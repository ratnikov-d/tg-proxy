# tg-proxy

Telegram WEB-прокси в Docker: сайт-заглушка + релей + MTProxy-бэкенд.

```
Клиент → Traefik (443, HTTPS host) → tproxy-web (сайт + релей) → telemt (MTProto, classic)
```

Клиент подключается к домену по HTTPS (`t.me/webproxy`-ссылка), релей снимает
TLS-транспорт и передаёт MTProto-потоки в бэкенд. Бэкенд работает в classic-режиме
(16-байтовый секрет), поэтому ссылки совместимы с обычным MTProxy-секретом.

## Состав

| Файл | Что |
|---|---|
| `compose.yaml` | стек: `tproxy-web` + `telemt`, внешняя сеть `shared-net` |
| `start.sh` | рендер `config.json`/`profiles.json`, socat `127.0.0.1:8443 → mtproxy:443` |
| `Dockerfile` | образ `tproxy-web` (Go-релей + socat) |
| `config.template.json`, `profiles.template.json` | шаблоны конфигов релея |
| `public/index.html` | сайт-заглушка на домене, заголовок — плейсхолдер `__SITE_TITLE__` |
| `.env.example` | шаблон `.env` |

## Секреты и настройки

Всё, что нужно хосту, — `.env` рядом с `compose.yaml`:

```
MTP_SECRET=<32 hex>
PUBLIC_HOSTNAME=<домен>
SITE_TITLE=Freedom
```

`SITE_TITLE` — заголовок сайта (`<title>` и `<h1>`), по умолчанию `Freedom`.
`start.sh` копирует `public` в `/run/tproxy/public` и подставляет туда название:
исходник смонтирован read-only, поэтому правка идёт в копию.

Секрет нигде в git не хранится: конфиг telemt рендерится Compose из `MTP_SECRET`
(`configs.content`), а tproxy-web получает его как переменную окружения.

## Бэкенд

`ghcr.io/telemt/telemt:3.5.17` (Rust), режим `classic`, TLS/secure выключены —
TLS-транспорт делает релей.

- у контейнера alias `mtproxy` в сети `shared-net`: `start.sh` релея ходит в
  `mtproxy:443`, поэтому отдельный контейнер `mtproxy` не нужен;
- конфиг — `configs.content`, состояние — tmpfs `/run/telemt`, томов нет;
- healthcheck — `telemt healthcheck ... --mode liveness`, использует Control API
  на `127.0.0.1:9091` внутри контейнера;
- `read_only` выключен: Compose не умеет `content`-configs в read-only контейнере.

## Деплой

```bash
cp .env.example .env    # вписать MTP_SECRET и PUBLIC_HOSTNAME
docker compose up -d
```

Требования хоста: Docker + Compose, внешняя сеть `shared-net`, Traefik с
`certresolver=letsencrypt` и метками `traefik.http.routers.*` (см. `compose.yaml`).

Клиентская ссылка (не меняется при смене бэкенда, если секрет тот же):

```
https://t.me/webproxy?server=<PUBLIC_HOSTNAME>&secret=<MTP_SECRET>
```

## Проверка после деплоя

```bash
docker compose ps                     # tproxy-web и telemt — healthy
curl -fsS -o /dev/null -w '%{http_code}\n' https://$PUBLIC_HOSTNAME/
docker logs telemt --tail 20          # «RPC handshake OK» = бэкенд видит DC Telegram
docker exec tproxy-web sh -c 'socat -u /dev/null TCP:mtproxy:443 && echo port_open'
```

## Обновление

```bash
git pull
docker compose up -d
```

## Если что-то не завелось

| Симптом | Причина |
|---|---|
| `bind source path does not exist: .../telemt.toml` | конфиг был bind-mount'ом; здесь он рендерится из `.env` |
| `cannot create config ... file is the sole supported option` | у сервиса стоит `read_only: true` — с `configs.content` нельзя |
| `MTP_SECRET must be set in .env` | нет `.env` или в нём нет переменной |
| клиент «Подключение…» и тишина | бэкенд не достучался до DC: смотреть `docker logs telemt`, нужен внешний IPv4 без NAT-сюрпризов |
