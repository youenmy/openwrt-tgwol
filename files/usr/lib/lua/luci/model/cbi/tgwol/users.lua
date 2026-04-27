local sys = require "luci.sys"

local m = Map("tgwol", translate("Пользователи / Доступ"),
	translate("Белый список пользователей Telegram и их права. " ..
		"В режиме <em>открытый</em> список игнорируется. В режиме <em>белый список</em> любой добавленный пользователь может делать всё. " ..
		"В режиме <em>admin+user</em> только администраторы имеют полный доступ; права пользователей ограничены чекбоксами разрешений."))

m.on_after_commit = function(self)
	sys.call("/etc/init.d/tgwol enabled && /etc/init.d/tgwol restart >/dev/null 2>&1 || true")
end

local s = m:section(TypedSection, "user", translate("Пользователи"))
s.anonymous = false
s.addremove = true
s.template  = "cbi/tblsection"

s:option(Value, "name", translate("Имя / метка"))

local cid = s:option(Value, "chat_id", translate("Telegram chat_id"),
	translate("Отправьте /id боту из своего Telegram-аккаунта, чтобы узнать его."))
cid.datatype = "uinteger"
cid.rmempty  = false

local role = s:option(ListValue, "role", translate("Роль"))
role:value("admin", translate("Администратор (все права, игнорирует разрешения)"))
role:value("user",  translate("Пользователь"))
role.default = "user"

local perms = s:option(MultiValue, "permissions", translate("Разрешения"),
	translate("Только для роли 'user'. Выберите 'all', чтобы разрешить всё."))
perms.widget    = "checkbox"
perms.delimiter = " "
perms:value("all",            translate("Все"))
perms:value("wake",           translate("Wake-on-LAN"))
perms:value("ping",           translate("Ping"))
perms:value("shutdown",       translate("Выключение ПК"))
perms:value("reboot",         translate("Перезагрузка ПК"))
perms:value("sleep",          translate("Сон ПК"))
perms:value("lock",           translate("Блокировка ПК"))
perms:value("router_status",  translate("Статус роутера"))
perms:value("router_clients", translate("Клиенты роутера"))
perms:value("router_reboot",  translate("Перезагрузка роутера"))

return m
