import java.io.File
import java.nio.file.Files
import java.nio.file.LinkOption
import java.nio.file.Path
import java.nio.file.Paths
import java.nio.file.attribute.DosFileAttributes

fun main(args: Array<String>) {
    println("=== Windows 缓存与垃圾文件清理 ===")

    val systemDrive: String = System.getenv("SYSTEMDRIVE")?.trim()?.takeIf { it.isNotEmpty() } ?: "C:"
    val windir: String = System.getenv("WINDIR")?.trim()?.takeIf { it.isNotEmpty() }
        ?: "$systemDrive\\Windows"
    val userProfile: String = System.getenv("USERPROFILE")?.trim()?.takeIf { it.isNotEmpty() }
        ?: "$systemDrive\\Users\\Default"
    val localAppData: String = System.getenv("LOCALAPPDATA")?.trim()?.takeIf { it.isNotEmpty() }
        ?: "$userProfile\\AppData\\Local"

    var deletedCount = 0L
    var deletedBytes = 0L
    val failedPaths = mutableListOf<String>()

    fun humanSize(bytes: Long): String {
        if (bytes <= 0) return "0 B"
        val units = arrayOf("B", "KB", "MB", "GB", "TB")
        var v = bytes.toDouble()
        var i = 0
        while (v >= 1024.0 && i < units.size - 1) {
            v /= 1024.0
            i++
        }
        return String.format("%.2f %s", v, units[i])
    }

    fun isReparse(p: Path): Boolean = try {
        val attrs = Files.readAttributes(p, DosFileAttributes::class.java)
        attrs.isSymbolicLink
    } catch (e: Exception) {
        true
    }

    fun deletePath(p: Path) {
        try {
            if (Files.isDirectory(p, LinkOption.NOFOLLOW_LINKS) && !isReparse(p)) {
                Files.list(p).use { stream -> stream.forEach { deletePath(it) } }
            }
            if (Files.isRegularFile(p, LinkOption.NOFOLLOW_LINKS)) {
                deletedBytes += Files.size(p)
            }
            if (Files.deleteIfExists(p)) deletedCount++
        } catch (e: Exception) {
            failedPaths.add(p.toString())
        }
    }

    fun deleteFilesByExt(dir: Path, exts: Set<String>) {
        if (!Files.isDirectory(dir)) return
        try {
            Files.list(dir).use { stream ->
                stream.filter { Files.isRegularFile(it, LinkOption.NOFOLLOW_LINKS) }.forEach { f ->
                    val name = f.fileName.toString().lowercase()
                    if (exts.any { name.endsWith(it) }) deletePath(f)
                }
            }
        } catch (e: Exception) {
            failedPaths.add(dir.toString())
        }
    }

    fun deleteDirContents(dir: Path) {
        if (!Files.isDirectory(dir)) return
        try {
            Files.list(dir).use { stream -> stream.forEach { deletePath(it) } }
        } catch (e: Exception) {
            failedPaths.add(dir.toString())
        }
    }

    fun deleteFilesByPrefix(dir: Path, prefixes: Set<String>) {
        if (!Files.isDirectory(dir)) return
        try {
            Files.list(dir).use { stream ->
                stream.filter { Files.isRegularFile(it, LinkOption.NOFOLLOW_LINKS) }.forEach { f ->
                    val name = f.fileName.toString().lowercase()
                    if (prefixes.any { name.startsWith(it) }) deletePath(f)
                }
            }
        } catch (e: Exception) {
            failedPaths.add(dir.toString())
        }
    }

    val beforeFree = try {
        File("$systemDrive\\").usableSpace
    } catch (e: Exception) {
        -1L
    }

    println("系统盘: $systemDrive")
    println("清理前可用空间: ${if (beforeFree >= 0) humanSize(beforeFree) else "Unknown"}")
    println("--------------------------------------------------")

    // 1. 系统盘根目录常见垃圾/临时扩展名
    deleteFilesByExt(Paths.get("$systemDrive\\"), setOf(".tmp", "._mp", ".gid", ".chk", ".old", ".sqm", ".bak"))

    // 2. Windows 目录下 *.bak 与 Windows\Temp
    deleteFilesByExt(Paths.get(windir), setOf(".bak"))
    deleteDirContents(Paths.get(windir, "Temp"))

    // 3. Windows Update 下载缓存
    deleteDirContents(Paths.get(windir, "SoftwareDistribution", "Download"))

    // 4. 用户临时目录（当前用户）
    deleteDirContents(Paths.get(localAppData, "Temp"))

    // 5. 旧版系统路径（junction 指向同一目录时跳过，避免重复遍历）
    val legacyTemp = Paths.get(userProfile, "Local Settings", "Temp")
    if (Files.isDirectory(legacyTemp) && !isReparse(legacyTemp)) deleteDirContents(legacyTemp)

    // 6. 旧版 Cookies / Recent / Temporary Internet Files（若存在）
    listOf(
        Paths.get(userProfile, "Cookies"),
        Paths.get(userProfile, "Recent"),
        Paths.get(userProfile, "Local Settings", "Temporary Internet Files")
    ).forEach { if (Files.isDirectory(it)) deleteDirContents(it) }

    // 7. 资源管理器缩略图缓存
    deleteFilesByPrefix(Paths.get(localAppData, "Microsoft", "Windows", "Explorer"), setOf("thumbcache_"))

    println("--------------------------------------------------")

    val afterFree = try {
        File("$systemDrive\\").usableSpace
    } catch (e: Exception) {
        -1L
    }

    if (beforeFree >= 0 && afterFree >= 0) {
        println("清理后可用空间: ${humanSize(afterFree)}")
        println("本次释放空间: ${humanSize(afterFree - beforeFree)}")
    }
    println("删除文件/目录数: $deletedCount")
    println("累计删除大小: ${humanSize(deletedBytes)}")

    if (failedPaths.isNotEmpty()) {
        println("以下项目因被占用或权限不足未能删除 (${failedPaths.size}):")
        failedPaths.forEach { println("  - $it") }
    } else {
        println("全部清理项处理完成。")
    }
}