/* powersd - root helper daemon for WheresMyPower.
 *
 * Deployed on the rooted test device as /system/bin/powersd with
 * /system/etc/init/powersd.rc; init starts it at boot. It runs outside the
 * zygote, so it has no seccomp filter and can execute the root dump that
 * in-app `su` cannot (app processes are killed with SIGSYS when su calls
 * setuid(0)).
 *
 * Loop: every REFRESH_MS run the whitelisted root dump and atomically replace
 * the world-readable file OUT_PATH (tmp + rename). The app reads that file and
 * applies its own freshness limit. No socket is used: app-domain SELinux
 * policies forbid connecting to an adbd-domain socket, while reading
 * /data/local/tmp/powers_sensors.txt is allowed for the legacy targetSdk-25
 * app domain.
 *
 * The service runs as user root with seclabel u:r:su:s0 (see powersd.rc):
 *  - the su domain is required to read the Mali GED nodes (type sysfs_ged),
 *    which the shell domain is denied;
 *  - for the sensor dump, refresh_once() forks a child that execs
 *    /system/bin/sh (shell_exec) so it transitions into the shell domain and
 *    runs `dumpsys` the same way `adb shell dumpsys` does.
 *
 * Build (NDK r27, dynamic linking - a static binary crashes on Android 14+
 * with a TLS alignment assertion):
 *   aarch64-linux-android24-clang -O2 -o powersd powersd.c
 */
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

#define OUT_PATH     "/data/local/tmp/powers_sensors.txt"
#define TMP_PATH     "/data/local/tmp/powers_sensors.tmp"
/* Mali GED nodes are root-only (not world-readable): the daemon copies the
 * handful the app needs into a world-readable file. This replaces the old
 * setenforce-0 + chmod workaround without weakening SELinux — the GED nodes
 * are type sysfs_ged, readable only by the su domain (not shell). */
#define GPU_OUT_PATH "/data/local/tmp/powers_gpu.txt"
#define GPU_TMP_PATH "/data/local/tmp/powers_gpu.tmp"
#define GED_DIR      "/sys/kernel/ged/hal"
#define REFRESH_MS   3000

static void refresh_once(void) {
    int fds[2];
    if (pipe(fds) < 0) return;

    /* Fixed command string: this daemon only ever runs one whitelisted
     * command. Going through /system/bin/sh matters: exec'ing shell_exec
     * moves the child into the shell domain, which is the domain with
     * the servicemanager/binder permissions that `dumpsys` needs (same
     * path `adb shell dumpsys` takes). */
    pid_t pid = fork();
    if (pid < 0) { close(fds[0]); close(fds[1]); return; }
    if (pid == 0) {
        close(fds[0]);
        dup2(fds[1], 1);
        dup2(fds[1], 2);
        char *argv[] = { "/system/bin/sh", "-c", "dumpsys sensorservice", NULL };
        execv(argv[0], argv);
        _exit(127);
    }
    close(fds[1]);

    FILE *out = fopen(TMP_PATH, "w");
    if (out) {
        char buf[8192];
        ssize_t n;
        while ((n = read(fds[0], buf, sizeof(buf))) > 0)
            fwrite(buf, 1, n, out);
        fclose(out);
        chmod(TMP_PATH, 0644);
        /* Atomic replace: readers never see a half-written file. */
        rename(TMP_PATH, OUT_PATH);
    }
    close(fds[0]);
    waitpid(pid, NULL, 0);
}

/* Copy the GED nodes the app needs into a world-readable file, grouped under
 * "[name]" headers. The app parses the same fields it used to read directly
 * from sysfs. Plain fopen works here (unlike the sensors dump, no binder or
 * special domain transition is required). */
static void refresh_gpu_once(void) {
    static const char *nodes[] = {
        "current_freqency", "gpu_utilization", "gpu_power_state",
        "total_gpu_freq_level_count", "opp_logs", NULL
    };
    FILE *out = fopen(GPU_TMP_PATH, "w");
    if (!out) return;
    for (int i = 0; nodes[i]; i++) {
        char path[256];
        snprintf(path, sizeof(path), GED_DIR "/%s", nodes[i]);
        FILE *in = fopen(path, "r");
        fprintf(out, "[%s]\n", nodes[i]);
        if (in) {
            char buf[4096];
            size_t n;
            while ((n = fread(buf, 1, sizeof(buf), in)) > 0)
                fwrite(buf, 1, n, out);
            fclose(in);
        }
        fputc('\n', out);
    }
    fclose(out);
    chmod(GPU_TMP_PATH, 0644);
    rename(GPU_TMP_PATH, GPU_OUT_PATH);
}

int main(void) {
    for (;;) {
        refresh_once();
        refresh_gpu_once();
        usleep(REFRESH_MS * 1000);
    }
}