#!/bin/sh
# OpenWRT Telegram WOL Bot — uninstaller

set -eu

KEEP_CONFIG=1
[ "${1:-}" = "--purge" ] && KEEP_CONFIG=0

say() { printf '\033[1;36m[tgwol]\033[0m %s\n' "$*"; }

[ "$(id -u)" = "0" ] || { echo "must run as root" >&2; exit 1; }

say "stopping service..."
/etc/init.d/tgwol stop    >/dev/null 2>&1 || true
/etc/init.d/tgwol disable >/dev/null 2>&1 || true

say "removing files..."
rm -f /usr/bin/tgwol-bot
rm -f /usr/bin/tgwol-cli
rm -rf /usr/share/tgwol
rm -f /etc/init.d/tgwol

rm -f /usr/lib/lua/luci/controller/tgwol.lua
rm -rf /usr/lib/lua/luci/model/cbi/tgwol
rm -rf /usr/lib/lua/luci/view/tgwol
rm -f /usr/share/rpcd/acl.d/luci-app-tgwol.json

rm -rf /var/lib/tgwol

if [ "$KEEP_CONFIG" = "0" ]; then
	rm -f /etc/config/tgwol
	rm -rf /etc/tgwol
	say "purged config and SSH keys"
else
	say "kept /etc/config/tgwol and /etc/tgwol/keys (use --purge to remove)"
fi

# luci cache flush
[ -d /tmp/luci-modulecache ] && rm -rf /tmp/luci-modulecache 2>/dev/null || true
[ -f /tmp/luci-indexcache ] && rm -f /tmp/luci-indexcache 2>/dev/null || true
/etc/init.d/rpcd restart >/dev/null 2>&1 || true

say "done"
