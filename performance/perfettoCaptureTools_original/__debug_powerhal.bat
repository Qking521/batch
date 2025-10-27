adb shell "setprop log.tag.libPowerHal D;  setprop persist.log.tag.libPowerHal D; setprop log.tag.mtkpower@impl D; setprop persist.log.tag.mtkpower@impl D; setprop log.tag.mtkpower_client D; setprop persist.log.tag.mtkpower_client D; setprop log.tag.UxUtility D; setprop persist.log.tag.UxUtility D; setprop log.tag.PowerHalAddressUitls D; setprop persist.log.tag.PowerHalAddressUitls D; setprop log.tag.PowerHalMgrImpl D; setprop persist.log.tag.PowerHalMgrImpl D; setprop log.tag.PowerHalMgrServiceImpl D; setprop persist.log.tag.PowerHalMgrServiceImpl D; "


adb shell "for x in `getprop | grep log.tag | grep -i powerhal | cut -c2-50 | awk -F']' '{print $1}'`; do setprop $x D ;done"
adb shell "for x in `getprop | grep log.tag | grep -i powerhal | cut -c2-50 | awk -F']' '{print $1}'`; do getprop $x  ;done"

pause