#!/bin/bash

# Initial server setup script (requires sudo)
set -e

ENVIRONMENT=${1:-production}
ANSIBLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔧 Setting up server for $ENVIRONMENT environment (requires sudo)..."

# Check if config files exist
if [ ! -f "$ANSIBLE_DIR/configs/$ENVIRONMENT.env" ]; then
    echo "❌ ERROR: $ANSIBLE_DIR/configs/$ENVIRONMENT.env not found!"
    echo "Create your environment config file first:"
    echo "  cp $ANSIBLE_DIR/configs/production.env $ANSIBLE_DIR/configs/$ENVIRONMENT.env"
    echo "  # Edit with your secrets"
    exit 1
fi

# Install required Ansible collections
echo "Installing required Ansible collections..."
ansible-galaxy collection install community.docker

# Change to ansible directory to ensure group_vars are loaded
cd "$ANSIBLE_DIR"

# Run the server setup
echo "Running server setup as kulibin user (will prompt for sudo password)..."
ansible-playbook \
    -i "inventory/hosts.yml" \
    --limit "$ENVIRONMENT" \
    --user kulibin \
    --ask-become-pass \
    "playbooks/server-setup.yml"

echo "✅ Server setup completed!"
echo ""
echo "Next steps:"
echo "  Deploy: $ANSIBLE_DIR/deploy-capistrano.sh $ENVIRONMENT"
