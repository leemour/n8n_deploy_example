#!/bin/bash

# Simple deployment script for updates
# Use this for quick deployments after initial setup

set -e

SERVER="deploy@142.132.239.135"
APP_DIR="/srv/www/n8n"
SSH_PORT="25222"

echo "🚀 Deploying N8N to production server..."

# Copy files to server
echo "📁 Copying files..."
rsync -avz --delete \
    --exclude='.git' \
    --exclude='ansible' \
    --exclude='n8n_storage' \
    --exclude='.env' \
    -e "ssh -p $SSH_PORT" \
    ./ $SERVER:$APP_DIR/

# Deploy on server
echo "🐳 Deploying containers..."
ssh -p $SSH_PORT $SERVER << 'EOF'
    cd /srv/www/n8n

    # Pull latest images
    docker-compose pull

    # Deploy with zero downtime
    docker-compose up -d --remove-orphans

    # Show status
    echo "✅ Deployment complete!"
    docker-compose ps
EOF

echo "🎉 Deployment finished!"
echo "Check status: ssh -p $SSH_PORT $SERVER 'cd $APP_DIR && docker-compose ps'"
