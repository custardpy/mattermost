# syntax=docker/dockerfile:1

FROM mattermost/mattermost-build-server:1.24.13 AS builder

RUN mkdir /work
WORKDIR /work

# Clone repository and apply limits modifications
RUN git clone https://github.com/mattermost/mattermost && \
    find ./mattermost -name "limits.go" -path "*/app/*" -exec sed -i 's/200/2000/; s/250/2500/' {} \;

ENV NVM_DIR=/root/.nvm
ENV CGO_ENABLED=0

# Install Node.js version and cache webapp dependencies
RUN --mount=type=cache,target=/root/.npm,id=npm-cache \
    . "$NVM_DIR/nvm.sh" && \
    cd /work/mattermost/webapp && \
    nvm install && \
    npm ci

# Build server and create amd64 package tarball
# Note: make build compiles both architectures, but we only package amd64
RUN . "$NVM_DIR/nvm.sh" && \
    cd /work/mattermost/server && \
    make build && \
    make package-linux-amd64
