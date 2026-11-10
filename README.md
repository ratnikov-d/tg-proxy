# tg-proxy

Telegram WEB proxy: `tproxy-web` (telegramdesktop/tproxy-server) + MTProxy backend в Docker.

```
Интернет :443 → Traefik (freedom.lt.ruii.ru) → tproxy-web → telemt:443
```

`tproxy-web` отдаёт сайт-заглушку и WebView-карьер, релеит MTProto-стримы в бэкенд.
FakeTLS/HTTPS снимает `tproxy-web`, поэтому бэкенд работает в **classic**-режиме
(16-байтовый секрет), как официальный MTProxy.

## Состав

| Файл | Назначение |
|---|---|
| `compose.yaml` | стек: `tproxy-web` + `telemt`, сеть `shared-net` |
| `start.sh` | рендер `config.json`/`profiles.json`, socat 8443 → `mtproxy:443` |
| `public/index.html` | сайт-заглушка |
| `Dockerfile` | сборка `tproxy-web` из telegramdesktop/tproxy-server |

## Бэкенд

`ghcr.io/telemt/telemt:3.5.17` (Rust) вместо официального `telegrammessenger/proxy`
(образ 2020 года, 7–8% CPU на 1 vCPU в простое). telemt в classic-режиме даёт
0.5–1% при том же протоколе и том же секрете — клиентские ссылки не меняются.

- у контейнера `telemt` network alias `mtproxy`, потому что `start.sh` жёстко
  ходит в `mtproxy:443`; отдельный контейнер `mtproxy` больше не нужен;
- конфиг бэкенда рендерится самим Compose из `MTP_SECRET` (`configs.content`):
  в git секрета нет, а bind-mount файла ломается при деплое из git на другом
  хосте (`bind source path does not exist`); состояние — tmpfs `/run/telemt`;
- healthcheck использует Control API `127.0.0.1:9091` внутри контейнера;
- TLS/secure режимы выключены: FakeTLS уже делает `tproxy-web`.

## Деплой

Нужен только `.env` рядом с `compose.yaml`:

```
MTP_SECRET=<32 hex>
PUBLIC_HOSTNAME=freedom.example.com
```

```bash
docker compose up -d
```

Клиентская ссылка (не меняется при смене бэкенда, если секрет тот же):

```
https://t.me/webproxy?server=<PUBLIC_HOSTNAME>&secret=<32 hex>
```

## Откат на официальный MTProxy

Вернуть в `compose.yaml` сервис `mtproxy` (`telegrammessenger/proxy:latest`,
`network_mode`/`networks: shared-net`, `SECRET`/`TAG`/`WORKERS`), убрать `telemt`,
затем `docker compose up -d`.
