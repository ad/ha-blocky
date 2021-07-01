# build stage
FROM golang:1.16-alpine AS build-env
RUN apk add --no-cache \
    git \
    make \
    gcc \
    libc-dev \
    tzdata \
    zip \
    ca-certificates

ENV GO111MODULE=on \
    CGO_ENABLED=0

WORKDIR /src

RUN git clone https://github.com/0xERR0R/blocky .

RUN go mod download

ARG opts
RUN env ${opts} make build
COPY config.yml config.yml

# final stage
FROM alpine:3.12

LABEL org.opencontainers.image.source="https://github.com/0xERR0R/blocky" \
      org.opencontainers.image.url="https://github.com/0xERR0R/blocky" \
      org.opencontainers.image.title="DNS proxy as ad-blocker for local network"

RUN apk add --no-cache bind-tools tini
COPY --from=build-env /src/bin/blocky /app/blocky

# the timezone data:
COPY --from=build-env /usr/share/zoneinfo /usr/share/zoneinfo
# the tls certificates:
COPY --from=build-env /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

COPY --from=build-env /src/config.yml /app/config.yml

HEALTHCHECK --interval=1m --timeout=3s CMD dig @127.0.0.1 -p 53 healthcheck.blocky +tcp || exit 1

WORKDIR /app

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/app/blocky","--config","/app/config.yml"]

# Labels
LABEL \
    io.hass.name="Domofon addon" \
    io.hass.description="Domofon addon" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    maintainer="ad <github@apatin.ru>" \
    org.label-schema.description="Domofon addon" \
    org.label-schema.build-date=${BUILD_DATE} \
    org.label-schema.name="Domofon addon" \
    org.label-schema.schema-version="1.0" \
    org.label-schema.usage="https://gitlab.com/ad/domru/-/blob/master/README.md" \
    org.label-schema.vcs-ref=${BUILD_REF} \
    org.label-schema.vcs-url="https://github.com/ad/domru/" \
    org.label-schema.vendor="HomeAssistant add-ons by ad"