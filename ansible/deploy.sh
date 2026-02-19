#!/bin/bash

# N8N Deployment Script
set -e

ENVIRONMENT=${1:-production}
ANSIBLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Deploying N8N to $ENVIRONMENT environment..."

# Check if secrets file exists and is encrypted
if [ ! -f "$ANSIBLE_DIR/vars/secrets.yml" ]; then
    echo "ERROR: secrets.yml not found!"
    echo "Please create and encrypt the secrets file:"
    echo "  cp $ANSIBLE_DIR/vars/secrets.yml.example $ANSIBLE_DIR/vars/secrets.yml"
    echo "  # Edit the file with your secrets"
    echo "  ansible-vault encrypt $ANSIBLE_DIR/vars/secrets.yml"
    exit 1
fi

# Check if inventory exists
if [ ! -f "$ANSIBLE_DIR/inventory/hosts.yml" ]; then
    echo "ERROR: inventory/hosts.yml not found!"
    echo "Please create the inventory file with your server details"
    exit 1
fi

# Install Ansible if not present
if ! command -v ansible &> /dev/null; then
    echo "Installing Ansible..."
    sudo apt update
    sudo apt install -y ansible
fi

# Install required Ansible collections
echo "Installing required Ansible collections..."
ansible-galaxy collection install community.docker

# Run the deployment
echo "Running Ansible playbook..."
ansible-playbook \
    -i "$ANSIBLE_DIR/inventory/hosts.yml" \
    --limit "$ENVIRONMENT" \
    --ask-vault-pass \
    --ask-become-pass \
    "$ANSIBLE_DIR/playbooks/deploy.yml"

echo "Deployment completed!"
echo ""
echo "Next steps:"
echo "1. Verify services are running: ssh user@server 'docker ps'"
echo "2. Check N8N: https://your-n8n-domain.com"
echo "3. Check logs: ssh user@server 'cd /opt/apps/n8n && docker-compose logs -f'"
