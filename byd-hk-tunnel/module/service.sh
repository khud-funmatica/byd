#!/system/bin/sh
# Brings the tunnel up once the BYD cloud daemons have created their APN3 host routes,
# then checks it every 60 s and re-creates whatever went missing.
MODDIR=${0%/*}
export BYD_HK_DIR=$MODDIR
LOG=$MODDIR/service.log
IP=/system/bin/ip

log() {
  echo "$(date '+%F %T') $*" >> "$LOG"
  tail -n 200 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
}

# Interface the daemons route their cloud hosts through (rmnet_data3 so far).
apn_if() {
  for t in 20 10; do
    $IP route show table $t 2>/dev/null | sed -n 's/.* dev \([^ ]*\).*/\1/p' | head -n 1
  done | head -n 1
}

until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 5; done
log "boot completed"

up_at=0
restarted=0
while true; do
  ifc=$(apn_if)
  if [ -n "$ifc" ] && $IP -4 addr show "$ifc" 2>/dev/null | grep -q inet; then
    now=$(date +%s)
    hs=$(sed -n 's/^last_handshake_time_sec=//p' "$MODDIR/wg.status" 2>/dev/null)
    why=""
    pgrep -f "bydwg -i wg0" >/dev/null || why="bydwg not running"
    [ -z "$why" ] && { $IP rule | grep -q "fwmark 0x5100 lookup 115" || why="ip rules missing"; }
    [ -z "$why" ] && { $IP route show table 116 | grep -q "dev $ifc" || why="endpoint route missing or APN moved to $ifc"; }
    [ -z "$why" ] && { /system/bin/iptables -w -t mangle -C BYDHK -o "$ifc" -p tcp -j MARK --set-mark 0x5100 2>/dev/null || why="mark rule missing"; }
    # keepalive is 25 s and WireGuard re-handshakes every 2 min, so 10 min without one is broken
    if [ -z "$why" ] && [ $((now - up_at)) -gt 600 ]; then
      if [ -z "$hs" ] || [ "$hs" = 0 ] || [ $((now - hs)) -gt 600 ]; then why="no handshake for 10 min"; fi
    fi
    if [ -n "$why" ]; then
      log "up ($why), apn_if=$ifc: $(APN_IF=$ifc sh "$MODDIR/tunnel.sh" up 2>&1 | tr '\n' ' ')"
      up_at=$now
      if [ $restarted = 0 ]; then
        # connections opened before the tunnel went direct and hang; make the daemons reconnect
        sleep 5
        setprop ctl.restart cloudmanager
        setprop ctl.restart mqttserv
        restarted=1
        log "restarted cloudmanager and mqttserv"
      fi
    fi
  fi
  sleep 60
done
