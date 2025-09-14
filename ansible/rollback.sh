#!/bin/bash

# Rollback script
set -e

ENVIRONMENT=${1:-production}
ANSIBLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔄 Rolling back N8N in $ENVIRONMENT environment..."

ansible-playbook \
    -i "$ANSIBLE_DIR/inventory/hosts.yml" \
    --limit "$ENVIRONMENT" \
    "$ANSIBLE_DIR/playbooks/rollback.yml"

echo "✅ Rollback completed!"
