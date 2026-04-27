local sys = require "luci.sys"

local m = Map("tgwol", translate("Действия роутера"),
	translate("Включите или отключите действия роутера, доступные через бота."))

m.on_after_commit = function(self)
	sys.call("/etc/init.d/tgwol enabled && /etc/init.d/tgwol restart >/dev/null 2>&1 || true")
end

local s = m:section(NamedSection, "router", "router", translate("Разрешённые действия"))
s.anonymous = true
s.addremove = false

s:option(Flag, "allow_status",  translate("Статус (аптайм / нагрузка / память / WAN IP)")).default = "1"
s:option(Flag, "allow_clients", translate("Список DHCP-клиентов")).default = "1"
s:option(Flag, "allow_reboot",  translate("Перезагрузить роутер")).default = "0"
s:option(Flag, "allow_shell",   translate("Произвольная shell-команда (только admin, ОПАСНО)")).default = "0"
s:option(Flag, "allow_speedtest", translate("Тест скорости (требует speedtest-cli)")).default = "0"

return m
