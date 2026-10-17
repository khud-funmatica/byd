# Shared by customize.sh (install time), service.sh (every boot) and test-live.sh.

# Mainland-China subnet sent as EDNS Client Subnet so BYD's geo-DNS answers as for a car in China.
ECS=121.37.0.0/24

# Names BYD's geo-DNS answers with 1.1.1.1 outside mainland China (checked 2026-10-11).
NAMES="idilink.bydauto.com.cn idilink-global.byd.auto
idilink.byd.com apr-global.byd.auto
dilink-mqtt-cn.byd.auto dilink-mqtt0-cn.byd.auto dilink-mqtt1-cn.byd.auto dilink-mqtt2-cn.byd.auto
dilink-mqtt3-cn.byd.auto dilink-mqtt4-cn.byd.auto dilink-mqtt5-cn.byd.auto dilink-mqtt6-cn.byd.auto
dilink-mqtt7-cn.byd.auto dilink-mqtt8-cn.byd.auto dilink-mqtt9-cn.byd.auto"

MARK="# byd_cn_dns"

# What China resolved these to on 2026-10-11; used when DoH is unreachable.
fallback_ip() {
  case $1 in
    idilink.bydauto.com.cn|idilink-global.byd.auto) echo 122.9.99.15 ;;
    idilink.byd.com|apr-global.byd.auto) echo 124.71.65.164 ;;
    dilink-mqtt*) echo 113.46.140.234 ;;
  esac
}

# Prints the first A record for $1 as seen from China, or nothing.
cn_resolve() {
  /system/bin/curl -s -m 15 "https://dns.google/resolve?name=$1&type=A&edns_client_subnet=$ECS" 2>/dev/null \
    | sed -n 's/.*"type":1,"TTL":[0-9]*,"data":"\([0-9.]*\)".*/\1/p' \
    | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | grep -v '^1\.1\.1\.1$' | head -n 1
}

# build_hosts <base hosts file> <previous hosts file or empty> -> stdout
build_hosts() {
  base=$1; prev=$2
  grep -v "$MARK" "$base"
  echo ""
  for name in $NAMES; do
    ip=$(cn_resolve "$name")
    if [ -z "$ip" ] && [ -n "$prev" ] && [ -f "$prev" ]; then
      ip=$(grep "$MARK" "$prev" | awk -v n="$name" '$2 == n {print $1}' | head -n 1)
    fi
    [ -z "$ip" ] && ip=$(fallback_ip "$name")
    echo "$ip $name $MARK"
  done
}
