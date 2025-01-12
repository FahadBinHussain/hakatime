#
# Build the frontend.
#
FROM node:18 as dashboard-builder

WORKDIR /usr/src/app

COPY dashboard ./
# COPY .git      ./

RUN yarn install --network-timeout 1000000000 && \
    yarn run prod

#
# Build the server.
#
FROM alpine:3.17 as server-builder

WORKDIR /build

ENV BOOTSTRAP_HASKELL_NONINTERACTIVE "1"
ENV BOOTSTRAP_HASKELL_GHC_VERSION    "9.0.2"
ENV BOOTSTRAP_HASKELL_CABAL_VERSION  "3.10.1.0"

COPY UNLICENSE      ./
COPY app/           ./app
COPY README.md      ./
COPY hakatime.cabal ./
COPY cabal.project  ./
COPY src/           ./src
COPY sql/           ./sql
COPY test/          ./test
COPY tools/         ./tools

RUN apk add --no-cache curl gcc g++ libc-dev musl-dev binutils-gold make zlib-dev alpine-sdk gmp-dev libffi-dev xz tar perl ncurses-dev postgresql-dev ca-certificates && \
    curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh && \
    source "/root/.ghcup/env" && \
    cabal build exe:hakatime && \
    mkdir -p /app/bin                             && \
    cp /build/dist-newstyle/build/*-linux/ghc-*/hakatime-*/x/hakatime/opt/build/hakatime/hakatime /app/bin/hakatime

RUN apk add upx && upx /app/bin/hakatime

FROM alpine:3.17

COPY --from=dashboard-builder /usr/src/app/dist /app/bin/dashboard
COPY --from=server-builder    /app/bin/hakatime /app/bin/hakatime
COPY docker/init.sql          /app/init.sql
COPY docker/start.sh          /app/start.sh
COPY migrations/              /app/migrations

RUN apk add --no-cache \
        bash \
        libffi-dev \
        gmp-dev \
        zlib-dev \
        postgresql \
        postgresql-dev && \
    # Remove files that we don't' need.
    rm -rf /usr/lib/libicudata.so* \
           /usr/lib/libLLVM* \
           /usr/lib/libclang* \
           /usr/lib/llvm10 \
           /usr/lib/clang \
           /usr/include \
           /usr/bin/c-index-test


ENV HAKA_PORT           8080
ENV HAKA_DASHBOARD_PATH /app/bin/dashboard

CMD ["/app/start.sh"]
