#!/bin/sh
# ============================================================
# Author: WangQiang
# Desc:   Wake lock management script
# Usage:  sh power_wakelock.sh <action>
#         set    - Acquire temporary kernel wake lock
#         unset  - Release temporary kernel wake lock
#         dump   - Show all wake lock status (kernel + framework + battery)
#         kernel - Show kernel wake locks only
#         fw     - Show framework wake locks (dumpsys power)
#         stats  - Show battery stats wake lock history
#         active - Show currently active wake locks (framework)
# ============================================================

ACTION="$1"

WAKE_LOCK_NODE=/sys/power/wake_lock
WAKE_UNLOCK_NODE=/sys/power/wake_unlock
LOCK_NAME="temporary"

case "$ACTION" in

  set)
    echo "$LOCK_NAME" > "$WAKE_LOCK_NODE"
    echo "[OK] Kernel wake lock '$LOCK_NAME' acquired."
    echo "wake_lock: $(cat $WAKE_LOCK_NODE 2>/dev/null)"
    ;;

  unset)
    echo "$LOCK_NAME" > "$WAKE_UNLOCK_NODE"
    echo "[OK] Kernel wake lock '$LOCK_NAME' released."
    echo "wake_lock: $(cat $WAKE_LOCK_NODE 2>/dev/null)"
    ;;

  dump)
    echo "===== [Kernel Wake Locks] ====="
    echo "wake_lock:   $(cat $WAKE_LOCK_NODE 2>/dev/null)"
    echo "wake_unlock: $(cat $WAKE_UNLOCK_NODE 2>/dev/null)"
    echo ""
    echo "===== [Framework Wake Locks (dumpsys power)] ====="
    dumpsys power | grep -A 10 "Wake Locks:"
    echo ""
    echo "===== [Battery Stats Wake Lock History] ====="
    dumpsys batterystats | grep -A 10 "Wake lock"
    echo ""
    echo "===== [Suspend Blockers] ====="
    cat /sys/power/wakeup_count 2>/dev/null | awk '{print "wakeup_count: " $0}'
    cat /d/wakeup_sources 2>/dev/null | head -10
    ;;

  kernel)
    echo "===== [Kernel Wake Locks] ====="
    echo "wake_lock:   $(cat $WAKE_LOCK_NODE 2>/dev/null)"
    echo "wake_unlock: $(cat $WAKE_UNLOCK_NODE 2>/dev/null)"
    ;;

  fw)
    echo "===== [Framework Wake Locks (dumpsys power)] ====="
    dumpsys power | grep -A 10 "Wake Locks:"
    ;;

  stats)
    echo "===== [Battery Stats Wake Lock History] ====="
    dumpsys batterystats | grep -A 10 "Wake lock"
    ;;

  active)
    echo "===== [Currently Active Wake Locks] ====="
    dumpsys power | grep -E "PARTIAL_WAKE_LOCK|FULL_WAKE_LOCK|SCREEN_BRIGHT_WAKE_LOCK|PROXIMITY_SCREEN_OFF_WAKE_LOCK" | grep "HELD_BY"
    ;;

  *)
    echo "Usage: power wakelock <action>"
    echo ""
    echo "Actions:"
    echo "  set    - Acquire temporary kernel wake lock"
    echo "  unset  - Release temporary kernel wake lock"
    echo "  dump   - Show all wake lock status (kernel + framework + battery + suspend blockers)"
    echo "  kernel - Show kernel wake locks only"
    echo "  fw     - Show framework wake locks (dumpsys power)"
    echo "  stats  - Show battery stats wake lock history"
    echo "  active - Show currently active framework wake locks"
    ;;

esac
