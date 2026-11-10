#!/bin/sh
set -eu

: "${MTP_SECRET:?MTP_SECRET is required}"
: "${PUBLIC_HOSTNAME:?PUBLIC_HOSTNAME is required}"

STATE_DIR=/etc/tproxy-server
TOKEN_KEY=${STATE_DIR}/token.key
MTPROXY_PORT=443

mkdir -p "$STATE_DIR"
umask 077

# tproxy-server has no env support: render both config files from the templates.
sed "s|__PUBLIC_HOSTNAME__|${PUBLIC_HOSTNAME}|g" \
    /tmp/tproxy/config.template.json > "$STATE_DIR/config.json"

sed "s|__MTP_SECRET__|${MTP_SECRET}|g" \
    /tmp/tproxy/profiles.template.json > "$STATE_DIR/profiles.json"

# The signing key must survive restarts: generate it once, never replace it.
if [ -f "$TOKEN_KEY" ] && [ "$(wc -c < "$TOKEN_KEY" | tr -d ' ')" = "32" ]; then
    echo "event=token_key_kept path=$TOKEN_KEY"
else
    head -c 32 /dev/urandom > "$TOKEN_KEY"
    echo "event=token_key_generated path=$TOKEN_KEY"
fi

chmod 600 "$STATE_DIR/config.json" "$STATE_DIR/profiles.json" "$TOKEN_KEY"

echo "event=connect_link url=https://t.me/webproxy?server=${PUBLIC_HOSTNAME}&secret=${MTP_SECRET}"

socat TCP-LISTEN:8082,fork,bind=0.0.0.0 TCP:127.0.0.1:8080 &
socat TCP-LISTEN:8443,fork,bind=127.0.0.1 "TCP:mtproxy:${MTPROXY_PORT}" &

exec tproxy-server -config "$STATE_DIR/config.json"
