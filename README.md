# OpenWRT Telegram WOL Bot

Лёгкий Telegram-бот для OpenWRT (24.10+), который умеет:

- 🛏 **Wake-on-LAN** домашнего ПК (через `etherwake`)
- 📡 **Ping** устройств в локалке
- 🔌 **Shutdown / Reboot / Sleep / Lock** удалённого ПК (по SSH; Windows / Linux / macOS)
- 🌐 **Управление роутером**: статус (uptime / load / mem / WAN IP), список DHCP-клиентов, ребут, произвольный shell
- 🔐 **Гибкий ACL**: режимы `open` / `whitelist` / `admin+user`, пермишены на действия и устройства
- 🖱 **LuCI-интерфейс** в `Services → Telegram WOL Bot` (General / Devices / Users / Router / Status)

Без Python, без Node — только `ash` + BusyBox + `curl` + `jsonfilter`. Подходит для самых скромных роутеров.

---

## Установка одной строкой

```sh
ssh root@<router-ip>
curl -fsSL https://raw.githubusercontent.com/youenmy/openwrt-tgwol/main/install.sh | sh
```

Установщик:

1. Поставит зависимости: `curl`, `etherwake`, `jsonfilter`, `openssh-client`, `luci-base`, `luci-compat`.
2. Скачает бот, init-скрипт, библиотеку, LuCI-страницы.
3. Создаст `/etc/config/tgwol` (если его нет) и каталог для SSH-ключей.
4. Если запуск интерактивный (TTY есть) — спросит токен бота, твой `chat_id`, MAC/IP домашнего ПК и включит сервис.
5. Сбросит кеш LuCI.

Без интерактива:

```sh
curl -fsSL .../install.sh | sh -s -- --no-prompt
```

И затем настроить руками — через LuCI или CLI.

---

## После установки

### Через веб-интерфейс

`http://<router>/cgi-bin/luci → Services → Telegram WOL Bot`

Вкладки:

- **General** — токен `@BotFather`, режим доступа, log level.
- **Devices** — список устройств: имя, MAC, IP, OS, broadcast, SSH-параметры, кому разрешено.
- **Users / Access** — белый список chat_id, роли, пермишены.
- **Router actions** — какие действия с роутером бот вообще может делать.
- **Status** — статус демона + лог + кнопки start/stop/restart + ответ Telegram `getMe`.

### Через CLI

```sh
tgwol-cli set-token 1234567890:AAAA...
tgwol-cli add-key home_pc          # генерит ed25519, печатает pubkey
tgwol-cli list-devices
tgwol-cli wake pc1                 # тестовый WoL
tgwol-cli ping pc1
tgwol-cli test-token               # вызывает getMe
tgwol-cli reload
```

Публичный ключ из `add-key` положи в `authorized_keys` на целевой машине:

- **Windows 10/11**: установить «OpenSSH Server» (Settings → Optional Features), запустить службу `sshd`, и добавить ключ в `C:\Users\<user>\.ssh\authorized_keys`. Для админ-аккаунтов также — в `C:\ProgramData\ssh\administrators_authorized_keys` (см. документацию MS).
- **Linux**: `~/.ssh/authorized_keys` (chmod 600).

### В Telegram

1. Создай бота у `@BotFather`, получи токен → введи в LuCI или `tgwol-cli set-token`.
2. Напиши боту `/id` — он ответит твоим `chat_id`.
3. Добавь его в **Users** (роль `admin`, или `user` с нужными permissions).
4. `/start` — главное меню с кнопками.

Команды:

| Команда | Что делает |
|---------|-----------|
| `/start`, `/menu` | Главное меню (inline keyboard) |
| `/id` | Узнать свой chat_id |
| `/help` | Справка по командам |
| `/wake [name]` | Разбудить устройство (или показать выбор) |
| `/ping [name]` | Ping |
| `/shutdown [name]` | Выключить (по SSH) |
| `/reboot [name]` | Перезагрузить |
| `/sleep [name]` | Усыпить |
| `/lock [name]` | Заблокировать сессию |
| `/status` | Статус роутера |
| `/clients` | DHCP-клиенты |
| `/sh <cmd>` | Shell-команда (admin only, нужно включить в Router actions) |

---

## Конфиг `/etc/config/tgwol`

```
config tgwol 'main'
	option enabled '1'
	option bot_token '1234567890:AA...'
	option access_mode 'whitelist'        # open | whitelist | admin_user
	option poll_timeout '50'
	option log_level 'info'
	option ssh_keydir '/etc/tgwol/keys'

config user 'admin'
	option name 'Admin'
	option chat_id '111111111'
	option role 'admin'
	list permissions 'all'

config device 'pc1'
	option name 'Home PC'
	option mac 'AA:BB:CC:DD:EE:FF'
	option ip '192.168.1.100'
	option broadcast '192.168.1.255'
	option os 'windows'                   # windows | linux | macos
	option ssh_host '192.168.1.100'
	option ssh_user 'admin'
	option ssh_port '22'
	option ssh_key '/etc/tgwol/keys/home_pc'
	list allowed_users 'all'              # или конкретные chat_id

config router 'router'
	option allow_status '1'
	option allow_clients '1'
	option allow_reboot '0'
	option allow_shell '0'
```

После правки руками — `/etc/init.d/tgwol restart`.

---

## Режимы доступа

- **open** — любой, кто знает бота, может всё. Очень опасно. Используй разве что в изолированной сети.
- **whitelist** (рекомендуется) — только перечисленные `chat_id`, и они могут всё.
- **admin_user** — `admin` может всё, `user` ограничен permissions из его секции.

`allowed_users` per-device ограничивает доступ к конкретному устройству независимо от глобальных permissions.

---

## Безопасность

- `bot_token` хранится в `/etc/config/tgwol` (`chmod 600`). Не публикуй конфиг.
- SSH-ключи в `/etc/tgwol/keys` (`chmod 700`).
- Включай `allow_shell` только если очень понимаешь риски — это полный shell на роутере под `root`.
- Trafic Telegram идёт через HTTPS на `api.telegram.org` (certificate pinning не используется — обычный CA).
- Long-poll наружу никаких портов **не открывает**, всё работает по исходящему HTTPS.

---

## Структура репозитория

```
openwrt-tgwol/
├── README.md
├── install.sh
├── uninstall.sh
└── files/
    ├── etc/
    │   ├── config/tgwol                              # дефолтный UCI
    │   └── init.d/tgwol                              # procd-сервис
    └── usr/
        ├── bin/
        │   ├── tgwol-bot                             # главный демон
        │   └── tgwol-cli                             # CLI/админка
        ├── share/
        │   ├── tgwol/lib.sh                          # общая библиотека
        │   └── rpcd/acl.d/luci-app-tgwol.json        # ACL для rpcd
        └── lib/lua/luci/
            ├── controller/tgwol.lua                  # меню + action handler
            ├── model/cbi/tgwol/                      # CBI-страницы
            │   ├── general.lua
            │   ├── devices.lua
            │   ├── users.lua
            │   └── router.lua
            └── view/tgwol/status.htm                 # страница статуса
```

---

## Снос

```sh
curl -fsSL https://raw.githubusercontent.com/youenmy/openwrt-tgwol/main/uninstall.sh | sh
# или с очисткой конфигов и ключей:
curl -fsSL .../uninstall.sh | sh -s -- --purge
```

---

## Troubleshooting

- **Бот не отвечает** → `logread -e tgwol` и Status-вкладка в LuCI. Проверь токен через `tgwol-cli test-token`.
- **Magic packet уходит, но ПК не просыпается** → BIOS/UEFI: включить «Wake on LAN», в Windows — в свойствах сетевой карты вкладка Power Management → Allow this device to wake the computer.
- **SSH не работает** → проверь `tgwol-cli list-devices`, путь к ключу, `authorized_keys` на цели. Тест: `ssh -i /etc/tgwol/keys/home_pc -p 22 user@host whoami`.
- **Меню в LuCI не появляется** → `rm -rf /tmp/luci-*cache && /etc/init.d/uhttpd restart`. Убедись что установлен `luci-compat`.
- **`curl: Resolving timed out`** → проверь DNS на роутере и доступность `api.telegram.org`.

---

MIT License.
