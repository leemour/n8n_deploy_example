#!/bin/bash

echo "=== pgAdmin SSL Troubleshooting ==="
echo ""

# SSH connection details
SSH_USER="deploy"
SSH_HOST="142.132.239.135"
SSH_PORT="25222"

# Function to run remote commands
run_remote() {
    ssh -p $SSH_PORT $SSH_USER@$SSH_HOST "$1"
}

echo "1. Checking pgAdmin container status..."
run_remote "docker ps -a | grep pgadmin || echo 'No pgAdmin container found'"
echo ""

echo "2. Checking pgAdmin container logs (last 20 lines)..."
run_remote "cd /srv/www/n8n_production/current && docker compose logs pgadmin --tail=20 2>&1 || echo 'Could not get pgAdmin logs'"
echo ""

echo "3. Checking global Caddy status..."
run_remote "docker ps | grep caddy"
echo ""

echo "4. Checking Caddy configuration for pgAdmin..."
run_remote "docker exec global-caddy cat /etc/caddy/Caddyfile | grep -A 10 -B 2 'pgadmin' || echo 'No pgAdmin config found in Caddy'"
echo ""

echo "5. Testing Caddy's ability to reach pgAdmin..."
run_remote "docker exec global-caddy wget -O- http://pgadmin:80 --timeout=5 2>&1 | head -20 || echo 'Cannot reach pgAdmin from Caddy'"
echo ""

echo "6. Checking network connectivity between containers..."
run_remote "docker network ls"
echo ""
run_remote "docker inspect global-caddy | grep -A 20 'Networks' | head -25"
echo ""

echo "7. Checking if pgAdmin is in the same network as Caddy..."
run_remote "docker inspect n8n-pgadmin-1 2>/dev/null | grep -A 20 'Networks' | head -25 || docker inspect pgadmin 2>/dev/null | grep -A 20 'Networks' | head -25 || echo 'pgAdmin container not found'"
echo ""

echo "8. Testing direct HTTPS connection to Caddy (bypassing Cloudflare)..."
echo "Run this command locally to test:"
echo "curl -k https://$SSH_HOST:443 -H 'Host: pgadmin.openorbit.pro' -I"
echo ""

echo "9. Checking Caddy logs for SSL errors..."
run_remote "docker logs global-caddy --tail=30 2>&1 | grep -E 'error|ERROR|warn|WARN|pgadmin' || docker logs global-caddy --tail=30 2>&1"
echo ""

echo "=== Recommendations ==="
echo "1. If pgAdmin container is not running, start it"
echo "2. Check Cloudflare SSL/TLS settings - should be set to 'Full' or 'Full (strict)'"
echo "3. Ensure pgAdmin and Caddy are on the same Docker network"
echo "4. Check if Caddy can generate certificates for the domain"