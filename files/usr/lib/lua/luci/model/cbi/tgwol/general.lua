local sys = require "luci.sys"

local m = Map("tgwol", translate("Telegram WOL Bot — Основные настройки"),
	translate("Управление сервисом бота, токеном и режимом доступа. " ..
		"Устройства, пользователи и действия роутера настраиваются на других вкладках."))

m.on_after_commit = function(self)
	sys.call("/etc/init.d/tgwol enabled && /etc/init.d/tgwol restart >/dev/null 2>&1 || true")
end

local s = m:section(NamedSection, "main", "tgwol", translate("Сервис"))
s.anonymous = true
s.addremove = false

local en = s:option(Flag, "enabled", translate("Включить бота"),
	translate("Запускать демон бота при загрузке."))
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

local tk = s:option(Value, "bot_token", translate("Токен бота"),
	translate("Токен от @BotFather."))
tk.password    = true
tk.placeholder = "1234567890:AA..."
tk.rmempty     = false

local mode = s:option(ListValue, "access_mode", translate("Режим доступа"))
mode:value("open",       translate("Открытый — любой (ОПАСНО, не для продакшна)"))
mode:value("whitelist",  translate("Белый список — только указанные chat ID"))
mode:value("admin_user", translate("Администратор + Пользователь с явными правами"))
mode.default = "whitelist"

local poll = s:option(Value, "poll_timeout", translate("Таймаут long-poll, сек"))
poll.datatype = "range(1,300)"
poll.default  = "50"

local lvl = s:option(ListValue, "log_level", translate("Уровень логирования"))
lvl:value("debug")
lvl:value("info")
lvl:value("warn")
lvl:value("err")
lvl.default = "info"

local kd = s:option(Value, "ssh_keydir", translate("Директория SSH-ключей"))
kd.default = "/etc/tgwol/keys"

return m
