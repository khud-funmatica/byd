#!/bin/bash
# Live test of the idilink hosts override without installing the module or rebooting.
#   ./test-live.sh apply   - bind-mount patched hosts over /system/etc/hosts, restart cloud daemons, watch
#   ./test-live.sh watch   - only watch cloud daemon connections / mqtt status
#   ./test-live.sh revert  - unmount the patched hosts, restart cloud daemons
# Needs Magisk root for the adb shell (Magisk -> Superuser -> Shell: allowed).
set -e
cd "$(dirname "$0")"
SU="/debug_ramdisk/magisk su -mm -c"

watch_conns() {
  for i in $(seq 1 "${1:-15}"); do
    echo "--- $(date +%T)"
    adb shell "$SU 'sh /data/local/tmp/conns.sh | grep -v LISTEN; echo mqtt_status=\$(getprop sys.mqtt_status) app_reg_status=\$(getprop persist.sys.cloud.app_reg_status)'"
    sleep 8
  done
}

adb push conns.sh /data/local/tmp/conns.sh >/dev/null
case "$1" in
  apply)
    adb push common.sh /data/local/tmp/byd_cn_dns_common.sh >/dev/null
    adb shell "$SU 'grep -q byd_cn_dns /system/etc/hosts && umount /system/etc/hosts; cp /system/etc/hosts /data/local/tmp/hosts.stock; . /data/local/tmp/byd_cn_dns_common.sh; build_hosts /data/local/tmp/hosts.stock \"\" > /data/local/tmp/hosts.byd; chmod 644 /data/local/tmp/hosts.byd; chcon u:object_r:system_file:s0 /data/local/tmp/hosts.byd; mount -o bind /data/local/tmp/hosts.byd /system/etc/hosts; grep byd_cn_dns /system/etc/hosts; setprop ctl.restart mqttserv'"
    watch_conns "$2" ;;
  watch) watch_conns "$2" ;;
  revert)
    adb shell "$SU 'umount /system/etc/hosts; setprop ctl.restart mqttserv; grep -c byd_cn_dns /system/etc/hosts || true'" ;;
  *) echo "usage: $0 apply|watch|revert [iterations]"; exit 1 ;;
esac
