SKIPUNZIP=0
. "$MODPATH/common.sh"

ui_print "- Saving stock /system/etc/hosts as base"
grep -v "$MARK" /system/etc/hosts > "$MODPATH/hosts.base"

ui_print "- Resolving idilink hosts via China ECS"
mkdir -p "$MODPATH/system/etc"
build_hosts "$MODPATH/hosts.base" "" > "$MODPATH/system/etc/hosts"
grep "$MARK" "$MODPATH/system/etc/hosts" | while read -r l; do ui_print "  $l"; done

set_perm_recursive "$MODPATH/system" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
