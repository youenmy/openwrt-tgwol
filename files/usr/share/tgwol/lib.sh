#!/bin/sh
# tgwol — common library
# shellcheck shell=ash

TGWOL_VERSION="1.0.0"
TGWOL_API="https://api.telegram.org"
TGWOL_STATE_DIR="/var/lib/tgwol"
TGWOL_OFFSET_FILE="$TGWOL_STATE_DIR/offset"
TGWOL_LOG_TAG="tgwol"

mkdir -p "$TGWOL_STATE_DIR"

# ---------- logging ----------

log() {
	# usage: log <level> <msg...>
	local lvl="$1"; shift
	logger -t "$TGWOL_LOG_TAG" -p "user.${lvl}" -- "$*"
	[ "${TGWOL_FOREGROUND:-0}" = "1" ] && echo "[$lvl] $*" >&2
}
log_info()  { log info "$@"; }
log_warn()  { log warning "$@"; }
log_err()   { log err "$@"; }
log_debug() { [ "${TGWOL_LOG_LEVEL:-info}" = "debug" ] && log debug "$@"; return 0; }

# ---------- json ----------

# Escape arbitrary string into JSON string body (no surrounding quotes)
json_escape() {
	awk 'BEGIN{
		for (i=0;i<32;i++) ctl[sprintf("%c",i)]=sprintf("\\u%04x",i)
		ctl["\""]="\\\""; ctl["\\"]="\\\\"; ctl["\b"]="\\b"
		ctl["\f"]="\\f"; ctl["\n"]="\\n"; ctl["\r"]="\\r"; ctl["\t"]="\\t"
	}
	{
		out=""
		for (i=1;i<=length($0);i++){
			c=substr($0,i,1)
			out = out (c in ctl ? ctl[c] : c)
		}
		# preserve original line ending logic: re-add \n between input lines
		print out
	}' <<EOF
$1
EOF
}

# Get JSON value via jsonfilter; returns empty on miss
jget() {
	# usage: jget <json> <jsonpath>
	printf '%s' "$1" | jsonfilter -e "$2" 2>/dev/null
}

# Count length of an array path
jlen() {
	local v
	v=$(printf '%s' "$1" | jsonfilter -e "$2" 2>/dev/null)
	# jsonfilter returns array as one element per line — count lines
	[ -z "$v" ] && { echo 0; return; }
	printf '%s\n' "$v" | wc -l
}

# ---------- telegram API ----------

tg_call() {
	# usage: tg_call <method> <json_payload>
	local method="$1" payload="$2"
	curl -fsS --max-time 30 \
		-H "Content-Type: application/json" \
		-X POST \
		--data "$payload" \
		"$TGWOL_API/bot$BOT_TOKEN/$method" 2>/dev/null
}

tg_get_updates() {
	# usage: tg_get_updates <offset> <timeout>
	local offset="$1" timeout="$2"
	curl -fsS --max-time "$((timeout + 10))" \
		"$TGWOL_API/bot$BOT_TOKEN/getUpdates?offset=$offset&timeout=$timeout&allowed_updates=%5B%22message%22%2C%22callback_query%22%5D" \
		2>/dev/null
}

tg_send_message() {
	# usage: tg_send_message <chat_id> <text> [keyboard_json]
	local chat="$1" text="$2" kbd="$3"
	local etext payload
	etext=$(json_escape "$text" | awk 'BEGIN{ORS=""} {if(NR>1)print "\\n"; print}')
	if [ -n "$kbd" ]; then
		payload=$(printf '{"chat_id":%s,"text":"%s","parse_mode":"HTML","disable_web_page_preview":true,"reply_markup":%s}' \
			"$chat" "$etext" "$kbd")
	else
		payload=$(printf '{"chat_id":%s,"text":"%s","parse_mode":"HTML","disable_web_page_preview":true}' \
			"$chat" "$etext")
	fi
	tg_call sendMessage "$payload" >/dev/null
}

tg_edit_message() {
	# usage: tg_edit_message <chat_id> <msg_id> <text> [keyboard_json]
	local chat="$1" mid="$2" text="$3" kbd="$4"
	local etext payload
	etext=$(json_escape "$text" | awk 'BEGIN{ORS=""} {if(NR>1)print "\\n"; print}')
	if [ -n "$kbd" ]; then
		payload=$(printf '{"chat_id":%s,"message_id":%s,"text":"%s","parse_mode":"HTML","disable_web_page_preview":true,"reply_markup":%s}' \
			"$chat" "$mid" "$etext" "$kbd")
	else
		payload=$(printf '{"chat_id":%s,"message_id":%s,"text":"%s","parse_mode":"HTML","disable_web_page_preview":true}' \
			"$chat" "$mid" "$etext")
	fi
	tg_call editMessageText "$payload" >/dev/null
}

tg_answer_callback() {
	# usage: tg_answer_callback <callback_id> [text] [show_alert]
	local cb="$1" text="$2" alert="${3:-false}"
	local etext payload
	etext=$(json_escape "$text" | awk 'BEGIN{ORS=""} {if(NR>1)print "\\n"; print}')
	payload=$(printf '{"callback_query_id":"%s","text":"%s","show_alert":%s}' \
		"$cb" "$etext" "$alert")
	tg_call answerCallbackQuery "$payload" >/dev/null
}

# ---------- inline keyboard builders ----------

# Build a single button JSON object
btn() {
	# usage: btn <text> <callback_data>
	local etext ecb
	etext=$(json_escape "$1" | tr -d '\n')
	ecb=$(json_escape "$2" | tr -d '\n')
	printf '{"text":"%s","callback_data":"%s"}' "$etext" "$ecb"
}

# Build a row from buttons separated by |
row() {
	# usage: row "btn1json" "btn2json" ...
	local first=1 b
	printf '['
	for b in "$@"; do
		[ "$first" = "1" ] || printf ','
		printf '%s' "$b"
		first=0
	done
	printf ']'
}

# Build inline_keyboard reply_markup from row JSONs
keyboard() {
	# usage: keyboard "rowjson1" "rowjson2" ...
	local first=1 r
	printf '{"inline_keyboard":['
	for r in "$@"; do
		[ "$first" = "1" ] || printf ','
		printf '%s' "$r"
		first=0
	done
	printf ']}'
}

# ---------- access control ----------

# Load all users and devices into in-memory shell vars (called once per loop iter)
acl_load() {
	. /lib/functions.sh
	config_load tgwol
	ACL_USERS=""
	ACL_DEVICES=""
	config_foreach _acl_collect_user user
	config_foreach _acl_collect_device device
}

_acl_collect_user() {
	local sec="$1"
	local chat role perms
	config_get chat "$sec" chat_id
	config_get role "$sec" role "user"
	config_get perms "$sec" permissions ""
	[ -z "$chat" ] && return
	ACL_USERS="$ACL_USERS$chat|$role|$sec
"
	# permissions stored as list — fetch via UCI list iter
	local p
	for p in $(uci -q get tgwol."$sec".permissions); do
		eval "ACL_PERM_${chat}_${p}=1"
	done
}

_acl_collect_device() {
	local sec="$1"
	ACL_DEVICES="$ACL_DEVICES$sec
"
}

# Returns role of chat_id or empty if unknown
acl_role() {
	local cid="$1" line c r
	IFS='
'
	for line in $ACL_USERS; do
		c=$(echo "$line" | cut -d'|' -f1)
		r=$(echo "$line" | cut -d'|' -f2)
		if [ "$c" = "$cid" ]; then unset IFS; echo "$r"; return; fi
	done
	unset IFS
}

# Check permission
acl_can() {
	# usage: acl_can <chat_id> <perm>
	local cid="$1" perm="$2" role mode
	mode=$(uci -q get tgwol.main.access_mode)
	[ -z "$mode" ] && mode="whitelist"

	if [ "$mode" = "open" ]; then
		return 0
	fi

	role=$(acl_role "$cid")
	[ -z "$role" ] && return 1
	[ "$role" = "admin" ] && return 0

	# user role: check explicit permission or 'all'
	eval "v=\${ACL_PERM_${cid}_all:-}"
	[ "$v" = "1" ] && return 0
	eval "v=\${ACL_PERM_${cid}_${perm}:-}"
	[ "$v" = "1" ] && return 0
	return 1
}

# Check device access for user
acl_device_allowed() {
	# usage: acl_device_allowed <chat_id> <device_section>
	local cid="$1" sec="$2" role allowed u
	role=$(acl_role "$cid")
	[ "$role" = "admin" ] && return 0
	for u in $(uci -q get tgwol."$sec".allowed_users); do
		[ "$u" = "all" ] && return 0
		[ "$u" = "$cid" ] && return 0
	done
	return 1
}

# ---------- device actions ----------

# Wake-on-LAN (etherwake)
do_wol() {
	# usage: do_wol <device_section>
	local sec="$1" mac bcast port iface
	mac=$(uci -q get tgwol."$sec".mac)
	bcast=$(uci -q get tgwol."$sec".broadcast)
	port=$(uci -q get tgwol."$sec".wol_port)
	iface=$(uci -q get tgwol."$sec".wol_iface)
	[ -z "$mac" ] && { echo "MAC не задан"; return 1; }
	[ -z "$bcast" ] && bcast="255.255.255.255"
	[ -z "$port" ] && port="9"

	if command -v etherwake >/dev/null 2>&1; then
		if [ -n "$iface" ]; then
			etherwake -i "$iface" -b "$mac" 2>&1
		else
			etherwake -b "$mac" 2>&1
		fi
	elif command -v wakeonlan >/dev/null 2>&1; then
		wakeonlan -i "$bcast" -p "$port" "$mac" 2>&1
	else
		echo "инструмент WoL не установлен (etherwake/wakeonlan)"
		return 1
	fi
}

# Ping device
do_ping() {
	local sec="$1" host
	host=$(uci -q get tgwol."$sec".ip)
	[ -z "$host" ] && host=$(uci -q get tgwol."$sec".ssh_host)
	[ -z "$host" ] && { echo "IP не задан"; return 1; }
	if ping -c 2 -W 2 "$host" >/dev/null 2>&1; then
		echo "онлайн ($host)"
		return 0
	fi
	echo "офлайн ($host)"
	return 1
}

# SSH command runner
_ssh_exec() {
	# usage: _ssh_exec <device_section> <command...>
	local sec="$1"; shift
	local host user port key
	host=$(uci -q get tgwol."$sec".ssh_host)
	[ -z "$host" ] && host=$(uci -q get tgwol."$sec".ip)
	user=$(uci -q get tgwol."$sec".ssh_user)
	port=$(uci -q get tgwol."$sec".ssh_port)
	key=$(uci -q get tgwol."$sec".ssh_key)
	[ -z "$port" ] && port=22
	[ -z "$host" ] && { echo "SSH-хост не задан"; return 1; }
	[ -z "$user" ] && { echo "SSH-пользователь не задан"; return 1; }
	[ -z "$key" ] && { echo "SSH-ключ не задан"; return 1; }
	[ ! -f "$key" ] && { echo "файл SSH-ключа не найден: $key"; return 1; }

	if command -v ssh >/dev/null 2>&1; then
		ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
			-o ConnectTimeout=8 -o BatchMode=yes \
			-i "$key" -p "$port" "$user@$host" "$@" 2>&1
	else
		# dropbear
		dbclient -y -y -i "$key" -p "$port" "$user@$host" "$@" 2>&1
	fi
}

_os_cmd() {
	# usage: _os_cmd <os> <action>
	local os="$1" act="$2"
	case "$os:$act" in
		windows:shutdown) echo "shutdown /s /t 0 /f" ;;
		windows:reboot)   echo "shutdown /r /t 0 /f" ;;
		windows:sleep)    echo "rundll32.exe powrprof.dll,SetSuspendState 0,1,0" ;;
		windows:lock)     echo "rundll32.exe user32.dll,LockWorkStation" ;;
		linux:shutdown)   echo "sudo shutdown -h now" ;;
		linux:reboot)     echo "sudo reboot" ;;
		linux:sleep)      echo "systemctl suspend" ;;
		linux:lock)       echo "loginctl lock-session" ;;
		macos:shutdown)   echo "sudo shutdown -h now" ;;
		macos:reboot)     echo "sudo reboot" ;;
		macos:sleep)      echo "pmset sleepnow" ;;
		macos:lock)       echo "pmset displaysleepnow" ;;
		*) echo "" ;;
	esac
}

do_action() {
	# usage: do_action <device_section> <shutdown|reboot|sleep|lock>
	local sec="$1" act="$2" os override cmd
	os=$(uci -q get tgwol."$sec".os)
	[ -z "$os" ] && os="windows"
	override=$(uci -q get "tgwol.$sec.cmd_$act")
	if [ -n "$override" ]; then
		cmd="$override"
	else
		cmd=$(_os_cmd "$os" "$act")
	fi
	[ -z "$cmd" ] && { echo "нет команды для $os/$act"; return 1; }
	_ssh_exec "$sec" "$cmd"
}

# ---------- router actions ----------

router_status() {
	local up load mem wan
	up=$(uptime | sed 's/^[ \t]*//')
	load=$(cat /proc/loadavg 2>/dev/null | cut -d' ' -f1-3)
	mem=$(awk '/MemAvailable/ {a=$2} /MemTotal/ {t=$2} END {printf "%.0f%% free (%.0f/%.0f MB)", a*100/t, a/1024, t/1024}' /proc/meminfo)
	wan=$(ifstatus wan 2>/dev/null | jsonfilter -e '@["ipv4-address"][0].address' 2>/dev/null)
	[ -z "$wan" ] && wan="unknown"
	cat <<EOF
<b>Статус роутера</b>
Аптайм: $up
Нагрузка: $load
Память: $mem
WAN IP: $wan
EOF
}

router_clients() {
	local out=""
	if [ -f /tmp/dhcp.leases ]; then
		out=$(awk '{printf "• %s — %s (%s)\n", $4, $3, $2}' /tmp/dhcp.leases | head -40)
	fi
	[ -z "$out" ] && out="(нет DHCP-аренд)"
	printf '<b>DHCP-клиенты</b>\n%s' "$out"
}

router_reboot() {
	(sleep 2 && reboot) &
	echo "Перезагрузка роутера через 2 сек..."
}

router_shell() {
	# usage: router_shell <cmd...>
	local out
	out=$(eval "$@" 2>&1 | head -c 3500)
	printf '<pre>%s</pre>' "$(printf '%s' "$out" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')"
}

# ---------- offset persistence ----------

offset_load() {
	[ -f "$TGWOL_OFFSET_FILE" ] && cat "$TGWOL_OFFSET_FILE" || echo 0
}

offset_save() {
	echo "$1" > "$TGWOL_OFFSET_FILE"
}
