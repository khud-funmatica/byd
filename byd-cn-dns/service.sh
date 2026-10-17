#!/system/bin/sh
# Re-resolves the idilink hosts every 6h (BYD may move them) and rewrites the
# bind-mounted hosts file in place, so no reboot is needed for new IPs.
MODDIR=${0%/*}
. "$MODDIR/common.sh"
HOSTS="$MODDIR/system/etc/hosts"
LOG="$MODDIR/refresh.log"

sleep 90
while true; do
  new=$(build_hosts "$MODDIR/hosts.base" "$HOSTS")
  if [ "$new" != "$(cat "$HOSTS")" ]; then
    echo "$new" > "$HOSTS"   # same inode: the /system/etc/hosts bind mount sees it immediately
    echo "$(date '+%F %T') updated: $(grep "$MARK" "$HOSTS" | awk '{print $1, $2}' | tr '\n' ' ')" >> "$LOG"
  fi
  tail -n 50 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
  sleep 21600
done
