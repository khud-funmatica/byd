#!/bin/bash
# Builds the Magisk module zip. The zip contains the WireGuard private key, so it is
# written to secrets/ (gitignored) and must not be shared.
#   ./build.sh   -> secrets/byd-hk-tunnel.zip
set -euo pipefail
cd "$(dirname "$0")"

[ -f secrets/wg.uapi ] || { echo "secrets/wg.uapi missing"; exit 1; }
(cd bydwg && CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -trimpath -ldflags="-s -w" -o bydwg-arm64 .)

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
cp -R ../byd-cn-dns/META-INF "$stage/"
cp module/* "$stage/"
cp bydwg/bydwg-arm64 "$stage/bydwg"
cp secrets/wg.uapi "$stage/wg.uapi"
rm -f secrets/byd-hk-tunnel.zip
(cd "$stage" && zip -qr -X "$OLDPWD/secrets/byd-hk-tunnel.zip" .)
unzip -l secrets/byd-hk-tunnel.zip
