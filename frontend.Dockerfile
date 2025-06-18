ARG NODE_VERSION=22.16.0
ARG PNPM_VERSION=10.12.1
ARG YARN_VERSION=4.9.2
ARG RUNNER_VERSION=2.323.0

FROM node:${NODE_VERSION}-alpine AS node
FROM ghcr.io/webitel/actions-runner-image/base:${RUNNER_VERSION}

USER root

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/bin/npm /usr/local/bin/npm
COPY --from=node /usr/local/bin/npx /usr/local/bin/npx
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules

RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

ENV NODE_PATH=/usr/local/lib/node_modules
ENV PATH=/usr/local/bin:$PATH

RUN npm install -g pnpm@${PNPM_VERSION}
RUN npm install -g yarn@${YARN_VERSION}

# Set up cache directories for the runner user
RUN mkdir -p /home/runner/.npm \
             /home/runner/.pnpm-store \
             /home/runner/.yarn \
             /home/runner/.cache && \
    chown -R runner:runner /home/runner/.npm \
                          /home/runner/.pnpm-store \
                          /home/runner/.yarn \
                          /home/runner/.cache

# Configure package manager cache directories
ENV NPM_CONFIG_CACHE=/home/runner/.npm
ENV PNPM_HOME=/home/runner/.local/share/pnpm
ENV PNPM_STORE_PATH=/home/runner/.pnpm-store
ENV YARN_CACHE_FOLDER=/home/runner/.yarn/cache
ENV XDG_CACHE_HOME=/home/runner/.cache

ENV PATH="$PNPM_HOME:$PATH"

RUN mkdir -p $PNPM_HOME && chown -R runner:runner $PNPM_HOME

USER runner

# Initialize pnpm for the runner user
RUN pnpm config set store-dir $PNPM_STORE_PATH
