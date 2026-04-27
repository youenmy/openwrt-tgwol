local sys = require "luci.sys"

local m = Map("tgwol", translate("Router actions"),
	translate("Toggle which router-side actions the bot exposes."))

m.on_after_commit = function(self)
	sys.call("/etc/init.d/tgwol enabled && /etc/init.d/tgwol restart >/dev/null 2>&1 || true")
end

local s = m:section(NamedSection, "router", "router", translate("Allowed actions"))
s.anonymous = true
s.addremove = false

s:option(Flag, "allow_status",  translate("Status (uptime / load / mem / WAN IP)")).default = "1"
s:option(Flag, "allow_clients", translate("List DHCP clients")).default = "1"
s:option(Flag, "allow_reboot",  translate("Reboot router")).default = "0"
s:option(Flag, "allow_shell",   translate("Run arbitrary shell (admin only, DANGEROUS)")).default = "0"
s:option(Flag, "allow_speedtest", translate("Speed test (requires speedtest-cli)")).default = "0"

return m
