#!/bin/bash

# Pre-deployment validation script
set -e

echo "🔍 Pre-deployment validation for N8N..."
echo ""

# Check if secrets are configured
echo "📋 Checking configuration files..."
if grep -q "your-production-" ansible/configs/production.env; then
    echo "❌ ERROR: You still have placeholder values in ansible/configs/production.env"
    echo "   Please run ./generate-secrets.sh and update the config file"
    exit 1
else
    echo "✅ Production config appears to be configured"
fi

# Check Ansible connection
echo ""
echo "🔗 Testing Ansible connection..."
if ansible -i ansible/inventory/hosts.yml production -m ping > /dev/null 2>&1; then
    echo "✅ Ansible can connect to production server"
else
    echo "❌ ERROR: Cannot connect to production server"
    echo "   Check your SSH key and server connectivity"
    exit 1
fi

# Check syntax
echo ""
echo "📝 Validating Ansible syntax..."
if ansible-playbook --syntax-check ansible/playbooks/deploy-capistrano.yml -i ansible/inventory/hosts.yml > /dev/null 2>&1; then
    echo "✅ Ansible playbook syntax is valid"
else
    echo "❌ ERROR: Ansible playbook syntax error"
    exit 1
fi

# Check if git repo is clean
echo ""
echo "📚 Checking git status..."
if git status --porcelain | grep -q .; then
    echo "⚠️  WARNING: You have uncommitted changes"
    echo "   Consider committing and pushing before deployment"
else
    echo "✅ Git repository is clean"
fi

echo ""
echo "🎉 All checks passed! Ready to deploy."
echo ""
echo "Next steps:"
echo "1. Commit and push your changes: git add . && git commit -m 'Initial deployment config' && git push"
echo "2. Run deployment: cd ansible && ./deploy-capistrano.sh production"
