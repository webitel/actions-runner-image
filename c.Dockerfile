ARG RUNNER_VERSION=2.338.2

FROM debian:bookworm-slim@sha256:e67eeead736ff7bbe258ef088bff683635c561b1fcfefad0806c1df4ab49ce0e AS builder

RUN apt-get update -y && apt-get install -y --no-install-recommends ca-certificates \
    build-essential cmake git autoconf libtool pkg-config curl unzip

# Install Abseil
RUN set -ex; \
    cd /tmp && git clone --depth 1 --branch 20250127.1 https://github.com/abseil/abseil-cpp.git; \
    cd abseil-cpp && mkdir build && cd build; \
    cmake -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DABSL_BUILD_TESTING=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DABSL_PROPAGATE_CXX_STD=ON .. ; \
    make -j$(nproc) && make install; \
    ldconfig

# Build gRPC
RUN set -ex; \
    cd /tmp && git clone --recurse-submodules --shallow-submodules --depth 1 -b v1.69.0 https://github.com/grpc/grpc; \
    cd grpc && mkdir -p cmake/build && cd cmake/build; \
    cmake -DgRPC_INSTALL=ON \
          -DgRPC_BUILD_TESTS=OFF \
          -DgRPC_ABSL_PROVIDER=package \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX=/usr/local \
          ../.. ; \
    make -j$(nproc) && make install; \
    ldconfig

# Build google-cloud-cpp (speech component only) on top of pre-installed
# gRPC/Protobuf/Abseil. Used by freeswitch-mod-google-transcribe.
RUN set -ex; \
    apt-get update -y && apt-get install -y --no-install-recommends libssl-dev libcurl4-openssl-dev nlohmann-json3-dev; \
    cd /tmp && git clone --depth 1 -b v2.38.0 https://github.com/googleapis/google-cloud-cpp.git; \
    cd google-cloud-cpp && mkdir -p build && cd build; \
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX=/usr/local \
          -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
          -DBUILD_TESTING=OFF \
          -DGOOGLE_CLOUD_CPP_WITH_MOCKS=OFF \
          -DGOOGLE_CLOUD_CPP_ENABLE_EXAMPLES=OFF \
          -DGOOGLE_CLOUD_CPP_ENABLE=speech \
          .. ; \
    make -j$(nproc) && make install; \
    ldconfig

FROM ghcr.io/webitel/actions-runner-image/base:${RUNNER_VERSION}

ARG POSTGRES_VERSION=15

USER root

COPY --from=builder /usr/local /usr/local

RUN ldconfig

ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"
ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV PATH="/usr/lib/postgresql/${POSTGRES_VERSION}/bin:${PATH}"

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends build-essential cmake libtool autoconf automake pkg-config gnupg dirmngr \
      libssl-dev libre2-dev zlib1g-dev libsystemd-dev libcurl4-openssl-dev librabbitmq-dev \
      libc-ares-dev libz-dev libspeexdsp-dev \
      postgresql-server-dev-${POSTGRES_VERSION} \
    && rm -rf /var/lib/apt/lists/*

RUN --mount=type=secret,id=SIGNALWIRE_TOKEN,env=SIGNALWIRE_TOKEN \
    curl -sSL https://freeswitch.org/fsget | bash -s ${SIGNALWIRE_TOKEN} release \
    && apt-get install -y --no-install-recommends libfreeswitch-dev \
    && rm -f /etc/apt/auth.conf /etc/apt/sources.list.d/freeswitch.sources /etc/apt/sources.list.d/freeswitch.list \
    && rm -rf /var/lib/apt/lists/*

USER runner
