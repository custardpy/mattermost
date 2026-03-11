# Mattermost Build Containerfile
# Supports any version: v11.4.2, v11.5.0, v12.0.0, etc.
# Usage: podman build --build-arg MATTERMOST_VERSION=v11.4.2 -t mattermost .

# Global build argument - available to all stages including FROM lines
ARG MATTERMOST_VERSION=v11.4.2

# Stage 1: Build both server and webapp
FROM mattermost/mattermost-build-server:1.24.13 AS builder

# Re-declare for use within this stage
ARG MATTERMOST_VERSION=v11.4.2

# Build optimization: use all CPU cores, disable CGO for static build
ENV GOMAXPROCS=8
ENV CGO_ENABLED=0
ENV GOARCH=amd64
ENV GOOS=linux
ENV NVM_DIR=/root/.nvm

# Extract version number from tag (e.g., v11.4.2 -> 11.4.2)
RUN echo "${MATTERMOST_VERSION#v}" > /tmp/version.txt

WORKDIR /work

# Shallow clone for faster download
RUN git clone --depth 1 -b ${MATTERMOST_VERSION} https://github.com/mattermost/mattermost

WORKDIR /work/mattermost

# Patch limits (server-side only, safe across versions)
RUN sed -i 's/200/2000/' ./server/channels/app/limits.go && \
    sed -i 's/250/2500/' ./server/channels/app/limits.go

# Install Node.js dependencies (version from .nvmrc)
RUN . $NVM_DIR/nvm.sh && \
    cd webapp && \
    nvm install && \
    npm ci --prefer-offline --no-audit --progress=false

# Build webapp first (required by server build)
RUN . $NVM_DIR/nvm.sh && \
    cd webapp && \
    npm run build

# Build server with patched limits
WORKDIR /work/mattermost/server
RUN make build-linux-amd64 GOOS=linux GOARCH=amd64 CGO_ENABLED=0 BUILD_NUMBER="${MATTERMOST_VERSION#v} (dev)"

# Create distribution package (server + webapp)
WORKDIR /work/mattermost
RUN mkdir -p dist/mattermost && \
    cp -r server/bin/mattermost dist/mattermost/ && \
    cp -r server/config dist/mattermost/ && \
    cp -r server/i18n dist/mattermost/ && \
    cp -r server/templates dist/mattermost/ && \
    cp -r server/plugins dist/mattermost/ && \
    cp -r webapp/dist dist/mattermost/client/ && \
    tar -czf mattermost-${MATTERMOST_VERSION}-linux-amd64.tar.gz -C dist mattermost

# Copy tarball to final stage for CI/CD artifact extraction
FROM alpine:3.19 AS artifacts

# Re-declare ARG for use in this stage
ARG MATTERMOST_VERSION=v11.4.2

WORKDIR /artifacts

COPY --from=builder /work/mattermost/mattermost-${MATTERMOST_VERSION}-linux-amd64.tar.gz .
