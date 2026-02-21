#!/bin/bash

# Script to fix pgAdmin password using built-in utility

echo "🔧 Fixing pgAdmin password..."

# Get container name
CONTAINER_NAME="pgadmin"

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ pgAdmin container is not running. Starting it..."
    docker compose up -d pgadmin
    sleep 5
fi

# Load environment variables
source .env

# Use pgAdmin's built-in setup.py to reset password
echo "📝 Resetting password for: ${PGADMIN_DEFAULT_EMAIL}"

# Method 1: Using pgadmin4 CLI setup
docker exec -it ${CONTAINER_NAME} python /pgadmin4/setup.py \
    --email "${PGADMIN_DEFAULT_EMAIL}" \
    --password "${PGADMIN_DEFAULT_PASSWORD}" \
    update-user \
    --non-interactive

# If that doesn't work, try method 2: Direct password reset
if [ $? -ne 0 ]; then
    echo "Trying alternative method..."

    # Create a Python script inside the container
    docker exec ${CONTAINER_NAME} bash -c "cat > /tmp/reset_pass.py << 'EOF'
import sys
import os
sys.path.insert(0, '/pgadmin4')
os.chdir('/pgadmin4')

from pgadmin import create_app
from pgadmin.model import db, User
from werkzeug.security import generate_password_hash
import os

# Create app context
app = create_app()

with app.app_context():
    email = os.environ.get('PGADMIN_DEFAULT_EMAIL', 'admin@openorbit.pro')
    password = os.environ.get('PGADMIN_DEFAULT_PASSWORD', 'ChangeMeSecurePassword123!')

    user = User.query.filter_by(email=email).first()
    if user:
        user.password = generate_password_hash(password)
        db.session.commit()
        print(f'Password updated for {email}')
    else:
        # Create new user
        user = User(
            email=email,
            password=generate_password_hash(password),
            active=True,
            confirmed_at=datetime.datetime.now()
        )
        db.session.add(user)
        db.session.commit()
        print(f'User created: {email}')
EOF"

    # Run the script
    docker exec ${CONTAINER_NAME} python /tmp/reset_pass.py
fi

echo ""
echo "✅ Password reset complete!"
echo "📧 Email: ${PGADMIN_DEFAULT_EMAIL}"
echo "🔑 Password: ${PGADMIN_DEFAULT_PASSWORD}"
echo ""
echo "🌐 Access pgAdmin at: https://${PGADMIN_HOSTNAME}"

# For SMTP issue - disable email verification temporarily
echo ""
echo "💡 To disable SMTP requirement (for development), you can set these in pgAdmin config:"
echo "   MAIL_ENABLED = False"
echo "   SECURITY_RECOVERABLE = False"
echo ""
echo "Or add to docker-compose.yaml under pgadmin environment:"
echo "   PGADMIN_DISABLE_POSTFIX: 'true'"
echo "   PGADMIN_CONFIG_MAIL_ENABLED: 'False'"