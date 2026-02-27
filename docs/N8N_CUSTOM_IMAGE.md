# N8N Custom Docker Image

This document explains how we build a custom n8n Docker image with community nodes and additional packages.

## Base Image Considerations

### Docker Hub vs n8n Registry

There are two n8n base images available:

1. **`n8nio/n8n:latest`** (Docker Hub)
   - Hardened production image
   - `apk` package manager is removed for security
   - Recommended for production use without modifications

2. **`docker.n8n.io/n8nio/n8n:latest`** (n8n Registry)
   - Development/community image
   - `apk` package manager is available
   - Better for custom builds with additional packages

### Current Approach

We currently use `n8nio/n8n:latest` from Docker Hub and restore `apk` manually:

```dockerfile
FROM n8nio/n8n:latest

USER root

# Restore apk package manager in hardened Alpine image
RUN set -ex && \
    cd /tmp && \
    wget https://dl-cdn.alpinelinux.org/alpine/v3.22/main/x86_64/apk-tools-2.14.9-r3.apk && \
    tar -xzf apk-tools-2.14.9-r3.apk && \
    mv sbin/apk /sbin/ && \
    chmod +x /sbin/apk && \
    rm -rf /tmp/*
```

### Future Improvement Options

1. **Switch to `docker.n8n.io/n8nio/n8n`** base image
   - Pros: No need to restore `apk`, simpler Dockerfile
   - Cons: Less hardened, may have different update schedule

2. **Create minimal custom image**
   - Only install what's absolutely necessary
   - Use multi-stage build to minimize final image size

## Community Nodes Installation

Community nodes should be installed in `/home/node/.n8n/nodes` directory:

```dockerfile
# Install Community nodes in the correct location
RUN mkdir -p /home/node/.n8n/nodes && \
    cd /home/node/.n8n/nodes && \
    npm init -y && \
    npm install --legacy-peer-deps \
    n8n-nodes-evolution-api \
    n8n-nodes-puppeteer \
    # ... other nodes
```

## Required Dependencies

### For Puppeteer Support
- chromium
- chromium-chromedriver
- nss, freetype, harfbuzz
- Various font packages

### For Building Native Modules
- python3
- make
- g++

## Building and Updating

### Pull Latest Base Image

The Docker cache can cause old versions to be used. Always pull the latest:

```bash
# Pull latest base image
docker pull n8nio/n8n:latest

# Rebuild custom image with no cache
docker compose build --no-cache n8n

# Or force rebuild everything
docker compose down
docker compose build --pull --no-cache
docker compose up -d
```

### Check Current Version

```bash
# Check running version
docker exec n8n n8n --version

# Check image metadata
docker inspect n8n --format '{{index .Config.Labels "org.opencontainers.image.version"}}'
```

## Known Issues

1. **Old Version Cached**: Docker may use cached base image. Use `--pull` and `--no-cache` when building.

2. **Community Nodes Location**: Some nodes may not load if installed in wrong directory. Always use `/home/node/.n8n/nodes`.

3. **Permission Issues**: Remember to restore ownership to node user after installing as root:
   ```dockerfile
   chown -R node:node /home/node/.n8n
   ```

4. **Puppeteer Chrome Path**: Set environment variables for system Chromium:
   ```dockerfile
   ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
       PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
   ```

## Version History

- **1.107.4** - Old version that may be cached
- **2.9.2** - Latest stable version as of February 2025

## References

- [n8n Docker Documentation](https://docs.n8n.io/hosting/installation/docker/)
- [Community Nodes Documentation](https://docs.n8n.io/integrations/community-nodes/)
- [Example Dockerfile with Puppeteer](https://github.com/drudge/n8n-nodes-puppeteer/blob/main/docker/Dockerfile)