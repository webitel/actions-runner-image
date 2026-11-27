FROM ghcr.io/actions/actions-runner:2.338.2@sha256:6d0b2d80d80f143f77dcb676e50920100bbb547e39e883454d57f45ab8c31300 AS runner
FROM docker/buildx-bin:0.39.1@sha256:65035f720fc63f266620394a62edcde2318b3611ceb50b77af984578d011a0d6 AS buildx
FROM goreleaser/nfpm:v2.49.0@sha256:9ea46a59c4d055ef7071b22f3520b53e8dad98e18043b2f881b53bd7ffec634e AS nfpm
FROM ghcr.io/google/osv-scanner:v2.7.1@sha256:a70ffffc2bfd33482953e5d6b64c6fcdb30239717a07b0f0d3ab2859ce3e4cde AS osv-scanner

FROM busybox:1.37@sha256:a7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec AS downloads

ADD --checksum=sha256:061642059fa7f2ed9b2f04a327a951cff4249585cf04b2661c2a6539197c9962 \
    https://download.docker.com/linux/static/stable/x86_64/docker-29.10.1.tgz /tmp/docker.tgz
ADD --checksum=sha256:2c3c4526f8a8d517373a2a0daa6122d7887bdc465c54945c6d716db87d9d9b4f \
    https://github.com/actions/runner-container-hooks/releases/download/v0.8.1/actions-runner-hooks-k8s-0.8.1.zip /tmp/hooks.zip

RUN tar -xzf /tmp/docker.tgz -C /tmp \
    && mkdir -p /tmp/k8s \
    && unzip -q /tmp/hooks.zip -d /tmp/k8s

FROM mcr.microsoft.com/dotnet/runtime-deps:8.0-bookworm-slim@sha256:54c5e25d41d6df433e520750bacfa4eed1f664140cd36b37c189dd6c6df33d79

ARG DEB_S3_VERSION=26.1.0

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV RUNNER_MANUALLY_TRAP_SIG=1
ENV ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=1
ENV ImageOS=debian12

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends sudo lsb-release gpg gpg-agent python3 git curl ca-certificates jq unzip zstd file rubygems \
    && mkdir -p -m 755 /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

RUN adduser --disabled-password --gecos "" --uid 1001 runner \
    && groupadd docker --gid 123 \
    && usermod -aG sudo runner \
    && usermod -aG docker runner \
    && printf '%s\n' \
      'Defaults env_keep += "DEBIAN_FRONTEND"' \
      'Defaults !secure_path' \
      '%sudo ALL=(ALL:ALL) NOPASSWD:ALL' > /etc/sudoers.d/runner \
    && chmod 0440 /etc/sudoers.d/runner \
    && visudo -c

RUN gem install deb-s3 -v "${DEB_S3_VERSION}"

WORKDIR /home/runner

COPY --chown=runner:docker --from=runner /home/runner/bin ./bin
COPY --chown=runner:docker --from=runner /home/runner/externals ./externals
COPY --chown=runner:docker --from=runner /home/runner/*.sh /home/runner/*.template ./
COPY --chown=runner:docker --from=downloads /tmp/k8s ./k8s
COPY --from=downloads /tmp/docker/ /usr/bin/
COPY --from=buildx /buildx /usr/local/lib/docker/cli-plugins/docker-buildx
COPY --from=nfpm /usr/bin/nfpm /usr/local/bin/nfpm
COPY --from=osv-scanner /osv-scanner /usr/local/bin/osv-scanner

USER runner
