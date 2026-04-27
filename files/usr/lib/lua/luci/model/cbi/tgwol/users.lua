local sys = require "luci.sys"

local m = Map("tgwol", translate("Users / Access"),
	translate("Whitelist of Telegram users and their permissions. " ..
		"In <em>open</em> mode this list is ignored. In <em>whitelist</em> mode any listed user can do anything. " ..
		"In <em>admin+user</em> mode only admins have full access; users are limited by the Permissions checkboxes."))

m.on_after_commit = function(self)
	sys.call("/etc/init.d/tgwol enabled && /etc/init.d/tgwol restart >/dev/null 2>&1 || true")
end

local s = m:section(TypedSection, "user", translate("Users"))
s.anonymous = false
s.addremove = true
s.template  = "cbi/tblsection"

s:option(Value, "name", translate("Name / label"))

local cid = s:option(Value, "chat_id", translate("Telegram chat_id"),
	translate("Send /id to the bot from your Telegram account to find it."))
cid.datatype = "uinteger"
cid.rmempty  = false

local role = s:option(ListValue, "role", translate("Role"))
role:value("admin", translate("Admin (all rights, ignores permissions)"))
role:value("user",  translate("User"))
role.default = "user"

local perms = s:option(MultiValue, "permissions", translate("Permissions"),
	translate("For 'user' role only. Pick 'all' to allow everything."))
perms.widget    = "checkbox"
perms.delimiter = " "
perms:value("all",            translate("All"))
perms:value("wake",           translate("Wake-on-LAN"))
perms:value("ping",           translate("Ping"))
perms:value("shutdown",       translate("Shutdown PC"))
perms:value("reboot",         translate("Reboot PC"))
perms:value("sleep",          translate("Sleep PC"))
perms:value("lock",           translate("Lock PC"))
perms:value("router_status",  translate("Router status"))
perms:value("router_clients", translate("Router clients"))
perms:value("router_reboot",  translate("Router reboot"))

return m
