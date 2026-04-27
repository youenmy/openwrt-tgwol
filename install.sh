#!/bin/sh
# OpenWRT Telegram WOL Bot — installer
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/youenmy/openwrt-tgwol/main/install.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/youenmy/openwrt-tgwol/main/install.sh | sh -s -- --no-prompt
# Re-run safely — it overwrites files but keeps your /etc/config/tgwol.

set -eu

REPO_RAW="${TGWOL_REPO_RAW:-https://raw.githubusercontent.com/youenmy/openwrt-tgwol/main}"
PROMPT=1
[ "${1:-}" = "--no-prompt" ] && PROMPT=0

say()  { printf '\033[1;36m[tgwol]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[tgwol]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[tgwol]\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" = "0" ] || die "must run as root"
command -v apk >/dev/null 2>&1 || die "this installer requires OpenWRT 24.10+ (apk not found)"
command -v curl >/dev/null 2>&1 || { say "installing curl..."; apk update >/dev/null && apk add curl >/dev/null; }

say "OpenWRT Telegram WOL Bot installer"
say "Source: $REPO_RAW"

say "updating package lists..."
apk update >/dev/null 2>&1 || warn "apk update failed (continuing — packages may be cached)"

PKGS="curl etherwake jsonfilter openssh-client luci-base luci-compat"
say "installing packages: $PKGS"
for p in $PKGS; do
	if apk info --installed "$p" >/dev/null 2>&1; then
		continue
	fi
	apk add "$p" >/dev/null 2>&1 || warn "could not install $p (try manually)"
done

# luci-compat provides classic CBI on newer OpenWRT; it's optional but recommended.

fetch() {
	# usage: fetch <relative_repo_path> <target_path> [mode]
	local src="$REPO_RAW/files/$1" dst="$2" mode="${3:-0644}" tmp
	tmp="$dst.tgwol-new"
	mkdir -p "$(dirname "$dst")"
	if curl -fsSL "$src" -o "$tmp"; then
		mv "$tmp" "$dst"
		chmod "$mode" "$dst"
	else
		rm -f "$tmp"
		warn "failed to fetch $src"
		return 1
	fi
}

say "downloading files..."
fetch usr/share/tgwol/lib.sh                         /usr/share/tgwol/lib.sh                          0644
fetch usr/bin/tgwol-bot                              /usr/bin/tgwol-bot                               0755
fetch usr/bin/tgwol-cli                              /usr/bin/tgwol-cli                               0755
fetch etc/init.d/tgwol                               /etc/init.d/tgwol                                0755

# UCI config — only install default if missing
if [ ! -f /etc/config/tgwol ]; then
	fetch etc/config/tgwol /etc/config/tgwol 0600
	say "installed default /etc/config/tgwol"
else
	say "kept existing /etc/config/tgwol"
fi

# LuCI bits
fetch usr/lib/lua/luci/controller/tgwol.lua          /usr/lib/lua/luci/controller/tgwol.lua           0644
fetch usr/lib/lua/luci/model/cbi/tgwol/general.lua   /usr/lib/lua/luci/model/cbi/tgwol/general.lua    0644
fetch usr/lib/lua/luci/model/cbi/tgwol/devices.lua   /usr/lib/lua/luci/model/cbi/tgwol/devices.lua    0644
fetch usr/lib/lua/luci/model/cbi/tgwol/users.lua     /usr/lib/lua/luci/model/cbi/tgwol/users.lua      0644
fetch usr/lib/lua/luci/model/cbi/tgwol/router.lua    /usr/lib/lua/luci/model/cbi/tgwol/router.lua     0644
fetch usr/lib/lua/luci/view/tgwol/status.htm         /usr/lib/lua/luci/view/tgwol/status.htm          0644
fetch usr/share/rpcd/acl.d/luci-app-tgwol.json       /usr/share/rpcd/acl.d/luci-app-tgwol.json        0644

# Working directories
mkdir -p /var/lib/tgwol /etc/tgwol/keys
chmod 700 /etc/tgwol/keys

# Optional interactive setup — skip when piped without -- flag if no tty
if [ "$PROMPT" = "1" ] && [ -t 0 ] && [ -t 1 ]; then
	echo
	say "interactive setup (Enter to skip a question)"

	cur_token=$(uci -q get tgwol.main.bot_token || true)
	printf '  Bot token from @BotFather%s: ' "$( [ -n "$cur_token" ] && echo " (current: ***)" || true )"
	read -r tok || tok=""
	if [ -n "$tok" ]; then
		uci set tgwol.main.bot_token="$tok"
	fi

	printf '  Your Telegram chat_id (admin)%s: ' "(send /id to the bot once it runs to find it)"
	read -r cid || cid=""
	if [ -n "$cid" ]; then
		# create or update an admin user
		uci -q delete tgwol.admin_example >/dev/null 2>&1 || true
		uci set tgwol.admin="user"
		uci set tgwol.admin.name='Admin'
		uci set tgwol.admin.chat_id="$cid"
		uci set tgwol.admin.role='admin'
		uci add_list tgwol.admin.permissions='all'
	fi

	printf '  MAC of your home PC (AA:BB:CC:DD:EE:FF, blank to skip): '
	read -r mac || mac=""
	if [ -n "$mac" ]; then
		printf '  IP of your home PC (for ping/ssh): '
		read -r ip || ip=""
		printf '  Broadcast address [255.255.255.255]: '
		read -r bcast || bcast=""
		[ -z "$bcast" ] && bcast="255.255.255.255"
		printf '  OS of the PC (windows/linux/macos) [windows]: '
		read -r os || os=""
		[ -z "$os" ] && os="windows"

		uci set tgwol.pc1=device
		uci set tgwol.pc1.name='Home PC'
		uci set tgwol.pc1.mac="$mac"
		uci set tgwol.pc1.ip="$ip"
		uci set tgwol.pc1.broadcast="$bcast"
		uci set tgwol.pc1.os="$os"
		uci -q delete tgwol.pc1.allowed_users >/dev/null 2>&1 || true
		uci add_list tgwol.pc1.allowed_users='all'
	fi

	printf '  Enable bot now? [Y/n]: '
	read -r yn || yn=""
	case "$yn" in
		n|N|no|No) ;;
		*) uci set tgwol.main.enabled='1' ;;
	esac

	uci commit tgwol
fi

# enable + start if configured
if [ "$(uci -q get tgwol.main.enabled)" = "1" ] && [ -n "$(uci -q get tgwol.main.bot_token)" ]; then
	/etc/init.d/tgwol enable
	/etc/init.d/tgwol restart
	say "bot started — try /start in Telegram"
else
	say "bot is disabled or token is empty — open LuCI → Services → Telegram WOL Bot to finish setup"
fi

# luci cache flush so menu appears
[ -d /tmp/luci-modulecache ] && rm -rf /tmp/luci-modulecache 2>/dev/null || true
[ -f /tmp/luci-indexcache ] && rm -f /tmp/luci-indexcache 2>/dev/null || true
/etc/init.d/rpcd restart >/dev/null 2>&1 || true

cat <<EOF

$(say "install complete")

Next steps:
  • Open LuCI → Services → Telegram WOL Bot
  • Or use the CLI:
        tgwol-cli set-token <token>
        tgwol-cli add-key home_pc        # generates SSH key, prints pubkey
        tgwol-cli list-devices
        tgwol-cli test-token
        /etc/init.d/tgwol restart
  • In Telegram, send /id to your bot to discover your chat_id, then add it
    in LuCI → Telegram WOL Bot → Users.

Repository: $REPO_RAW
EOF
