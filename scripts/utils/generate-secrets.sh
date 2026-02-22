#!/bin/bash

# Generate secrets for N8N deployment
echo "🔐 Generating secrets for N8N deployment..."
echo ""

echo "N8N_ENCRYPTION_KEY=$(openssl rand -hex 16)"
echo "N8N_USER_MANAGEMENT_JWT_SECRET=$(openssl rand -hex 32)"
echo "POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-25)"
echo "QDRANT_API_KEY=$(openssl rand -hex 32)"
echo ""

if command -v openssl &> /dev/null; then
    echo "LANGFUSE_SALT=$(openssl rand -hex 32)"
    echo "ENCRYPTION_KEY=$(openssl rand -hex 32)"
    echo "NEXTAUTH_SECRET=$(openssl rand -hex 32)"
    echo "CLICKHOUSE_PASSWORD=$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-25)"
    echo "MINIO_ROOT_PASSWORD=$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-25)"
    echo ""
    echo "Copy these values into ansible/configs/production.env"
else
    echo "❌ OpenSSL not found. Please install it to generate secure secrets."
fi
