local sys = require "luci.sys"

local m = Map("tgwol", translate("Devices"),
	translate("Computers controlled by the bot. Each device gets its own card with WoL, ping and SSH actions in Telegram."))

m.on_after_commit = function(self)
	sys.call("/etc/init.d/tgwol enabled && /etc/init.d/tgwol restart >/dev/null 2>&1 || true")
end

local s = m:section(TypedSection, "device", translate("Devices"))
s.anonymous = false
s.addremove = true
s.template  = "cbi/tblsection"
s.extedit   = false

s:option(Value, "name", translate("Name")).rmempty = false

local mac = s:option(Value, "mac", translate("MAC"))
mac.datatype = "macaddr"
mac.rmempty  = false
mac.placeholder = "AA:BB:CC:DD:EE:FF"

local ip = s:option(Value, "ip", translate("IP / hostname"))
ip.placeholder = "192.168.1.100"

local bcast = s:option(Value, "broadcast", translate("Broadcast"))
bcast.default = "255.255.255.255"

local iface = s:option(Value, "wol_iface", translate("Iface (etherwake -i)"),
	translate("Optional. Network interface to send the magic packet from."))

local os = s:option(ListValue, "os", translate("OS"),
	translate("Used to pick default shutdown/sleep/lock commands."))
os:value("windows", "Windows")
os:value("linux",   "Linux")
os:value("macos",   "macOS")
os.default = "windows"

s:option(Value, "ssh_host", translate("SSH host"),
	translate("Falls back to IP if empty."))
s:option(Value, "ssh_user", translate("SSH user"))
local sport = s:option(Value, "ssh_port", translate("SSH port"))
sport.datatype = "port"
sport.default  = "22"

s:option(Value, "ssh_key", translate("SSH key path"),
	translate("Path on the router. Generate with: tgwol-cli add-key &lt;name&gt;"))

local au = s:option(DynamicList, "allowed_users", translate("Allowed users"),
	translate("Telegram chat IDs that can manage this device. Use 'all' to allow every user that passes the global access mode."))
au.default = "all"

return m
