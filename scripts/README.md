# Scripts

This directory contains utility scripts for managing the n8n deployment.

## Directory Structure

```
scripts/
├── db/                    # Database management scripts
├── deploy/               # Deployment automation scripts
├── pgadmin/             # pgAdmin management utilities
│   ├── check-pgadmin-config.sh      # Check pgAdmin configuration on server
│   └── reset-pgadmin-manual-password.sh  # Reset pgAdmin password
└── utils/               # General utilities
    └── generate-secrets.sh  # Generate secure passwords and keys

```

## pgAdmin Scripts

### check-pgadmin-config.sh
Checks the current pgAdmin configuration on the server and helps diagnose login issues.

**Usage:**
```bash
./scripts/pgadmin/check-pgadmin-config.sh
```

### reset-pgadmin-manual-password.sh
Resets the pgAdmin database and sets a new admin password. Can be used with or without a password argument.

**Usage:**
```bash
# With password argument
./scripts/pgadmin/reset-pgadmin-manual-password.sh "NewSecurePassword"

# Without argument (prompts for password)
./scripts/pgadmin/reset-pgadmin-manual-password.sh
```

## Utility Scripts

### generate-secrets.sh
Generates secure random values for all required environment variables.

**Usage:**
```bash
./scripts/utils/generate-secrets.sh >> .env
```

**Generates:**
- N8N_ENCRYPTION_KEY
- N8N_USER_MANAGEMENT_JWT_SECRET
- POSTGRES_PASSWORD
- QDRANT_API_KEY
- LANGFUSE_SALT
- CLICKHOUSE_PASSWORD
- MINIO_ROOT_PASSWORD
- PGADMIN_DEFAULT_PASSWORD

## Database Scripts

Located in `scripts/db/` - contains database backup and restore utilities.

## Deployment Scripts

Located in `scripts/deploy/` - contains deployment automation scripts.