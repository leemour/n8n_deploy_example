#!/bin/bash

echo "=== Resetting pgAdmin Password ==="
echo ""

# SSH connection details
SSH_USER="deploy"
SSH_HOST="142.132.239.135"
SSH_PORT="25222"

# Function to run remote commands
run_remote() {
    ssh -p $SSH_PORT $SSH_USER@$SSH_HOST "$1"
}

echo "Current pgAdmin credentials from server's .env file:"
echo "----------------------------------------------------"
run_remote 'cd /srv/www/n8n_production/shared && grep -E "PGADMIN_DEFAULT_EMAIL|PGADMIN_DEFAULT_PASSWORD" .env'
echo ""

echo "To reset the pgAdmin password, we need to:"
echo "1. Delete the existing pgAdmin database"
echo "2. Restart pgAdmin with the password from .env"
echo ""
read -p "Do you want to proceed? This will delete all pgAdmin settings! (y/N): " confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Resetting pgAdmin..."

# Stop pgAdmin
echo "1. Stopping pgAdmin..."
run_remote "cd /srv/www/n8n_production/current && docker compose stop pgadmin"

# Remove pgAdmin data
echo ""
echo "2. Removing pgAdmin data..."
run_remote "cd /srv/www/n8n_production/current && rm -rf pgadmin_data/* pgadmin_data/.* 2>/dev/null || true"
run_remote "cd /srv/www/n8n_production/current && docker volume rm current_pgadmin_data 2>/dev/null || true"

# Recreate with correct permissions
echo ""
echo "3. Creating fresh pgAdmin data directory..."
run_remote "cd /srv/www/n8n_production/current && mkdir -p pgadmin_data"
run_remote "cd /srv/www/n8n_production/current && docker run --rm -v \$(pwd)/pgadmin_data:/var/lib/pgadmin busybox chown -R 5050:5050 /var/lib/pgadmin"

# Start pgAdmin
echo ""
echo "4. Starting pgAdmin with fresh configuration..."
run_remote "cd /srv/www/n8n_production/current && docker compose up -d pgadmin"

echo ""
echo "5. Waiting for pgAdmin to initialize..."
sleep 10

echo ""
echo "6. Checking pgAdmin status..."
run_remote "docker ps | grep pgadmin"

echo ""
echo "7. Checking pgAdmin logs..."
run_remote "cd /srv/www/n8n_production/current && docker compose logs pgadmin --tail=10"

echo ""
echo "=== Password Reset Complete ==="
echo ""
echo "pgAdmin has been reset. Use these credentials to login:"
echo "--------------------------------------------------------"
run_remote 'cd /srv/www/n8n_production/shared && echo "Email: $(grep PGADMIN_DEFAULT_EMAIL .env | cut -d= -f2)" && echo "Password: $(grep PGADMIN_DEFAULT_PASSWORD .env | cut -d= -f2)"'
echo ""
echo "URL: https://pgadmin.openorbit.pro"
echo ""
echo "Note: If the email shows as 'admin@openorbit.pro', that's the default value."