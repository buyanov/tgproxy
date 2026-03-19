FROM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    make \
    gcc \
    libc6-dev \
    zlib1g-dev \
    libssl-dev \
    ca-certificates \
    curl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src

RUN git clone https://github.com/TelegramMessenger/MTProxy.git . \
    && make

FROM debian:bookworm-slim

ARG DEBUG=false

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    openssl \
    zlib1g \
    bash \
 && if [ "$DEBUG" = "true" ]; then \
      apt-get install -y --no-install-recommends \
        iproute2 \
        iputils-ping \
        netcat-openbsd \
        procps \
        telnet \
        dnsutils; \
    fi \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /src/objs/bin/mtproto-proxy /usr/local/bin/mtproto-proxy
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENV PORT=443
ENV WORKERS=1
ENV MT_DATA_DIR=/data
ENV RANDOM_PADDING=true

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
