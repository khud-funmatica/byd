#!/system/bin/sh
# Runs on the head unit as root. Sends the BYD cloud daemons' TCP traffic (everything
# that would leave via the telematics APN3 interface) through a WireGuard tunnel to the
# Hong Kong relay, because BYD's cloud only accepts China/HK source IPs on several ports.
#   tunnel.sh up | down | status
# The tunnel's own UDP packets carry fwmark 0x5200 and still leave via APN3 directly.
D=${BYD_HK_DIR:-${0%/*}}
APN_IF=${APN_IF:-rmnet_data3}
WG_IF=wg0
WG_ADDR=10.66.0.2/32
ENDPOINT=$(sed -n 's/^endpoint=\(.*\):.*/\1/p' "$D/wg.uapi")
MARK_TUN=0x5200   # set by bydwg on its UDP socket (fwmark=20992 in wg.uapi)
MARK_BYD=0x5100   # set below on BYD TCP that would go out via APN3
T_TUN=116
T_BYD=115

# Magisk runs boot scripts in busybox standalone mode; its ip applet lacks fwmark rules.
ip() { /system/bin/ip "$@"; }
ipt() { /system/bin/iptables -w "$@"; }

rules_down() {
  ipt -t mangle -D OUTPUT -j BYDHK 2>/dev/null
  ipt -t mangle -F BYDHK 2>/dev/null; ipt -t mangle -X BYDHK 2>/dev/null
  ipt -t mangle -D POSTROUTING -j BYDHK_MSS 2>/dev/null
  ipt -t mangle -F BYDHK_MSS 2>/dev/null; ipt -t mangle -X BYDHK_MSS 2>/dev/null
  ipt -t nat -D POSTROUTING -j BYDHK_POST 2>/dev/null
  ipt -t nat -F BYDHK_POST 2>/dev/null; ipt -t nat -X BYDHK_POST 2>/dev/null
  while ip rule del fwmark $MARK_TUN lookup $T_TUN 2>/dev/null; do :; done
  while ip rule del fwmark $MARK_BYD lookup $T_BYD 2>/dev/null; do :; done
  ip route flush table $T_TUN 2>/dev/null
  ip route flush table $T_BYD 2>/dev/null
}

rules_up() {
  # tunnel transport: endpoint via APN3
  ip route replace "$ENDPOINT" dev $APN_IF table $T_TUN
  ip rule add fwmark $MARK_TUN lookup $T_TUN prio 5
  # BYD traffic: default via wg0
  ip route replace default dev $WG_IF table $T_BYD
  ip rule add fwmark $MARK_BYD lookup $T_BYD prio 6
  # mark TCP that routing sent to APN3 (mark change re-routes the packet)
  ipt -t mangle -N BYDHK
  ipt -t mangle -A BYDHK -m mark --mark $MARK_TUN -j RETURN
  ipt -t mangle -A BYDHK -o $APN_IF -p tcp -j MARK --set-mark $MARK_BYD
  ipt -t mangle -I OUTPUT 1 -j BYDHK
  ipt -t mangle -N BYDHK_MSS
  ipt -t mangle -A BYDHK_MSS -o $WG_IF -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
  ipt -t mangle -I POSTROUTING 1 -j BYDHK_MSS
  ipt -t nat -N BYDHK_POST
  ipt -t nat -A BYDHK_POST -o $WG_IF -j MASQUERADE
  ipt -t nat -I POSTROUTING 1 -j BYDHK_POST
}

case "$1" in
  up)
    rules_down
    pkill -f "bydwg -i $WG_IF" 2>/dev/null; sleep 1
    tail -n 100 "$D/bydwg.log" > "$D/bydwg.log.tmp" 2>/dev/null && mv "$D/bydwg.log.tmp" "$D/bydwg.log"
    setsid "$D/bydwg" -i $WG_IF -c "$D/wg.uapi" -s "$D/wg.status" >>"$D/bydwg.log" 2>&1 < /dev/null &
    for _ in 1 2 3 4 5 6 7 8 9 10; do ip link show $WG_IF >/dev/null 2>&1 && break; sleep 1; done
    pid=$(pgrep -f "bydwg -i $WG_IF" | head -n 1)
    [ -n "$pid" ] && echo -1000 > /proc/$pid/oom_score_adj
    ip addr replace $WG_ADDR dev $WG_IF
    ip link set $WG_IF up
    echo 2 > /proc/sys/net/ipv4/conf/$WG_IF/rp_filter   # replies arrive on wg0 for routes that point at APN3
    rules_up
    echo "up: pid=$pid endpoint=$ENDPOINT"
    ;;
  down)
    rules_down
    pkill -f "bydwg -i $WG_IF" 2>/dev/null
    echo down
    ;;
  status)
    pid=$(pgrep -f "bydwg -i $WG_IF" | head -n 1)
    echo "bydwg pid: ${pid:-not running}  apn_if: $APN_IF"
    ip -4 addr show $WG_IF 2>/dev/null | grep inet
    grep -E 'last_handshake_time_sec|rx_bytes|tx_bytes' "$D/wg.status" 2>/dev/null
    ip rule | grep -E "lookup ($T_TUN|$T_BYD)"
    ipt -t mangle -L BYDHK -nv 2>/dev/null | tail -n +3
    tail -n 5 "$D/bydwg.log" 2>/dev/null
    ;;
  *) echo "usage: $0 up|down|status"; exit 1 ;;
esac
