#!/bin/bash

echo "=== Fixing pgAdmin Issues ==="
echo ""

# SSH connection details
SSH_USER="deploy"
SSH_HOST="142.132.239.135"
SSH_PORT="25222"

# Function to run remote commands
run_remote() {
    ssh -p $SSH_PORT $SSH_USER@$SSH_HOST "$1"
}

echo "1. Stopping pgAdmin container..."
run_remote "cd /srv/www/n8n_production/current && docker compose stop pgadmin"

echo ""
echo "2. Fixing pgAdmin permissions..."
# Create the pgadmin_data directory with correct permissions
run_remote "cd /srv/www/n8n_production/current && sudo chown -R 5050:5050 pgadmin_data || true"
run_remote "cd /srv/www/n8n_production/current && sudo chmod 700 pgadmin_data || true"

echo ""
echo "3. Starting pgAdmin container..."
run_remote "cd /srv/www/n8n_production/current && docker compose up -d pgadmin"

echo ""
echo "4. Adding pgAdmin to global Caddy configuration..."
# Create a pgAdmin addon config file
cat > /tmp/pgadmin.conf << 'EOF'
# pgAdmin configuration
pgadmin.openorbit.pro {
    reverse_proxy pgadmin:80
}

pgadmin.staging.openorbit.pro {
    reverse_proxy pgadmin:80
}
EOF

# Copy the addon config to the server
echo "Copying pgAdmin Caddy config to server..."
scp -P $SSH_PORT /tmp/pgadmin.conf $SSH_USER@$SSH_HOST:/tmp/pgadmin.conf
run_remote "sudo mv /tmp/pgadmin.conf /srv/www/proxy/addons/pgadmin.conf"
run_remote "sudo chown deploy:deploy /srv/www/proxy/addons/pgadmin.conf"

echo ""
echo "5. Reloading Caddy configuration..."
run_remote "docker exec global-caddy caddy reload --config /etc/caddy/Caddyfile"

echo ""
echo "6. Checking pgAdmin container status..."
run_remote "docker ps | grep pgadmin"

echo ""
echo "7. Checking pgAdmin logs (last 10 lines)..."
run_remote "cd /srv/www/n8n_production/current && docker compose logs pgadmin --tail=10"

echo ""
echo "=== Fix Complete ==="
echo ""
echo "IMPORTANT: Cloudflare SSL/TLS Settings"
echo "----------------------------------------"
echo "1. Go to Cloudflare Dashboard > Your Domain > SSL/TLS > Overview"
echo "2. Set SSL/TLS encryption mode to 'Full' or 'Full (strict)'"
echo "   (NOT 'Flexible' - this causes Error 525)"
echo ""
echo "Test URLs:"
echo "  Production: https://pgadmin.openorbit.pro"
echo "  Staging: https://pgadmin.staging.openorbit.pro"
echo ""
echo "Default pgAdmin credentials (from .env):"
echo "  Email: admin@openorbit.pro"
echo "  Password: Check PGADMIN_DEFAULT_PASSWORD in your .env file"