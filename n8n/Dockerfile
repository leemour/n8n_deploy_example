FROM n8nio/n8n:latest

USER root

# 1. Restore apk package manager in hardened Alpine image and install dependencies
RUN set -ex && \
    # Download and install apk-tools
    cd /tmp && \
    wget https://dl-cdn.alpinelinux.org/alpine/v3.22/main/x86_64/apk-tools-2.14.9-r3.apk && \
    tar -xzf apk-tools-2.14.9-r3.apk && \
    mv sbin/apk /sbin/ && \
    chmod +x /sbin/apk && \
    rm -rf /tmp/* && \
    # Now install packages
    apk add --no-cache \
    chromium \
    chromium-chromedriver \
    nss \
    freetype \
    freetype-dev \
    harfbuzz \
    ca-certificates \
    ttf-freefont \
    python3 \
    make \
    g++

# 2. Install Community nodes outside the mounted volume so they survive bind mounts
RUN mkdir -p /home/node/custom-nodes && \
    cd /home/node/custom-nodes && \
    npm init -y && \
    npm install --legacy-peer-deps \
    n8n-nodes-evolution-api \
    @mendable/n8n-nodes-firecrawl \
    n8n-nodes-globals \
    n8n-nodes-text-manipulation \
    n8n-nodes-apify \
    n8n-nodes-puppeteer \
    @brave/n8n-nodes-brave-search \
    @elevenlabs/n8n-nodes-elevenlabs \
    n8n-nodes-palatine-speech \
    n8n-nodes-docx-filler \
    @custom-js/n8n-nodes-pdf-toolkit \
    n8n-nodes-serpapi \
    n8n-nodes-scrapingbee \
    n8n-nodes-pdfco \
    @cloudconvert/n8n-nodes-cloudconvert \
    @blotato/n8n-nodes-blotato \
    @tavily/n8n-nodes-tavily && \
    chown -R node:node /home/node/custom-nodes

# 3. Install NPM packages for Code node: task-runner resolves require() from n8n's node_modules
#    (not from task-runner dir). Install in /tmp then copy into n8n/node_modules (see n8n#24191).
RUN mkdir -p /tmp/code-node-deps && \
    cd /tmp/code-node-deps && \
    npm init -y && \
    npm install --no-save \
    papaparse fast-xml-parser turndown sanitize-html \
    jsonwebtoken bcrypt qrcode sharp tiktoken exceljs pdf-lib adm-zip form-data \
    libphonenumber-js && \
    mkdir -p /usr/local/lib/node_modules/n8n/node_modules && \
    cp -r node_modules/* /usr/local/lib/node_modules/n8n/node_modules/ && \
    rm -rf /tmp/code-node-deps

# 4. Set paths for Puppeteer to use the system Chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

# 5. Return permissions to the node user (CRITICAL for stable n8n operation)
USER node
