ARG GO_VERSION=1.24.2
ARG GORELEASER_VERSION=v2.8.2
ARG GOLANGCI_LINT_VERSION=v2.2.2
ARG RUNNER_VERSION=2.323.0

FROM golang:${GO_VERSION}-alpine AS go
FROM goreleaser/goreleaser:${GORELEASER_VERSION} AS goreleaser
FROM golangci/golangci-lint:${GOLANGCI_LINT_VERSION}-alpine AS golangci

FROM ghcr.io/webitel/actions-runner-image/base:${RUNNER_VERSION}

USER root

COPY --from=go /usr/local/go /usr/local/go
ENV GOPATH=/home/runner/go
ENV GOMODCACHE=$GOPATH/pkg/mod
ENV GOCACHE=/home/runner/.cache/go
ENV PATH=$GOPATH/bin:/usr/local/go/bin:$PATH

COPY --from=goreleaser /usr/bin/goreleaser /usr/local/bin/goreleaser
COPY --from=golangci /usr/bin/golangci-lint /usr/local/bin/golangci-lint

USER runner