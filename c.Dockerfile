ARG RUNNER_VERSION=2.323.0

FROM debian:bookworm-slim AS builder

RUN apt-get update -y && apt-get install -y --no-install-recommends ca-certificates \
    build-essential cmake git autoconf libtool pkg-config curl unzip

# Install Abseil
RUN set -ex; \
    cd /tmp && git clone --depth 1 --branch 20250127.1 https://github.com/abseil/abseil-cpp.git; \
    cd abseil-cpp && mkdir build && cd build; \
    cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DABSL_BUILD_TESTING=OFF .. ; \
    make -j$(nproc) && make install

RUN ldconfig

FROM ghcr.io/webitel/actions-runner-image/base:${RUNNER_VERSION}

ARG POSTGRES_VERSION=15

USER root

COPY --from=builder /usr/local /usr/local

RUN ldconfig

ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"
ENV LD_LIBRARY_PATH="/usr/local/lib"

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends build-essential cmake libtool autoconf automake pkg-config gnupg dirmngr \
      libssl-dev libre2-dev zlib1g-dev libsystemd-dev libcurl4-openssl-dev

RUN --mount=type=secret,id=SIGNALWIRE_TOKEN,env=SIGNALWIRE_TOKEN \
    curl -sSL https://freeswitch.org/fsget | bash -s ${SIGNALWIRE_TOKEN} release \
    && apt install -y --no-install-recommends libfreeswitch-dev \
    && rm -f /etc/apt/auth.conf

RUN rm -rf /var/lib/apt/lists/*

USER runner