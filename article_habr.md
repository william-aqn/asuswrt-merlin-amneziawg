# AmneziaWG на роутере ASUS с Merlin: обход DPI без сервера-посредника

Когда VPN на телефоне уже не спасает, а DPI провайдера научился резать WireGuard за секунды — приходит время переносить обфускацию на роутер. В этой статье расскажу, как я сделал полноценный аддон для Asuswrt-Merlin с веб-интерфейсом, выборочной маршрутизацией и поддержкой AmneziaWG 2.0 — и почему пришлось отказаться от kernel module в пользу userspace.

## Проблема

У меня ASUS GT-AX11000 с прошивкой Asuswrt-Merlin. Обычный WireGuard на роутере через встроенный клиент Merlin работает, но провайдер его видит и режет. AmneziaWG решает эту проблему за счёт обфускации — DPI не может отличить трафик от обычного UDP.

На телефоне и ПК есть клиент Amnezia VPN, и там всё работает. Но хочется:

- Один туннель на весь дом — а не VPN на каждом устройстве
- Выборочную маршрутизацию — YouTube через VPN, банк напрямую
- Управление через веб-интерфейс роутера — без SSH для каждого изменения
- Поддержку AmneziaWG 2.0 — с новыми параметрами I1-I5 для мимикрии трафика

## Первый подход: kernel module

AmneziaWG — это форк WireGuard с дополнительными параметрами обфускации. Есть [kernel module](https://github.com/amnezia-vpn/amneziawg-linux-kernel-module), который компилируется как out-of-tree модуль для Linux.

Проблема: роутер работает на ядре 4.1.51 (Broadcom HND). Модуль нужно кросс-компилировать с Broadcom toolchain под конкретную версию ядра. Собрал Docker-окружение, модуль скомпилировался, загрузился — handshake проходит, ping работает.

Но TCP умирал через 2 минуты.

Handshake свежий, ICMP работает, а TCP — нет. Каждый раз через ~2 минуты (интервал key rotation в WireGuard). Перезапуск помогал, но ненадолго. На десктопном клиенте с тем же сервером — всё идеально.

После долгих разбирательств стало ясно: проблема в kernel module на старом ядре 4.1.51. Что-то ломается при ротации ключей.

## Решение: userspace

У AmneziaWG есть [amneziawg-go](https://github.com/amnezia-vpn/amneziawg-go) — userspace реализация на Go, форк wireguard-go. Это то же самое, что использует десктопный клиент.

```bash
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -ldflags="-s -w" -o amneziawg-go
```

3.1 MB, статический бинарник, работает на любом ядре. Никаких vermagic, никаких проблем с совместимостью.

Результат: TCP стабилен, key rotation работает, туннель не падает. Проблема со стабильностью решена полностью.

## Архитектура маршрутизации

Изучил как сделана маршрутизация в [xrayui](https://github.com/DanielLavrushin/asuswrt-merlin-xrayui) — аналогичном аддоне для Xray. Там используется TPROXY для перехвата всего трафика и инспекция SNI на уровне приложения. У нас нет прокси-приложения, только WireGuard-туннель, поэтому подход другой:

### Кастомная iptables-цепочка

Все правила живут в отдельной цепочке `AWG` в таблице mangle. Очистка — одна команда `iptables -t mangle -F AWG`. Никакого ручного удаления отдельных правил.

```
mangle PREROUTING → AWG chain:
  1. dst-type LOCAL → RETURN          # трафик к роутеру
  2. dst LAN → RETURN                 # LAN-to-LAN
  3. udp dports 67,68,123 → RETURN    # DHCP, NTP
  4. dst 224.0.0.0/4 → RETURN         # multicast
  5. dst VPN_ENDPOINT → RETURN        # защита от петель
  6. [direct devices → RETURN]         # исключения
  7. [vpn_all devices → MARK 0x100]    # весь трафик через VPN
  8. [vpn_geo devices + ipset → MARK]  # выборочно через VPN
  9. [default policy]                   # для остальных
```

Помеченный трафик (fwmark 0x100) уходит в routing table 300, где маршруты через `awg0`.

### Три политики на устройство

- **VPN All** — весь трафик через VPN
- **VPN Geo** — только трафик к IP из GeoIP/GeoSite списков
- **Direct** — устройство обходит VPN

### GeoIP по сервисам

IP-диапазоны для Telegram, Google, Netflix и других сервисов из [Loyalsoldier/geoip](https://github.com/Loyalsoldier/geoip). Это CIDR-блоки, они не зависят от DNS — трафик матчится по IP назначения напрямую.

```
telegram,google,facebook,twitter,netflix,cloudflare
```

Скрипт скачивает текстовые файлы с CIDR-блоками и загружает в ipset `awg_dst`.

### GeoSite по доменам

Доменные списки из [v2fly/domain-list-community](https://github.com/v2fly/domain-list-community) — 1400+ категорий. Работают через dnsmasq ipset: когда устройство резолвит домен, IP попадает в ipset, и последующий трафик маркируется.

```
youtube,google,discord,netflix,spotify,instagram
```

## Грабли на пути

### 1. iPhone и зашифрованный DNS

Потратил несколько часов на дебаг: правила iptables на месте, ipset наполнен, а iPhone видит прямой IP. Оказалось — iPhone использует DNS-over-HTTPS, обходя dnsmasq роутера. Домен резолвится через Apple DoH, IP не попадает в ipset.

**Решение:** принудительный перехват DNS + блокировка DoH/DoT:

```bash
# Перенаправить весь DNS на роутер
iptables -t nat -I PREROUTING -i br0 -p udp --dport 53 -j DNAT --to $ROUTER_IP
# Заблокировать DNS-over-TLS
iptables -I FORWARD -i br0 -p tcp --dport 853 -j REJECT
# Заблокировать DoH к известным провайдерам
for ip in 8.8.8.8 8.8.4.4 1.1.1.1 1.0.0.1 9.9.9.9; do
    iptables -I FORWARD -i br0 -d $ip -p tcp --dport 443 -j REJECT
    iptables -I FORWARD -i br0 -d $ip -p udp --dport 443 -j REJECT
done
```

Но это не помогает полностью — iPhone использует Apple DoH серверы (17.x.x.x), которых слишком много для блокировки. Финальное решение: ручной DNS на устройстве (IP роутера) для политики VPN Geo.

Для политики VPN All это не проблема — весь трафик и так идёт через VPN.

### 2. rp_filter и forwarded трафик

Ping с роутера через туннель работает, а трафик с LAN-устройств — нет. Причина: `rp_filter` (reverse path filter). Ответные пакеты приходят на `awg0`, но после conntrack de-NAT имеют dst из LAN. Ядро считает это подозрительным и дропает.

Важный нюанс: effective rp_filter = MAX(conf/all, conf/interface). Недостаточно отключить на `awg0` — нужно и на `all`:

```bash
for iface in all awg0 br0; do
    echo 0 > /proc/sys/net/ipv4/conf/$iface/rp_filter
done
```

### 3. MSS clamping

TCP SYN проходит, SYN-ACK возвращается, а данные — нет. Классическая MTU/MSS проблема. Десктопный клиент делает MSS clamping автоматически, на роутере нужно явно:

```bash
iptables -t mangle -A FORWARD -o awg0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
iptables -t mangle -A FORWARD -i awg0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
```

### 4. Теги v2fly ломали dnsmasq

В v2fly domain list домены могут иметь теги: `cici.com:@!cn`. Эти теги попадали в dnsmasq конфиг и ломали его — dnsmasq не запускался. Пришлось чистить:

```bash
domain=$(echo "$domain" | sed 's/^\.//;s/:@[^ ]*$//')
```

И уменьшить количество доменов на строку с 80 до 20 — dnsmasq не переваривал слишком длинные строки ipset.

### 5. Telegram и прямые IP

Добавил `telegram` в GeoSite (доменные списки) — не работает. Telegram подключается напрямую по IP, минуя DNS. Нужны GeoIP CIDR-блоки, не домены. Для этого добавил отдельную секцию GeoIP Service Lists с автодополнением.

## Веб-интерфейс

Аддон встраивается в стандартный веб-интерфейс Merlin через Addons API:

- **Import Config** — загрузка `.conf` файла из клиента Amnezia VPN (все поля включая I1-I5 заполняются автоматически)
- **Device Rules** — таблица устройств с выбором политики и добавлением из DHCP-списка
- **GeoIP Service Lists** — IP-диапазоны по сервисам с автодополнением
- **GeoSite Service Lists** — домены по сервисам с автодополнением из v2fly базы (1400+ категорий)
- **Custom Domains / IPs** — ручные записи
- **Start / Stop / Apply** — управление туннелем

При нажатии Apply скрипт проверяет, какие GeoIP списки отсутствуют, и скачивает только недостающие. Update Now принудительно обновляет все списки.

## Entware .ipk пакет

Для простоты установки собирается .ipk пакет:

```bash
./build-ipk.sh
# output/amneziawg_1.0.1-1_aarch64-3.10.ipk  (ARM64)
# output/amneziawg_1.0.1-1_armv7-2.6.ipk      (ARM32)
```

Установка на роутере:

```bash
opkg install /tmp/amneziawg_1.0.1-1_aarch64-3.10.ipk
```

Post-install скрипт создаёт `/dev/net/tun`, устанавливает web UI, настраивает автозапуск.

Важный нюанс: Entware на Merlin использует tar.gz формат для .ipk, а не ar (как Debian). Это стоило дополнительного часа дебага.

## Что в итоге

| Компонент | Решение |
|-----------|---------|
| VPN-протокол | AmneziaWG 2.0 (обход DPI) |
| Реализация | userspace (amneziawg-go) |
| Маршрутизация | iptables mangle + ipset + fwmark |
| GeoIP | Loyalsoldier/geoip (CIDR по сервисам) |
| GeoSite | v2fly/domain-list-community (домены) |
| DNS | Принудительный dnsmasq + блокировка DoH/DoT |
| Пакет | Entware .ipk (ARM64 + ARM32) |
| UI | Merlin Addons API |

Поддерживаются все aarch64 роутеры с Merlin (GT-AX11000, RT-AX86U, RT-AX88U и др.) и ARM32 модели (RT-AC68U). Kernel module не нужен — userspace работает на любом ядре.

## Правовой аспект

На момент публикации (март 2026) использование VPN в России **не запрещено** и не является правонарушением.

Федеральный закон № 281-ФЗ от 31.07.2025, вступивший в силу 1 сентября 2025 года, вводит административную ответственность за **умышленный поиск и доступ к материалам из реестра экстремистских** (штраф 3 000 — 5 000 руб.), а также за **рекламу средств обхода блокировок** (штраф до 500 000 руб.). При этом само использование VPN для обеспечения приватности, безопасности и защиты персональных данных закон не затрагивает.

Депутат Госдумы Антон Горелкин (зампред комитета по информполитике) публично подтвердил: *«введение штрафов за использование VPN не планируется и даже не обсуждается»*.

Данный проект является техническим инструментом для обеспечения сетевой безопасности и приватности. Автор не несёт ответственности за использование программного обеспечения в целях, противоречащих законодательству Российской Федерации или иных юрисдикций. Пользователь самостоятельно несёт ответственность за соблюдение применимого законодательства.

## Ссылки

- **Проект:** [github.com/r0otx/asuswrt-merlin-amneziawg](https://github.com/r0otx/asuswrt-merlin-amneziawg)
- **AmneziaWG 2.0:** [habr.com/ru/companies/amnezia/articles/1014636](https://habr.com/ru/companies/amnezia/articles/1014636/)
- **Amnezia VPN:** [amnezia.org](https://amnezia.org/)
- **Loyalsoldier/geoip:** [github.com/Loyalsoldier/geoip](https://github.com/Loyalsoldier/geoip)
- **v2fly domains:** [github.com/v2fly/domain-list-community](https://github.com/v2fly/domain-list-community)
