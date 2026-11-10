FROM golang:1.21-alpine AS builder
WORKDIR /src
RUN apk add --no-cache git
RUN git clone https://github.com/telegramdesktop/tproxy-server.git .
RUN go build -trimpath -o /tproxy-server . || go build -trimpath -o /tproxy-server ./cmd/...

FROM alpine:latest
WORKDIR /app
RUN apk add --no-cache socat
COPY --from=builder /tproxy-server /usr/local/bin/tproxy-server

COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]