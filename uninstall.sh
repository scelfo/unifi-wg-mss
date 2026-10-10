#!/bin/sh
# STETNET WireGuard MSS Clamping Uninstaller

WG_DIR="/data/STETNET/wg-mss"
SERVICE_NAME="wg-mss.service"
TIMER_NAME="wg-mss.timer"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"
TIMER_PATH="/etc/systemd/system/$TIMER_NAME"

GREEN="\\033[1;32m"
YELLOW="\\033[1;33m"
NC="\\033[0m"

echo "🔧 Stopping and disabling systemd units..."

systemctl stop "$TIMER_NAME" 2>/dev/null
systemctl stop "$SERVICE_NAME" 2>/dev/null
systemctl disable "$TIMER_NAME" 2>/dev/null
systemctl disable "$SERVICE_NAME" 2>/dev/null

rm -f "$TIMER_PATH"
rm -f "$SERVICE_PATH"

systemctl daemon-reexec
systemctl daemon-reload

echo "🧹 Removing MSS iptables rules..."

# Delete every TCPMSS rule on a wg* interface in the mangle FORWARD chain:
# outbound (-o) and inbound (-i), --clamp-mss-to-pmtu or --set-mss, and any
# duplicates. The rules are read from iptables itself rather than from the
# current interface list, so rules for wg interfaces that no longer exist
# (e.g. after a site-to-site VPN is deleted) are removed too.
iptables -w -t mangle -S FORWARD 2>/dev/null \
    | grep -E -- '-[io] wg[^ ]* .*-j TCPMSS' \
    | sed 's/^-A /-D /' \
    | while read -r rule; do
        # shellcheck disable=SC2086
        iptables -w -t mangle $rule
    done

remaining=$(iptables -w -t mangle -S FORWARD 2>/dev/null | grep -cE -- '-[io] wg[^ ]* .*-j TCPMSS')

echo "🗑️  Removing $WG_DIR..."
[ -n "$WG_DIR" ] && rm -rf "$WG_DIR"
rmdir "$(dirname "$WG_DIR")" 2>/dev/null || true

if [ "$remaining" -eq 0 ]; then
    echo "${GREEN}✅ Uninstalled. No wg* MSS rules remain.${NC}"
else
    echo "${YELLOW}⚠️  Uninstalled, but $remaining wg* MSS rule(s) remain:${NC}"
    iptables -w -t mangle -S FORWARD | grep -E -- '-[io] wg[^ ]* .*-j TCPMSS'
fi
