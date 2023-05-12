# build stage
FROM golang:1.18-alpine AS build-env
RUN apk add --no-cache \
    git \
    make \
    gcc \
    libc-dev \
    zip \
    ca-certificates

ENV GO111MODULE=on \
    CGO_ENABLED=0

WORKDIR /src
COPY appconfig.yml config.yml

RUN git clone https://github.com/0xERR0R/blocky

WORKDIR /src/blocky

RUN go mod download
RUN go install github.com/abice/go-enum@v0.3.8
RUN go generate ./...

RUN go build -v -ldflags="-w -s -X github.com/0xERR0R/blocky/util.Version=${BUILD_REF} -X github.com/0xERR0R/blocky/util.BuildTime=${BUILD_DATE}" -o /src/bin/blocky


# final stage
FROM alpine:3

LABEL org.opencontainers.image.source="https://github.com/0xERR0R/blocky" \
      org.opencontainers.image.url="https://github.com/0xERR0R/blocky" \
      org.opencontainers.image.title="DNS proxy as ad-blocker for local network"

COPY --from=build-env /src/bin/blocky /app/blocky

RUN apk add --no-cache ca-certificates bind-tools tini tzdata libcap && \
    adduser -S -D -H -h /app -s /sbin/nologin blocky && \
    setcap 'cap_net_bind_service=+ep' /app/blocky

COPY --from=build-env /src/config.yml /app/config.yml

HEALTHCHECK --interval=1m --timeout=3s CMD dig @127.0.0.1 -p 53 healthcheck.blocky +tcp +short || exit 1

USER blocky
WORKDIR /app

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/app/blocky","--config","/app/config.yml"]

# Labels
LABEL \
    io.hass.name="0xERR0R/blocky" \
    io.hass.description="Fast and lightweight DNS proxy as ad-blocker for local network with many features" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    maintainer="ad <github@apatin.ru>" \
    org.label-schema.description="Fast and lightweight DNS proxy as ad-blocker for local network with many features" \
    org.label-schema.build-date=${BUILD_DATE} \
    org.label-schema.name="0xERR0R/blocky" \
    org.label-schema.schema-version="1.0" \
    org.label-schema.usage="https://gitlab.com/ad/ha-blocky/-/blob/master/README.md" \
    org.label-schema.vcs-ref=${BUILD_REF} \
    org.label-schema.vcs-url="https://github.com/ad/ha-blocky/" \
    org.label-schema.vendor="HomeAssistant add-ons by ad"
