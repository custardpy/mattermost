# syntax=docker/dockerfile:1

FROM mattermost/mattermost-build-server:1.24.13 AS builder

RUN rm /bin/sh && ln -s /bin/bash /bin/sh

RUN mkdir /work
WORKDIR /work

# Clone repository and apply limits modifications
RUN git clone https://github.com/mattermost/mattermost && \
    sed -i 's/200/2000/; s/250/2500/' ./mattermost/server/channels/app/limits.go

ENV NVM_DIR=/root/.nvm
ENV CGO_ENABLED=0

# Install Node.js version and cache webapp dependencies
RUN --mount=type=cache,target=/root/.npm \
    source $NVM_DIR/nvm.sh && \
    cd /work/mattermost/webapp && \
    nvm install && \
    npm ci

# Build server and create amd64 package tarball
# Note: make build compiles both architectures, but we only package amd64
RUN source $NVM_DIR/nvm.sh && \
    cd /work/mattermost/server && \
    CGO_ENABLED=0 make build && \
    CGO_ENABLED=0 make package-linux-amd64

# Output stage - copy tarball to predictable location
FROM scratch AS artifact

COPY --from=builder /work/mattermost/server/dist/mattermost-team-linux-amd64.tar.gz /mattermost.tar.gz
