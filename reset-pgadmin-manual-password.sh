#!/bin/bash
#
# Reset pgAdmin on the server and set the login password manually.
# - With a password argument: uses that password for the new admin user.
# - Without argument: prompts you to type the password (not shown on screen).
# - Optionally updates the server's .env so the password persists across restarts.
#
# Usage:
#   ./reset-pgadmin-manual-password.sh 'MyNewPassword'
#   ./reset-pgadmin-manual-password.sh    # will prompt for password
#

set -e

SSH_USER="${SSH_USER:-deploy}"
SSH_HOST="${SSH_HOST:-142.132.239.135}"
SSH_PORT="${SSH_PORT:-25222}"
COMPOSE_DIR="/srv/www/n8n_production/current"
SHARED_DIR="/srv/www/n8n_production/shared"

run_remote() {
    ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "$1"
}

# Determine the password to use
NEW_PASSWORD=""
if [[ -n "$1" ]]; then
    NEW_PASSWORD="$1"
    echo "Using password from argument (length ${#NEW_PASSWORD} chars)."
else
    echo "No password given. You can type it now (input hidden)."
    read -rs -p "New pgAdmin password: " NEW_PASSWORD
    echo
    if [[ -z "$NEW_PASSWORD" ]]; then
        echo "Empty password not allowed. Aborting."
        exit 1
    fi
    read -rs -p "Confirm password: " CONFIRM
    echo
    if [[ "$NEW_PASSWORD" != "$CONFIRM" ]]; then
        echo "Passwords do not match. Aborting."
        exit 1
    fi
fi

# Get email from server .env (used for display and for compose override)
PGADMIN_EMAIL=$(run_remote "grep -E '^PGADMIN_DEFAULT_EMAIL=' $SHARED_DIR/.env 2>/dev/null | cut -d= -f2-" || echo "leemour@gmail.com")
echo "Email for pgAdmin login: $PGADMIN_EMAIL"
echo ""

read -p "Reset pgAdmin and set this password? All pgAdmin settings will be lost. (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "1. Stopping pgAdmin..."
run_remote "cd $COMPOSE_DIR && docker compose stop pgadmin"

echo ""
echo "2. Removing pgAdmin data (so the new password is applied on first start)..."
run_remote "cd $COMPOSE_DIR && rm -rf pgadmin_data/* pgadmin_data/.* 2>/dev/null || true"
run_remote "cd $COMPOSE_DIR && docker volume rm current_pgadmin_data 2>/dev/null || true"

echo ""
echo "3. Creating fresh pgAdmin data directory..."
run_remote "cd $COMPOSE_DIR && mkdir -p pgadmin_data"
run_remote "cd $COMPOSE_DIR && docker run --rm -v \$(pwd)/pgadmin_data:/var/lib/pgadmin busybox chown -R 5050:5050 /var/lib/pgadmin"

echo ""
echo "4. Starting pgAdmin with your chosen password..."
# Pass password via stdin to avoid escaping issues over SSH
printf '%s' "$NEW_PASSWORD" | ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "cd $COMPOSE_DIR && read -r -d '' PGPASS || true; export PGADMIN_DEFAULT_EMAIL='$PGADMIN_EMAIL'; export PGADMIN_DEFAULT_PASSWORD=\"\$PGPASS\"; docker compose up -d pgadmin < /dev/null"

echo ""
echo "5. Waiting for pgAdmin to initialize..."
sleep 10

echo ""
echo "6. Checking pgAdmin status..."
run_remote "docker ps | grep pgadmin || true"

echo ""
echo "=== Done ==="
echo "Log in with:"
echo "  URL:      https://pgadmin.openorbit.pro"
echo "  Email:    $PGADMIN_EMAIL"
echo "  Password: (the one you just set)"
echo ""
echo "To make this password persist across restarts, update on the server:"
echo "  $SHARED_DIR/.env"
echo "Set: PGADMIN_DEFAULT_PASSWORD='<your-password>'"
echo ""
