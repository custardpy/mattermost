# syntax=docker/dockerfile:1

# The workflow reads MATTERMOST_VERSION from this file to name the release, so
# keep the format `ARG MATTERMOST_VERSION=<tag>` and update it together with
# BUILD_SERVER_VERSION when upgrading.
ARG BUILD_SERVER_VERSION=1.26.10
ARG MATTERMOST_VERSION=v12.0.1

FROM mattermost/mattermost-build-server:${BUILD_SERVER_VERSION} AS builder

ARG MATTERMOST_VERSION

ENV NVM_DIR=/root/.nvm
ENV CGO_ENABLED=0

WORKDIR /work

# Clone the pinned upstream tag. This layer is only rebuilt when the version changes.
RUN git clone --depth 1 --branch "${MATTERMOST_VERSION}" https://github.com/mattermost/mattermost \
    && git -C mattermost rev-parse HEAD > mattermost-commit.txt

# Webapp dependencies. Ordered before the source patch on purpose: tweaking the
# patch or the build flags below then keeps this expensive layer cached.
# Note: cache mounts are local to the builder and are not exported to the GHA
# cache, so in CI this only helps within a single build.
RUN --mount=type=cache,target=/root/.npm,id=npm-cache \
    bash -c '. "$NVM_DIR/nvm.sh" \
        && cd /work/mattermost \
        && nvm install \
        && cd webapp \
        && npm ci'

# Raise the free-tier seat limits. Anchored to the exact constants and verified
# afterwards, so an upstream rename fails the build instead of silently shipping
# stock limits.
RUN set -eu; \
    limits=/work/mattermost/server/channels/app/limits.go; \
    sed -i -E \
        -e 's/^([[:space:]]*maxUsersLimit[[:space:]]+)=[[:space:]]*200$/\1= 2000/' \
        -e 's/^([[:space:]]*maxUsersHardLimit[[:space:]]+)=[[:space:]]*250$/\1= 2500/' \
        "$limits"; \
    grep -qE '^[[:space:]]*maxUsersLimit[[:space:]]+=[[:space:]]*2000$' "$limits"; \
    grep -qE '^[[:space:]]*maxUsersHardLimit[[:space:]]+=[[:space:]]*2500$' "$limits"

# Build server and client, then create the amd64 package tarball.
WORKDIR /work/mattermost/server
RUN --mount=type=cache,target=/go/pkg/mod,id=go-mod \
    --mount=type=cache,target=/root/.cache/go-build,id=go-build \
    bash -c '. "$NVM_DIR/nvm.sh" \
        && cd /work/mattermost \
        && nvm use \
        && cd server \
        && make setup-go-work build-client \
        && GOOS=linux GOARCH=amd64 make build-linux-amd64 \
        && make package-linux-amd64'
