FROM n8nio/n8n:latest

USER root

# 1. Обновляем систему и ставим зависимости для Puppeteer и Sharp
RUN apt-get update && \
    apt-get install -y \
    chromium \
    chromium-driver \
    fonts-liberation \
    libappindicator3-1 \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    xdg-utils \
    python3 \
    make \
    g++ \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 2. Install Community nodes
RUN cd /usr/local/lib/node_modules/n8n && \
    npm install --save \
    n8n-nodes-evolution-api \
    n8n-nodes-evolution-whatsapp-api \
    @mendable/n8n-nodes-firecrawl \
    n8n-nodes-globals \
    n8n-nodes-text-manipulation \
    n8n-nodes-opensearch \
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
    @blotato/n8n-nodes-blotato

# 3. Install NPM packages for use inside Code node
RUN npm install -g \
    zod pino lodash papaparse fast-xml-parser turndown cheerio sanitize-html \
    jsonwebtoken bcrypt qrcode sharp tiktoken exceljs pdf-lib adm-zip form-data \
    uuid libphonenumber-js handlebars

# 4. Set paths for Puppeteer to use the system Chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

# 5. Return permissions to the node user (CRITICAL for stable n8n operation)
USER node
