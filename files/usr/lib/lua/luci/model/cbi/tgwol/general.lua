local sys = require "luci.sys"

local m = Map("tgwol", translate("Telegram WOL Bot — General"),
	translate("Manage the bot service, token and access mode. " ..
		"Devices, users and router actions are configured in the other tabs."))

m.on_after_commit = function(self)
	-- restart service when settings change (only if enabled)
	sys.call("/etc/init.d/tgwol enabled && /etc/init.d/tgwol restart >/dev/null 2>&1 || true")
end

local s = m:section(NamedSection, "main", "tgwol", translate("Service"))
s.anonymous = true
s.addremove = false

local en = s:option(Flag, "enabled", translate("Enable bot"),
	translate("Start the bot daemon at boot."))
en.default  = "0"
en.rmempty  = false
function en.write(self, section, value)
	Flag.write(self, section, value)
	if value == "1" then
		sys.call("/etc/init.d/tgwol enable >/dev/null 2>&1")
	else
		sys.call("/etc/init.d/tgwol disable >/dev/null 2>&1")
		sys.call("/etc/init.d/tgwol stop >/dev/null 2>&1")
	end
end

local tk = s:option(Value, "bot_token", translate("Bot token"),
	translate("Token from @BotFather."))
tk.password    = true
tk.placeholder = "1234567890:AA..."
tk.rmempty     = false

local mode = s:option(ListValue, "access_mode", translate("Access mode"))
mode:value("open",       translate("Open — anyone (DANGEROUS, do not use on prod)"))
mode:value("whitelist",  translate("Whitelist — only listed chat IDs"))
mode:value("admin_user", translate("Admin + User with explicit permissions"))
mode.default = "whitelist"

local poll = s:option(Value, "poll_timeout", translate("Long-poll timeout, sec"))
poll.datatype = "range(1,300)"
poll.default  = "50"

local lvl = s:option(ListValue, "log_level", translate("Log level"))
lvl:value("debug")
lvl:value("info")
lvl:value("warn")
lvl:value("err")
lvl.default = "info"

local kd = s:option(Value, "ssh_keydir", translate("SSH keys directory"))
kd.default = "/etc/tgwol/keys"

return m
