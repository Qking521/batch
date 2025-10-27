adb shell "setprop debug.hwui.skia_atrace_enabled true"
adb shell "setprop debug.hwui.skia_use_perfetto_track_events false"
adb shell "setprop debug.renderengine.skia_atrace_enabled true"
adb shell "setprop vendor.debug.gpu.provider meow"
adb shell "setprop debug.hwui.skia_tracing_enabled true"

adb shell "stop;start"
pause