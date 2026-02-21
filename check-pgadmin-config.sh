#!/bin/bash
#
# Check how pgAdmin is configured on the server and why login might fail.
# Run from your machine (uses SSH).
#
# Usage: ./check-pgadmin-config.sh
#

SSH_USER="${SSH_USER:-deploy}"
SSH_HOST="${SSH_HOST:-142.132.239.135}"
SSH_PORT="${SSH_PORT:-25222}"
COMPOSE_DIR="/srv/www/n8n_production/current"
SHARED_DIR="/srv/www/n8n_production/shared"

run_remote() {
    ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "$1"
}

echo "=== pgAdmin configuration check ==="
echo ""

echo "1. What the server .env says (used only on FIRST start of pgAdmin):"
echo "   ---"
run_remote "grep -E '^PGADMIN_DEFAULT_EMAIL=' $SHARED_DIR/.env 2>/dev/null || echo '(not set)'"
run_remote "p=\$(grep -E '^PGADMIN_DEFAULT_PASSWORD=' $SHARED_DIR/.env 2>/dev/null | cut -d= -f2-); if [ -n \"\$p\" ]; then echo \"PGADMIN_DEFAULT_PASSWORD=**set** (length \${#p} chars)\"; else echo 'PGADMIN_DEFAULT_PASSWORD=(not set)'; fi"
echo "   ---"
echo "   Important: These values are only used when pgAdmin starts with an EMPTY data directory."
echo "   If pgAdmin was ever started before, the login is whatever was in .env at that time."
echo ""

echo "2. Does pgAdmin already have stored data? (if yes, .env password is ignored)"
run_remote "ls -la $COMPOSE_DIR/pgadmin_data 2>/dev/null || echo '(no pgadmin_data dir)'"
run_remote "ls $COMPOSE_DIR/pgadmin_data/pgadmin4.db 2>/dev/null && echo '   -> Database exists: login is the OLD password from when it was first created.' || echo '   -> No database: next start will create user from .env'"
echo ""

echo "3. pgAdmin container status:"
run_remote "docker ps -a --filter name=pgadmin --format '   {{.Status}}  {{.Names}}' 2>/dev/null" || true
echo ""

echo "=== Summary ==="
echo "- Login email is from .env (step 1)."
echo "- The PASSWORD in .env only applies if there was no pgadmin4.db when the container first started."
echo "- If you see 'Database exists' in step 2, reset pgAdmin with: ./reset-pgadmin-manual-password.sh 'YourNewPassword'"
echo ""
