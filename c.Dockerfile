ARG RUNNER_VERSION=2.323.0

FROM debian:bookworm-slim AS builder

RUN apt-get update -y && apt-get install -y --no-install-recommends ca-certificates \
    build-essential cmake git autoconf libtool pkg-config curl unzip

# Install Abseil
RUN set -ex; \
    cd /tmp && git clone --depth 1 --branch 20250127.1 https://github.com/abseil/abseil-cpp.git; \
    cd abseil-cpp && mkdir build && cd build; \
    cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DABSL_BUILD_TESTING=OFF .. ; \
    make -j$(nproc) && make install; \
    ldconfig

# Build gRPC
RUN set -ex; \
    cd /tmp && git clone --recurse-submodules -b v1.48.0 https://github.com/grpc/grpc; \
    cd grpc && mkdir -p cmake/build && cd cmake/build; \
    cmake -DgRPC_INSTALL=ON \
          -DgRPC_BUILD_TESTS=OFF \
          -DgRPC_ABSL_PROVIDER=package \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX=/usr/local \
          ../.. ; \
    make -j$(nproc) && make install; \
    ldconfig

FROM ghcr.io/webitel/actions-runner-image/base:${RUNNER_VERSION}

ARG POSTGRES_VERSION=15

USER root

COPY --from=builder /usr/local /usr/local

RUN ldconfig

ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"
ENV LD_LIBRARY_PATH="/usr/local/lib"

# Install RabbitMQ team signing key and repository
RUN curl -1sLf "https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA" | gpg --dearmor | tee /usr/share/keyrings/com.rabbitmq.team.gpg > /dev/null \
    && curl -1sLf https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key | gpg --dearmor | tee /usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg > /dev/null \
    && curl -1sLf https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key | gpg --dearmor | tee /usr/share/keyrings/rabbitmq.9F4587F226208342.gpg > /dev/null

# Add RabbitMQ repositories
RUN echo "deb [arch=amd64 signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://ppa1.rabbitmq.com/rabbitmq/rabbitmq-erlang/deb/debian bookworm main" > /etc/apt/sources.list.d/rabbitmq.list \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://ppa2.rabbitmq.com/rabbitmq/rabbitmq-erlang/deb/debian bookworm main" > /etc/apt/sources.list.d/rabbitmq.list \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://ppa1.rabbitmq.com/rabbitmq/rabbitmq-server/deb/debian bookworm main" > /etc/apt/sources.list.d/rabbitmq.list \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://ppa2.rabbitmq.com/rabbitmq/rabbitmq-server/deb/debian bookworm main" > /etc/apt/sources.list.d/rabbitmq.list

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends build-essential cmake libtool autoconf automake pkg-config gnupg dirmngr \
      libssl-dev libre2-dev zlib1g-dev libsystemd-dev libcurl4-openssl-dev librabbitmq-dev \
      libc-ares-dev libz-dev libspeexdsp-dev

RUN --mount=type=secret,id=SIGNALWIRE_TOKEN,env=SIGNALWIRE_TOKEN \
    curl -sSL https://freeswitch.org/fsget | bash -s ${SIGNALWIRE_TOKEN} release \
    && apt install -y --no-install-recommends libfreeswitch-dev \
    && rm -f /etc/apt/auth.conf

RUN rm -rf /var/lib/apt/lists/*

USER runner