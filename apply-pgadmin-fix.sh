#!/bin/bash

echo "=== Applying pgAdmin CSRF Fix ==="
echo ""

# SSH connection details
SSH_USER="deploy"
SSH_HOST="142.132.239.135"
SSH_PORT="25222"

# Function to run remote commands
run_remote() {
    ssh -p $SSH_PORT $SSH_USER@$SSH_HOST "$1"
}

echo "1. Updating Caddy configuration with proper headers..."
cat > /tmp/pgadmin-caddy.conf << 'EOF'
# pgAdmin configuration with proper proxy headers
pgadmin.openorbit.pro {
    reverse_proxy pgadmin:80 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
        header_up X-Forwarded-Host {host}
        header_up X-Script-Name ""
    }
}

pgadmin.staging.openorbit.pro {
    reverse_proxy pgadmin:80 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
        header_up X-Forwarded-Host {host}
        header_up X-Script-Name ""
    }
}
EOF

# Copy the new Caddy config
scp -P $SSH_PORT /tmp/pgadmin-caddy.conf $SSH_USER@$SSH_HOST:/tmp/pgadmin-caddy.conf
run_remote "mv /tmp/pgadmin-caddy.conf /srv/www/proxy/addons/pgadmin.conf"

echo ""
echo "2. Updating pgAdmin environment variables in docker-compose..."
# Update the docker-compose.yaml on the server
run_remote "cd /srv/www/n8n_production/current && \
cat > /tmp/pgadmin-env-patch.txt << 'EOF'
      PGADMIN_CONFIG_PROXY_X_FOR_COUNT: '1'
      PGADMIN_CONFIG_PROXY_X_PROTO_COUNT: '1'
      PGADMIN_CONFIG_PROXY_X_HOST_COUNT: '1'
      PGADMIN_CONFIG_PROXY_X_PORT_COUNT: '1'
      PGADMIN_CONFIG_PROXY_X_PREFIX_COUNT: '1'
      PGADMIN_CONFIG_ENHANCED_COOKIE_PROTECTION: 'False'
EOF"

# Apply the environment variables
run_remote "cd /srv/www/n8n_production/current && \
if ! grep -q 'PGADMIN_CONFIG_PROXY_X_FOR_COUNT' docker-compose.yaml; then \
  sed -i '/PGADMIN_DISABLE_POSTFIX/a\\      PGADMIN_CONFIG_PROXY_X_FOR_COUNT: '\''1'\''\\n      PGADMIN_CONFIG_PROXY_X_PROTO_COUNT: '\''1'\''\\n      PGADMIN_CONFIG_PROXY_X_HOST_COUNT: '\''1'\''\\n      PGADMIN_CONFIG_PROXY_X_PORT_COUNT: '\''1'\''\\n      PGADMIN_CONFIG_PROXY_X_PREFIX_COUNT: '\''1'\''\\n      PGADMIN_CONFIG_ENHANCED_COOKIE_PROTECTION: '\''False'\''' docker-compose.yaml; \
fi"

echo ""
echo "3. Restarting pgAdmin with new configuration..."
run_remote "cd /srv/www/n8n_production/current && docker compose stop pgadmin && docker compose up -d pgadmin"

echo ""
echo "4. Reloading Caddy configuration..."
run_remote "docker exec global-caddy caddy reload --config /etc/caddy/Caddyfile"

echo ""
echo "5. Waiting for services to stabilize..."
sleep 5

echo ""
echo "6. Checking pgAdmin status..."
run_remote "docker ps | grep pgadmin"

echo ""
echo "7. Testing pgAdmin response..."
curl -s -I https://pgadmin.openorbit.pro 2>&1 | head -10

echo ""
echo "=== Fix Applied ==="
echo ""
echo "The CSRF token issue should now be resolved."
echo "Try logging in again at: https://pgadmin.openorbit.pro"
echo ""
echo "If you still have issues:"
echo "1. Clear your browser cookies for pgadmin.openorbit.pro"
echo "2. Use an incognito/private browser window"
echo "3. Ensure Cloudflare SSL mode is set to 'Full' or 'Full (strict)'"