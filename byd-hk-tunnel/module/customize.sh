SKIPUNZIP=0

[ -f "$MODPATH/wg.uapi" ] || abort "! wg.uapi missing: build the zip with build.sh"
set_perm "$MODPATH/bydwg" 0 0 0755
set_perm "$MODPATH/tunnel.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm "$MODPATH/wg.uapi" 0 0 0600
ui_print "- WireGuard endpoint: $(sed -n 's/^endpoint=//p' "$MODPATH/wg.uapi")"
ui_print "- Tunnel starts on next boot (or run: sh $MODPATH/tunnel.sh up)"
