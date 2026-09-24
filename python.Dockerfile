ARG UV_VERSION=0.12.18
ARG RUNNER_VERSION=2.334.0

FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv
FROM ghcr.io/webitel/actions-runner-image/base:${RUNNER_VERSION}

ARG PYTHON_VERSIONS="3.11 3.12 3.13 3.14"

USER root

COPY --from=uv /uv /uvx /usr/local/bin/

ENV UV_PYTHON_INSTALL_DIR=/opt/uv/python
ENV UV_CACHE_DIR=/home/runner/.cache/uv
ENV UV_LINK_MODE=copy
ENV UV_PYTHON_PREFERENCE=only-managed

# Pre-installed interpreters are only a cache: uv downloads any other version a
# repository pins in .python-version (the analogue of GOTOOLCHAIN=auto), so the
# install dir must stay writable by the runner user.
RUN uv python install --no-bin ${PYTHON_VERSIONS} \
    && mkdir -p /home/runner/.cache/uv \
    && chown -R runner:runner /opt/uv /home/runner/.cache

USER runner
