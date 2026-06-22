# AmneziaWG for Asuswrt-Merlin

![banner](assets/banner.jpg)


[[русский]](README.md) [[english]](README_EN.md)

💬 Обсуждение и помощь — [Telegram-чат сообщества](https://t.me/asusxray/26094)

VPN-клиент с обходом DPI-блокировок на базе [AmneziaWG](https://github.com/amnezia-vpn/amneziawg-go) с веб-интерфейсом для роутеров ASUS на прошивке [Asuswrt-Merlin](https://www.asuswrt-merlin.net/). Маршрутизация по устройствам и выборочная маршрутизация через GeoIP/GeoSite.

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

![widget](assets/widget.png)

<details>
<summary>Скриншот админки</summary>

![screenshot](assets/screenshot.png)

</details>

<details>
<summary>Скриншот Анализатора трафика</summary>

![analyse](assets/analyse.png)

</details>

## Changelog

Полный список изменений — в файле [CHANGELOG.md](CHANGELOG.md).

## Возможности

- **Протокол AmneziaWG** -- WireGuard с обфускацией DPI (Jc, Jmin, Jmax, S1-S4, H1-H4, I1-I5)
- **Userspace-демон** -- на базе [amneziawg-go](https://github.com/amnezia-vpn/amneziawg-go), без kernel module
- **Веб-интерфейс** -- страница-аддон в стиле ROG, встроенная в панель роутера (VPN > AmneziaWG)
- **Импорт конфига** -- загрузка `.conf` файла из клиента Amnezia VPN
- **Маршрутизация по устройствам** -- своя политика для каждого устройства: `VPN: весь трафик`, любая гео-политика, `Напрямую`
- **Несколько гео-политик** -- независимые гео-политики во вкладках (до 8); в каждой свой набор GeoIP / GeoSite / GeoCustom / Antifilter, устройство выбирает нужную. Одинаковые списки скачиваются в общий пул без дублей
- **Режим политики** -- *включение* (в VPN идёт то, что в списках) или *исключение* (в VPN идёт всё, **кроме** списков)
- **Точечные исключения** -- свои домены/IP/файлы/URL, которые вырезаются из политики (а в режиме исключения, наоборот, добавляются)
- **GeoIP по сервисам** -- IP-диапазоны Telegram, Google, Netflix, Twitter и др. через [Loyalsoldier/geoip](https://github.com/Loyalsoldier/geoip)
- **GeoSite по доменам** -- списки доменов через [v2fly/domain-list-community](https://github.com/v2fly/domain-list-community) + dnsmasq ipset
- **Geo Antifilter** -- готовые списки заблокированных в РФ подсетей/доменов через [antifilter.download](https://antifilter.download/)
- **GeoCustom — свои записи** -- ручное добавление доменов, CIDR-подсетей, своих файлов и URL-источников
- **Анализатор трафика** -- по каждому устройству видно, какие домены/соединения идут через VPN, а какие напрямую; пойманное добавляется в выбранную гео-политику одним кликом
- **Перехват DNS** -- принудительный DNS через dnsmasq, блокировка DoH/DoT для надёжной гео-маршрутизации
- **MSS clamping** -- автоматическое исправление TCP MSS для туннельного трафика
- **Автообновление** -- ежедневное обновление гео-списков по cron

## Требования

- [Прошивка Asuswrt-Merlin](https://www.asuswrt-merlin.net/download) (`384.15` и новее, `3006.x`)
- Установленный [Entware](https://github.com/Entware/Entware/wiki/Install-on-Asus-stock-firmware) (ставится через [amtm](https://diversion.ch/amtm.html))
- SSH-доступ к роутеру
- AmneziaWG-сервер (self-hosted) -- для быстрой установки сервера: [amneziawg-installer](https://github.com/bivlked/amneziawg-installer)

## Установка

### Быстрая установка (одна команда)

```shell
curl -sfL https://raw.githubusercontent.com/william-aqn/asuswrt-merlin-amneziawg/main/install-online.sh | sh
```

Скрипт автоматически определит архитектуру роутера, скачает нужный пакет из последнего релиза и установит.

**Если GitHub заблокирован (РФ):** установка через зеркало jsDelivr —

```shell
curl -sfL https://cdn.jsdelivr.net/gh/william-aqn/asuswrt-merlin-amneziawg@main/install-online.sh | sh
```

Скрипт сам скачает `.ipk` через зеркала и проверит его по SHA256.

### Из .ipk пакета

Скопируйте пакет на роутер и установите:

```shell
scp amneziawg_1.0.0-1_aarch64-3.10.ipk admin@<ip-роутера>:/tmp/
```

```shell
ssh admin@<ip-роутера>
opkg install /tmp/amneziawg_1.0.0-1_aarch64-3.10.ipk
```

### Ручная установка

Проект полностью **userspace**: демон `amneziawg-go` + утилита `awg`, без кастомного модуля ядра (нужен только штатный `tun`). Для чистой установки проще всего собрать `.ipk` (`./build-ipk.sh`) и поставить его через `opkg` (см. раздел «Из .ipk пакета») — пакет сам разложит бинарники в `/opt/amneziawg`, аддон в `/jffs/addons/amneziawg`, создаст init-скрипт `S99amneziawg` и зарегистрирует страницу.

Для быстрого обновления **только аддона** (бэкенд-скрипт и веб-страница) без пересборки бинарников — скопируйте файлы прямо в `/jffs/addons/amneziawg/` и перезапустите:

```shell
scp addon/amneziawg.sh addon/amneziawg_page.asp addon/amneziawg_widget.js admin@<ip-роутера>:/jffs/addons/amneziawg/
ssh admin@<ip-роутера>
/jffs/addons/amneziawg/amneziawg.sh install_page   # перерегистрировать страницу в меню роутера
/jffs/addons/amneziawg/amneziawg.sh restart         # перезапустить туннель с новым кодом
```

> `install.sh` в корне репозитория — устаревший инсталлятор для старого варианта с модулем ядра (`amneziawg.ko`); в текущей userspace-сборке он не используется.

> SCP-клиенты с графическим интерфейсом: для Windows — [WinSCP](https://winscp.net/eng/download.php), для macOS — [MacSCP](https://www.macscp.co/).

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

В «Правилах устройств» у каждого устройства выбирается политика:

| Политика | Описание |
|----------|----------|
| **VPN: весь трафик** | Весь трафик устройства через VPN |
| **VPN: \<имя гео-политики\>** | Маршрутизация по выбранной гео-политике (см. ниже). Таких пунктов столько, сколько создано гео-политик |
| **Напрямую** | Устройство обходит VPN |

### Гео-политики (вкладки)

Гео-политик может быть несколько (до 8) — они задаются **вкладками** (кнопка «+ Добавить гео политику»). В каждой вкладке свой независимый набор источников: **GeoIP**, **GeoSite**, **GeoCustom** (свои домены/IP/файлы/URL) и **Geo Antifilter**. Какое устройство по какой политике ходит — выбирается в «Правилах устройств».

Все политики идут в **один** туннель — различается только то, *какие* адреса в него попадают (у каждой политики свой `ipset`). Одинаковые списки в разных политиках скачиваются и хранятся **один раз** (общий пул); в туннель каждой политики попадает только выбранное именно в ней. На слабых роутерах общий бюджет `ipset` делится между политиками, чтобы не исчерпать память.

**Режим политики** — переключатель в начале вкладки:

| Режим | Поведение |
|-------|-----------|
| **В VPN по спискам** (включение) | В туннель идёт только совпавшее со списками; остальное — напрямую |
| **Напрямую по спискам** (исключение) | Наоборот: в туннель идёт весь трафик устройства, **кроме** того, что в списках |

> Режим исключения тянет почти весь трафик в туннель (как «весь трафик», но с вырезами) — учитывайте при сосуществовании с zapret/Xray/b4.

**Точечные исключения** — блок в конце вкладки (свои домены/IP/подсети/файлы/URL). Записи в нём ведут себя как исключения с учётом режима: в режиме включения идут **напрямую** (вырезаются из VPN), в режиме исключения — **в VPN**. Удобно, когда большой список (например категория GeoSite) тянет лишнее.

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

### Geo Antifilter

Готовые списки заблокированных в РФ ресурсов с [antifilter.download](https://antifilter.download/). Отмечайте нужные галочками — IP-списки грузятся в ipset этой гео-политики (рядом с GeoIP) и маршрутизируются через VPN:

- **allyouneed** (~15K) -- все нужные подсети (= `ipsum` + `subnet`); рекомендуемый выбор
- **community** (~900) -- подсети сообщества
- **ipsum** / **subnet** / **ip** (~48K) -- альтернативные срезы, сильно пересекаются с `allyouneed`
- **ipresolve** (~154K) -- IP из DNS-резолва; очень большой список
- **community домены** (~485) -- небольшой список доменов → dnsmasq

Полный `domains.lst` (1.4M доменов / 27 МБ) намеренно не подключается — он слишком велик для dnsmasq на роутере. Обновляются той же кнопкой **Update Now** и автообновлением, что и остальные гео-списки.

### GeoCustom — свои записи

- **Свои домены** -- домены через запятую/с новой строки (например `example.com,service.org`)
- **Свои IP / подсети** -- IP/CIDR через запятую (например `8.8.8.8,1.1.1.0/24`)
- **Свои файлы** -- именованные списки, которые можно вставить/отредактировать прямо в интерфейсе или загрузить из файла (домен → DNS, IP/подсеть → ipset; строки с `#` — комментарии)
- **URL-источники** -- ссылки на скачиваемые списки того же формата

Те же поля есть в блоке **«Точечные исключения»** — но там они работают как исключения (см. [Гео-политики](#гео-политики-вкладки)).

## Сборка из исходников

### Необходимо

- Docker Desktop
- Go 1.24+ (для amneziawg-go)
- GNU tar (`brew install gnu-tar` на macOS)

### Сборка amneziawg-go (userspace-демон)

```shell
git clone --depth 1 https://github.com/amnezia-vpn/amneziawg-go.git
cd amneziawg-go

# ARM64 (aarch64-3.10) — GT-AX11000, RT-AX86U, RT-AX88U
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -ldflags="-s -w" -o ../output/amneziawg-go

# ARM32 (armv7-2.6) — RT-AC68U, RT-AC66U, старые ARM-роутеры
CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=5 go build -ldflags="-s -w" -o ../output/amneziawg-go-arm5

# ARM32 (armv7-3.2) — RT-AX56U, RT-AX58U, новые HND-роутеры
CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 go build -ldflags="-s -w" -o ../output/amneziawg-go-arm
```

### Сборка awg CLI (через Docker)

```shell
# ARM64 (aarch64) — через основной Dockerfile
./build.sh

# ARM32 (static musl, для обоих armv7-2.6 и armv7-3.2)
DOCKER_BUILDKIT=1 docker build -f Dockerfile.arm32 --output=output .
```

### Сборка .ipk пакетов

```shell
./build-ipk.sh
```

Результат:
- `output/amneziawg_*_aarch64-3.10.ipk` -- ARM64 роутеры (GT-AX11000, RT-AX86U, RT-AX88U)
- `output/amneziawg_*_armv7-2.6.ipk` -- ARM32 старые роутеры (RT-AC68U, RT-AC66U)
- `output/amneziawg_*_armv7-3.2.ipk` -- ARM32 новые HND-роутеры (RT-AX56U, RT-AX58U)

## Управление через CLI

```shell
# Запуск/остановка/перезапуск
/opt/etc/init.d/S99amneziawg start
/opt/etc/init.d/S99amneziawg stop
/opt/etc/init.d/S99amneziawg restart

# Обновление программы до последней версии
/opt/etc/init.d/S99amneziawg update

# Установка конкретной версии (например, откат или фикс)
/opt/etc/init.d/S99amneziawg update 1.1.50

# Статус туннеля
awg show

# Обновить гео-списки
/jffs/addons/amneziawg/amneziawg.sh update_geo

# Диагностика (версия, платформа, бинарники, сеть, TUN — для отчёта о проблеме)
/jffs/addons/amneziawg/amneziawg.sh diag
```

> В веб-интерфейсе тот же отчёт можно получить кнопкой **«Получить диагностические данные»** в блоке «Журнал» — он сразу копируется в буфер обмена, обёрнутый в код-блок, готовый для вставки в Telegram.

## Удаление

```shell
/jffs/addons/amneziawg/amneziawg.sh uninstall
opkg remove amneziawg
```

## Архитектура

```
Интернет <-- awg0 (туннель) <-- iptables mangle цепочка AWG <-- br0 (устройства LAN)
                                          |
                            ipset каждой гео-политики: awg_dst, awg_dst2, …
                            (GeoIP/Antifilter CIDR + DNS-резолвы; у политики
                             с исключениями ещё свой awg_dst<id>_x)
                                          |
                                  fwmark 0x100 -> таблица маршрутов 300 -> awg0
```

| Компонент | Назначение |
|-----------|-----------|
| **amneziawg-go** | Userspace WireGuard-демон с расширениями AmneziaWG |
| **awg** | CLI-утилита для управления туннелем |
| **amneziawg.sh** | Backend: жизненный цикл, firewall, маршрутизация, гео-списки, перехват DNS |
| **amneziawg_page.asp** | Веб-интерфейс (страница аддона **VPN > AmneziaWG**) |
| **amneziawg_widget.js** | Глобальный виджет в шапке роутера: индикатор статуса ● AWG на всех страницах прошивки + мини-панель включения/выключения туннеля (отдаётся как `/www/user/awg_widget.js`, подгружается через `menuTree.js`) |

## FAQ

**В: Telegram не работает через VPN?**

О: Добавьте `telegram` в GeoIP Service Lists. Telegram подключается по IP напрямую -- доменных списков недостаточно.

**В: Сайты не открываются на iPhone с гео-политикой?**

О: iPhone использует зашифрованный DNS (DoH), который обходит dnsmasq роутера. Настройте DNS вручную: Настройки > Wi-Fi > (i) > DNS > Вручную > только IP роутера.

**В: Туннель работает для ping, но сайты не открываются?**

О: Перезапустите туннель с паузой: `/jffs/addons/amneziawg/amneziawg.sh stop; sleep 5; /jffs/addons/amneziawg/amneziawg.sh start`

**В: Как добавить свой сервис по IP?**

О: Добавьте CIDR-диапазоны в поле «Свои IP / подсети» (GeoCustom), например `149.154.160.0/20,91.108.4.0/22` для Telegram.

**В: Поддерживается ли ARM32 (RT-AC68U)?**

О: Да, есть отдельный .ipk для ARM32 (`armv7-2.6`).

**В: Можно ли использовать вместе с zapret2 или Xray (XRAYUI)?**

О: Да, но с оговорками. Аддон автоматически определяет рядом работающие DPI-обходы/прокси (zapret2/bol-van, Xray/XRAYUI, v2ray, sing-box, **b4**, а также правила NFQUEUE/TPROXY в iptables или nftables) и в этом случае **не включает перехват DNS** (DNAT на :53), чтобы не конфликтовать с ними -- иначе сеть может остаться без интернета. Этим управляет **«Режим совместимости»** (бывшая галочка «Не перехватывать DNS»): при чистой установке он включён по умолчанию, чтобы даже неизвестная утилита не оставила сеть без интернета; у обновлённых установок поведение прежнее, пока вы сами его не включите.

Важно: это снимает только конфликт по DNS. При политике по умолчанию **«VPN -- весь трафик»** маршрутизация всё равно заберёт трафик у соседнего прокси, поэтому для совместимости выбирайте политику **«Напрямую»** или **«VPN -- только Geo»**, а не «весь трафик». Geo-маршрутизация по IP при этом продолжает работать.

**В: `ipset` пишет `Warning: Kernel support protocol versions 6-6 while userspace supports protocol versions 6-7`?**

О: Это безвредное предупреждение, а не ошибка. Утилита `ipset` (и прошивочная `/usr/sbin/ipset`, и Entware `/opt/sbin/ipset`) собрана из более свежих исходников и умеет протокол версий 6 и 7, а модуль ipset в старом ядре роутера (4.1.51) реализует только версию 6. Диапазоны пересекаются на версии 6, поэтому утилита автоматически работает по ней -- всё функционирует штатно. Делать ничего не нужно; geo-роутинг через ipset (`awg_dst` и geo-ipset'ы) полностью работает на версии 6.

## Авторы

- **r0otx** -- [github.com/r0otx](https://github.com/r0otx)
- **william-aqn** -- [github.com/william-aqn](https://github.com/william-aqn)

## Поддержать проект

Если проект оказался полезен — можно поддержать разработку:

**Boosty:** [boosty.to/dcrm/donate](https://boosty.to/dcrm/donate)

**USDT (TRC-20):** `TC9MSnePyR6MBfSGU6WRCNEmCa5iyzmWUr`

## Благодарности

- [AmneziaWG](https://github.com/amnezia-vpn) -- протокол и реализации
- [Loyalsoldier/geoip](https://github.com/Loyalsoldier/geoip) -- GeoIP CIDR-списки сервисов
- [v2fly/domain-list-community](https://github.com/v2fly/domain-list-community) -- доменные списки
- [antifilter.download](https://antifilter.download/) -- РКН-списки (IP/подсети и домены)
- [Asuswrt-Merlin](https://www.asuswrt-merlin.net/) -- прошивка роутера
- [DanielLavrushin/asuswrt-merlin-xrayui](https://github.com/DanielLavrushin/asuswrt-merlin-xrayui) -- референс архитектуры маршрутизации

## Дисклеймер

Данный проект является техническим инструментом для обеспечения сетевой безопасности и приватности. Использование VPN в Российской Федерации не запрещено (по состоянию на март 2026). Автор не несёт ответственности за использование ПО в целях, противоречащих законодательству РФ или иных юрисдикций. Пользователь самостоятельно несёт ответственность за соблюдение применимого законодательства.

## Лицензия

MIT License
