local sys = require "luci.sys"

local m = Map("tgwol", translate("Устройства"),
	translate("Компьютеры, управляемые ботом. Каждое устройство получает собственную карточку с WoL, пингом и SSH-командами в Telegram."))

m.on_after_commit = function(self)
	sys.call("/etc/init.d/tgwol enabled && /etc/init.d/tgwol restart >/dev/null 2>&1 || true")
end

local s = m:section(TypedSection, "device", translate("Устройства"))
s.anonymous = false
s.addremove = true
s.template  = "cbi/tblsection"
s.extedit   = false

s:option(Value, "name", translate("Название")).rmempty = false

local mac = s:option(Value, "mac", translate("MAC"))
mac.datatype = "macaddr"
mac.rmempty  = false
mac.placeholder = "AA:BB:CC:DD:EE:FF"

local ip = s:option(Value, "ip", translate("IP / имя хоста"))
ip.placeholder = "192.168.1.100"

local bcast = s:option(Value, "broadcast", translate("Широковещательный адрес"))
bcast.default = "255.255.255.255"

local iface = s:option(Value, "wol_iface", translate("Интерфейс (etherwake -i)"),
	translate("Необязательно. Сетевой интерфейс для отправки magic-пакета."))

local os = s:option(ListValue, "os", translate("ОС"),
	translate("Используется для выбора команд выключения/сна/блокировки по умолчанию."))
os:value("windows", "Windows")
os:value("linux",   "Linux")
os:value("macos",   "macOS")
os.default = "windows"

s:option(Value, "ssh_host", translate("SSH-хост"),
	translate("Если пусто — используется поле IP."))
s:option(Value, "ssh_user", translate("SSH-пользователь"))
local sport = s:option(Value, "ssh_port", translate("SSH-порт"))
sport.datatype = "port"
sport.default  = "22"

s:option(Value, "ssh_key", translate("Путь к SSH-ключу"),
	translate("Путь на роутере. Создать: tgwol-cli add-key &lt;имя&gt;"))

local au = s:option(DynamicList, "allowed_users", translate("Разрешённые пользователи"),
	translate("Telegram chat ID, которым разрешено управлять этим устройством. Используйте 'all', чтобы разрешить всем пользователям, прошедшим глобальный режим доступа."))
au.default = "all"

return m
