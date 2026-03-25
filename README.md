# AmneziaWG for Asuswrt-Merlin

[[русский]](README.md) [[english]](README_EN.md)

VPN-клиент с обходом DPI-блокировок на базе [AmneziaWG](https://docs.amnezia.org/documentation/amnezia-wg/) с веб-интерфейсом для роутеров ASUS на прошивке [Asuswrt-Merlin](https://www.asuswrt-merlin.net/). Маршрутизация по устройствам и выборочная маршрутизация через GeoIP/GeoSite.

Полностью userspace-реализация -- не требует kernel module, работает на любой версии ядра.

<details>
    <summary>Поддерживаемые устройства</summary>

Все роутеры aarch64 (ARM64) с Asuswrt-Merlin (`384.15` и новее, `3006.x`) и установленным Entware:

- GT-AX11000
- GT-AXE11000
- GT-AX6000
- RT-AX86U
- RT-AX86U Pro
- RT-AX88U
- RT-AX88U Pro
- RT-AX58U
- RT-AX56U
- TUF-AX5400

Другие aarch64 роутеры с Merlin тоже должны работать.

</details>

## Возможности

- **Протокол AmneziaWG** -- WireGuard с обфускацией DPI (Jc, Jmin, Jmax, S1-S4, H1-H4, I1-I5)
- **Userspace-демон** -- на базе [amneziawg-go](https://github.com/amnezia-vpn/amneziawg-go), без kernel module
- **Веб-интерфейс** -- страница-аддон в стиле ROG, встроенная в панель роутера (VPN > AmneziaWG)
- **Импорт конфига** -- загрузка `.conf` файла из клиента Amnezia VPN
- **Маршрутизация по устройствам** -- политика VPN для каждого устройства: `VPN All`, `VPN Geo`, `Direct`
- **GeoIP по сервисам** -- IP-диапазоны Telegram, Google, Netflix, Twitter и др. через [Loyalsoldier/geoip](https://github.com/Loyalsoldier/geoip)
- **GeoSite по доменам** -- списки доменов через [v2fly/domain-list-community](https://github.com/v2fly/domain-list-community) + dnsmasq ipset
- **Свои домены и IP** -- ручное добавление доменов и CIDR-подсетей
- **Перехват DNS** -- принудительный DNS через dnsmasq, блокировка DoH/DoT для надёжной гео-маршрутизации
- **MSS clamping** -- автоматическое исправление TCP MSS для туннельного трафика
- **Автообновление** -- ежедневное обновление гео-списков по cron

## Требования

- [Прошивка Asuswrt-Merlin](https://www.asuswrt-merlin.net/download) (`384.15` и новее, `3006.x`)
- Установленный [Entware](https://github.com/Entware/Entware/wiki/Install-on-Asus-stock-firmware) (ставится через [amtm](https://diversion.ch/amtm.html))
- SSH-доступ к роутеру
- AmneziaWG-сервер (например из [Amnezia VPN](https://amnezia.org/))

## Установка

### Из .ipk пакета (рекомендуется)

Скопируйте пакет на роутер и установите:

```shell
scp amneziawg_1.0.0-1_aarch64-3.10.ipk admin@<ip-роутера>:/tmp/
```

```shell
ssh admin@<ip-роутера>
opkg install /tmp/amneziawg_1.0.0-1_aarch64-3.10.ipk
```

### Ручная установка

```shell
scp output/amneziawg-go output/awg admin@<ip-роутера>:/tmp/
scp addon/amneziawg.sh addon/amneziawg_page.asp admin@<ip-роутера>:/tmp/
scp install.sh admin@<ip-роутера>:/tmp/
ssh admin@<ip-роутера>
sh /tmp/install.sh
```

### После установки

1. Выйдите и войдите заново в веб-интерфейс роутера
2. Перейдите в **VPN > AmneziaWG**
3. Нажмите **Import Config** и загрузите `.conf` файл из клиента Amnezia VPN
4. Нажмите **Apply**

## Использование

### Быстрый старт

1. Экспортируйте конфиг из клиента Amnezia VPN (файл `.conf`)
2. В интерфейсе роутера: **VPN > AmneziaWG > Import Config** -- загрузите файл
3. Нажмите **Apply** -- туннель запустится автоматически
4. Добавьте устройства в разделе **Device Rules** с нужной политикой

### Политики маршрутизации

| Политика | Описание |
|----------|----------|
| **VPN All** | Весь трафик устройства через VPN |
| **VPN Geo** | Только трафик к GeoIP/GeoSite-адресам через VPN |
| **Direct** | Устройство обходит VPN |

### GeoIP Service Lists

Введите имена сервисов через запятую для маршрутизации их IP-диапазонов через VPN:

```
telegram,google,facebook,twitter,netflix,cloudflare
```

Работают по IP -- не зависят от DNS, идеальны для Telegram и других приложений, которые подключаются напрямую по IP.

### GeoSite Service Lists

Введите имена сервисов для маршрутизации по доменам через dnsmasq:

```
youtube,google,discord,netflix,spotify,instagram
```

Требует чтобы устройства использовали роутер как DNS-сервер. Для iPhone: **Настройки > Wi-Fi > (i) > DNS > Вручную > только IP роутера**.

### Свои записи

- **Custom Domains** -- домены через запятую (например `example.com,service.org`)
- **Custom IPs** -- IP/CIDR через запятую (например `8.8.8.8,1.1.1.0/24`)

## Сборка из исходников

### Необходимо

- Docker Desktop
- Go 1.24+ (для amneziawg-go)
- GNU tar (`brew install gnu-tar` на macOS)

### Сборка amneziawg-go (userspace-демон)

```shell
git clone --depth 1 https://github.com/amnezia-vpn/amneziawg-go.git
cd amneziawg-go
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -ldflags="-s -w" -o ../output/amneziawg-go
```

### Сборка awg CLI (через Docker)

```shell
./build.sh
```

### Сборка .ipk пакетов

```shell
./build-ipk.sh
```

Результат:
- `output/amneziawg_1.0.0-1_aarch64-3.10.ipk` -- ARM64 роутеры
- `output/amneziawg_1.0.0-1_armv7-2.6.ipk` -- ARM32 роутеры

## Управление через CLI

```shell
# Запуск/остановка/перезапуск
/opt/etc/init.d/S99amneziawg start
/opt/etc/init.d/S99amneziawg stop
/opt/etc/init.d/S99amneziawg restart

# Статус туннеля
awg show

# Обновить гео-списки
/jffs/addons/amneziawg/amneziawg.sh update_geo
```

## Удаление

```shell
/jffs/addons/amneziawg/amneziawg.sh uninstall
opkg remove amneziawg
```

## Архитектура

```
Интернет <-- awg0 (туннель) <-- iptables mangle цепочка AWG <-- br0 (устройства LAN)
                                          |
                                  ipset awg_dst (GeoIP CIDR + DNS-резолвы)
                                          |
                                  fwmark 0x100 -> таблица маршрутов 300 -> awg0
```

| Компонент | Назначение |
|-----------|-----------|
| **amneziawg-go** | Userspace WireGuard-демон с расширениями AmneziaWG |
| **awg** | CLI-утилита для управления туннелем |
| **amneziawg.sh** | Backend: жизненный цикл, firewall, маршрутизация, гео-списки, перехват DNS |
| **amneziawg_page.asp** | Веб-интерфейс (аддон для Merlin) |

## FAQ

**В: Telegram не работает через VPN?**

О: Добавьте `telegram` в GeoIP Service Lists. Telegram подключается по IP напрямую -- доменных списков недостаточно.

**В: Сайты не открываются на iPhone с политикой VPN Geo?**

О: iPhone использует зашифрованный DNS (DoH), который обходит dnsmasq роутера. Настройте DNS вручную: Настройки > Wi-Fi > (i) > DNS > Вручную > только IP роутера.

**В: Туннель работает для ping, но сайты не открываются?**

О: Перезапустите туннель с паузой: `/jffs/addons/amneziawg/amneziawg.sh stop; sleep 5; /jffs/addons/amneziawg/amneziawg.sh start`

**В: Как добавить свой сервис по IP?**

О: Добавьте CIDR-диапазоны в поле Custom IPs, например `149.154.160.0/20,91.108.4.0/22` для Telegram.

**В: Поддерживается ли ARM32 (RT-AC68U)?**

О: Да, есть отдельный .ipk для ARM32 (`armv7-2.6`).

## Автор

**r0otx** -- [github.com/r0otx](https://github.com/r0otx)

## Благодарности

- [AmneziaWG](https://github.com/amnezia-vpn) -- протокол и реализации
- [Loyalsoldier/geoip](https://github.com/Loyalsoldier/geoip) -- GeoIP CIDR-списки сервисов
- [v2fly/domain-list-community](https://github.com/v2fly/domain-list-community) -- доменные списки
- [Asuswrt-Merlin](https://www.asuswrt-merlin.net/) -- прошивка роутера
- [DanielLavrushin/asuswrt-merlin-xrayui](https://github.com/DanielLavrushin/asuswrt-merlin-xrayui) -- референс архитектуры маршрутизации

## Дисклеймер

Данный проект является техническим инструментом для обеспечения сетевой безопасности и приватности. Использование VPN в Российской Федерации не запрещено (по состоянию на март 2026). Автор не несёт ответственности за использование ПО в целях, противоречащих законодательству РФ или иных юрисдикций. Пользователь самостоятельно несёт ответственность за соблюдение применимого законодательства.

## Лицензия

MIT License
