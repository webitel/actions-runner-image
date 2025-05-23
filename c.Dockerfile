ARG RUNNER_VERSION=2.323.0

FROM ghcr.io/webitel/actions-runner-image/base:${RUNNER_VERSION}

ARG POSTGRES_VERSION=15
ARG SIGNALWIRE_TOKEN

USER root

RUN apt-get update -y
RUN apt-get install -y --no-install-recommends build-essential cmake libtool autoconf automake pkg-config gnupg dirmngr \
    libssl-dev libpcre3-dev libedit-dev libabsl-dev libsystemd-dev libpq-dev

RUN apt-get install -y --no-install-recommends postgresql-server-dev-${POSTGRES_VERSION}
RUN set -ex; \
    # pub   4096R/ACCC4CF8 2011-10-13 [expires: 2019-07-02]
    #       Key fingerprint = B97B 0AFC AA1A 47F0 44F2  44A0 7FCC 7D46 ACCC 4CF8
    # uid                  PostgreSQL Debian Repository
	key='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8'; \
	export GNUPGHOME="$(mktemp -d)"; \
	mkdir -p /usr/local/share/keyrings/; \
	gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key"; \
	gpg --batch --export --armor "$key" > /usr/local/share/keyrings/postgres.gpg.asc; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" \

RUN echo "deb [ signed-by=/usr/local/share/keyrings/postgres.gpg.asc ] http://apt.postgresql.org/pub/repos/apt/ bookworm-pgdg main ${POSTGRES_VERSION}" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends postgresql-server-dev-${POSTGRES_VERSION}


RUN --mount=type=secret,id=SIGNALWIRE_TOKEN,env=SIGNALWIRE_TOKEN \
    curl -sSL https://freeswitch.org/fsget | bash -s ${SIGNALWIRE_TOKEN} release \
    && apt install -y --no-install-recommends libfreeswitch-dev \
    && rm -f /etc/apt/auth.conf

RUN rm -rf /var/lib/apt/lists/*

# Install latest compatible Abseil to build mod_grpc (gRPC, protobuf dependency).
# LTS releases newer than 20250127.1 needs at least C++17, which has built-in `if constexpr`
# instead of `absl::if_constexpr`, which used in gRPC or Protobuf.
#
# Now we choosed to use Abseil provided from modules itself, so it is no neseccary
# to build it from sources.
#RUN git clone https://github.com/abseil/abseil-cpp.git \
#  && cd abseil-cpp && git checkout 20250127.1 \
#  && mkdir build && cd build \
#  && cmake -DCMAKE_BUILD_TYPE=Release \
#      -DCMAKE_INSTALL_PREFIX=/usr/local \
#      -DABSL_BUILD_TESTING=OFF \
#      -DABSL_ENABLE_INSTALL=ON \
#      -DCMAKE_CXX_STANDARD=17 \
#      -DABSL_PROPAGATE_CXX_STD=ON \
#      .. \
#  && make -j$(nproc) && make install \
#  && ldconfig \
#  && cd ../.. && rm -rf abseil-cpp

USER runner