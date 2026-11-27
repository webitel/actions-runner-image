ARG RUNNER_VERSION=2.338.2

FROM golang:1.26.11-alpine@sha256:ecb67f987aa1a57794c91d19ade7ae0209f2f0f5496aaef9e6ae85ddf92d02ab AS go
FROM golangci/golangci-lint:v2.15.0-alpine@sha256:2ba875b990f1d8501ad4ec19be1ea0701e316ec3a4b764f7b129f62f01318bbf AS golangci

FROM ghcr.io/webitel/actions-runner-image/base:${RUNNER_VERSION}

USER root

COPY --from=go /usr/local/go /usr/local/go
ENV GOPATH=/home/runner/go
ENV GOMODCACHE=$GOPATH/pkg/mod
ENV GOCACHE=/home/runner/.cache/go
ENV PATH=$GOPATH/bin:/usr/local/go/bin:$PATH

COPY --from=golangci /usr/bin/golangci-lint /usr/local/bin/golangci-lint

# C toolchain for cgo: native amd64 plus the arm64 cross toolchain, with the C libraries Go code links against.
# Go enables cgo automatically once gcc is on PATH, so workflows must set CGO_ENABLED explicitly.
RUN dpkg --add-architecture arm64 \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
      gcc libc6-dev pkg-config \
      gcc-aarch64-linux-gnu libc6-dev-arm64-cross \
      libsystemd-dev libsystemd-dev:arm64 \
    && rm -rf /var/lib/apt/lists/*

USER runner