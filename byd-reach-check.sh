#!/bin/bash
# Checks which BYD China cloud endpoints accept TCP from this Mac's current internet exit
# (run it with the VPN set to the country you want to test, e.g. Hong Kong).
#   ./byd-reach-check.sh            -> prints a table and saves it to byd-reach-<country>-<time>.txt
# IPs are the ones the car itself resolved/was dispatched to on 2026-10-17.
cd "$(dirname "$0")"

# ip:port  name  role  (status from Lithuania/Germany on 2026-10-17)
TARGETS="
110.41.6.66:6041     dilinknat1-cn.byd.auto   T-Box_channel(cloudmanager)  blocked
113.45.38.117:9999   newcan-cn.byd.auto       CAN_data_upload              blocked
122.9.98.233:8082    account.byd.com          DiLink_account               blocked
113.45.160.12:18080  push-cn.byd.auto         push                         ?
121.37.45.110:6001   dilinkreg-cn.byd.auto    T-Box_register(211)          open
121.37.192.90:6021   dilinkaddr-cn.byd.auto   T-Box_dispatch(200)          open
113.46.140.234:8890  dilink-mqtt1-cn.byd.auto MQTT_broker                  open
122.9.99.15:4443     idilink.bydauto.com.cn   idilink_https                open
124.71.65.164:443    idilink.byd.com          idilink_https                open
"

geo=$(curl -s -m 10 https://ipinfo.io/json)
ip=$(echo "$geo" | sed -n 's/.*"ip": *"\([^"]*\)".*/\1/p')
country=$(echo "$geo" | sed -n 's/.*"country": *"\([^"]*\)".*/\1/p')
city=$(echo "$geo" | sed -n 's/.*"city": *"\([^"]*\)".*/\1/p')
org=$(echo "$geo" | sed -n 's/.*"org": *"\([^"]*\)".*/\1/p')
OUT="byd-reach-${country:-unknown}-$(date +%Y%m%d-%H%M%S).txt"

# OPEN if either of 2 attempts connects within 5 s
probe() {
  for _ in 1 2; do nc -z -G 5 "$1" "$2" >/dev/null 2>&1 && { echo OPEN; return; }; done
  echo closed
}

{
  echo "BYD reachability check  $(date '+%F %T')"
  echo "exit IP: ${ip:-?}  country: ${country:-?}  city: ${city:-?}  org: ${org:-?}"
  echo
  printf '%-21s %-26s %-29s %-8s %s\n' "ip:port" "host" "role" "result" "(from LT/DE)"
  echo "$TARGETS" | while read -r t name role was; do
    [ -z "$t" ] && continue
    printf '%-21s %-26s %-29s %-8s %s\n' "$t" "$name" "$role" "$(probe "${t%:*}" "${t#*:}")" "$was"
  done
} | tee "$OUT"
echo
echo "saved: $(pwd)/$OUT"
