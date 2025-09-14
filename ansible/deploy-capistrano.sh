#!/bin/bash

# Capistrano-style deployment script
set -e

ENVIRONMENT=${1:-production}
ANSIBLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Deploying N8N (Capistrano-style) to $ENVIRONMENT environment..."

# Check if config files exist
if [ ! -f "$ANSIBLE_DIR/configs/$ENVIRONMENT.env" ]; then
    echo "❌ ERROR: $ANSIBLE_DIR/configs/$ENVIRONMENT.env not found!"
    echo "Create your environment config file first:"
    echo "  cp $ANSIBLE_DIR/configs/production.env $ANSIBLE_DIR/configs/$ENVIRONMENT.env"
    echo "  # Edit with your secrets"
    exit 1
fi

# Install Ansible if not present
if ! command -v ansible &> /dev/null; then
    echo "❌ ERROR: Ansible not found!"
    echo "Please install Ansible first or run the server setup script:"
    echo "  $ANSIBLE_DIR/server-setup.sh $ENVIRONMENT"
    exit 1
fi

# Install required Ansible collections
echo "Installing required Ansible collections..."
ansible-galaxy collection install community.docker

# Run the deployment
echo "Running Capistrano-style deployment..."
ansible-playbook \
    -i "$ANSIBLE_DIR/inventory/hosts.yml" \
    --limit "$ENVIRONMENT" \
    "$ANSIBLE_DIR/playbooks/deploy-capistrano.yml"

echo "✅ Deployment completed!"
echo ""
echo "Commands:"
echo "  View logs: ssh -p 25222 deploy@142.132.239.135 'cd /srv/www/n8n/current && docker-compose logs -f'"
echo "  Rollback:  $ANSIBLE_DIR/rollback.sh $ENVIRONMENT"
