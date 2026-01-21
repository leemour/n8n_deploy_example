# Complete Deployment Guide

This guide covers the Capistrano-style deployment process using Ansible.

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Post-Deployment](#post-deployment)
- [Ongoing Operations](#ongoing-operations)

## Prerequisites

### Server Requirements

- **OS**: Ubuntu 22.04 or 24.04 LTS
- **Resources**: 4+ CPU cores, 8+ GB RAM, 100+ GB SSD
- **Network**: Public IP address, ports 80/443 accessible
- **Access**: SSH access with sudo privileges

### Local Requirements

- **Ansible**: Version 2.9+
  ```bash
  pip install ansible
  ```
- **SSH Key**: Configured for passwordless access
- **Git**: For cloning the repository

### DNS Setup

Create A records pointing to your server:
```
n8n.yourdomain.com       → YOUR_SERVER_IP
qdrant.yourdomain.com    → YOUR_SERVER_IP
langfuse.yourdomain.com  → YOUR_SERVER_IP
```

## Initial Setup

### 1. Clone Repository

```bash
git clone git@github.com:leemour/n8n_deploy_example.git
cd n8n_deploy_example
```

### 2. Install Ansible Collections

```bash
ansible-galaxy collection install community.docker
```

### 3. Configure Server Inventory

Edit `ansible/inventory/hosts.yml`:

```yaml
all:
  children:
    production:
      hosts:
        n8n-production:
          ansible_host: 142.132.239.135      # Your server IP
          ansible_port: 25222                 # Your SSH port
          ansible_user: deploy                # Deployment user
          deploy_user: deploy                 # Same as ansible_user
          sudo_user: kulibin                  # User with sudo access
          ansible_ssh_private_key_file: ~/.ssh/id_ed25519
          
          # Domain configuration
          server_domain: yourdomain.com
          letsencrypt_email: admin@yourdomain.com
    
    staging:
      hosts:
        n8n-staging:
          # ... staging configuration
```

**Key fields explained:**
- `ansible_host`: Your server's IP address
- `ansible_port`: SSH port (default 22, but often changed for security)
- `ansible_user`: User for deployment (should have SSH key access)
- `deploy_user`: Owner of deployed files
- `sudo_user`: User with sudo privileges (for initial server setup)
- `server_domain`: Base domain for your services
- `letsencrypt_email`: Email for SSL certificate notifications

## Configuration

### 1. Create Environment File

```bash
cp ansible/configs/production.env.example ansible/configs/production.env
nano ansible/configs/production.env
```

### 2. Required Secrets

Generate secure values for these variables:

```bash
# Generate encryption keys
openssl rand -hex 32  # For N8N_ENCRYPTION_KEY
openssl rand -hex 32  # For N8N_USER_MANAGEMENT_JWT_SECRET
openssl rand -hex 32  # For LANGFUSE_SALT
openssl rand -hex 32  # For ENCRYPTION_KEY

# Generate passwords
openssl rand -base64 32  # For POSTGRES_PASSWORD
openssl rand -base64 32  # For QDRANT_API_KEY
openssl rand -base64 32  # For CLICKHOUSE_PASSWORD
openssl rand -base64 32  # For MINIO_ROOT_PASSWORD
```

### 3. Configure Environment Variables

Edit `ansible/configs/production.env`:

```bash
# N8N Configuration
N8N_HOSTNAME=n8n.yourdomain.com
WEBHOOK_URL=https://n8n.yourdomain.com
N8N_ENCRYPTION_KEY=your-generated-key-here
N8N_USER_MANAGEMENT_JWT_SECRET=your-generated-secret-here

# Database
POSTGRES_VERSION=17
POSTGRES_USER=n8n_user
POSTGRES_PASSWORD=your-secure-password
POSTGRES_DB=n8n

# Redis
REDIS_HOST=redis
REDIS_PORT=6379

# Qdrant (Vector Database)
QDRANT_HOSTNAME=qdrant.yourdomain.com
QDRANT_API_KEY=your-qdrant-key

# Langfuse (LLM Monitoring) - Optional
LANGFUSE_HOSTNAME=langfuse.yourdomain.com
LANGFUSE_SALT=your-langfuse-salt
ENCRYPTION_KEY=your-encryption-key
NEXTAUTH_SECRET=your-nextauth-secret
CLICKHOUSE_PASSWORD=your-clickhouse-password
MINIO_ROOT_PASSWORD=your-minio-password
```

### 4. Configure Service Options

Edit `ansible/group_vars/production.yml`:

```yaml
# N8N Configuration
n8n:
  hostname: "n8n.{{ server_domain }}"
  worker_count: 2                     # Number of background workers
  enable_langfuse: true               # Enable LLM monitoring
  enable_qdrant: true                 # Enable vector database
  enable_crawl4ai: true               # Enable web scraping

# Qdrant Configuration
qdrant:
  hostname: "qdrant.{{ server_domain }}"

# Langfuse Configuration
langfuse:
  hostname: "langfuse.{{ server_domain }}"

# Resource limits
resource_limits:
  n8n_memory: "2g"
  postgres_memory: "1g"
  redis_memory: "512m"
  crawl4ai_memory: "4g"
```

## Deployment

### Method 1: First-Time Deployment (Recommended)

Run the complete setup including server preparation:

```bash
# 1. Setup server (installs Docker, creates users, configures firewall)
./ansible/server-setup.sh production

# 2. Deploy application
./ansible/deploy-capistrano.sh production
```

### Method 2: Application-Only Deployment

If server is already configured:

```bash
./ansible/deploy-capistrano.sh production
```

### What Happens During Deployment

The Capistrano deployment process:

1. **Creates release directories**
   ```
   /srv/www/n8n_production/
   ├── releases/
   ├── shared/
   └── current (symlink)
   ```

2. **Clones repository**
   - Fetches latest code from GitHub
   - Creates timestamped release: `/srv/www/n8n_production/releases/1234567890/`

3. **Copies configuration**
   - Copies `production.env` to `/srv/www/n8n_production/shared/.env`
   - Copies `Caddyfile.production` to `/srv/www/n8n_production/shared/Caddyfile`

4. **Creates symlinks**
   - Links `.env` from shared directory
   - Links `n8n_storage` from shared directory
   - Updates `current` → latest release

5. **Stops old services**
   - Gracefully stops containers from previous release

6. **Starts new services**
   - Pulls Docker images (if needed)
   - Starts containers from new release
   - Waits for health checks to pass

7. **Cleans up**
   - Keeps last 5 releases
   - Removes older releases

### Deployment Timeline

- **First deployment**: 3-5 minutes (downloading images)
- **Subsequent deployments**: 30-90 seconds (using cached images)

### Expected Output

```
🚀 Deploying N8N (Capistrano-style) to production environment...

PLAY [Deploy N8N (Capistrano Style)]

TASK [Create standard deployment directories]
ok: [n8n-production]

TASK [Clone repository to new release directory]
changed: [n8n-production]

TASK [Copy local config files to shared directory]
changed: [n8n-production]

TASK [Create symlinks to shared files]
changed: [n8n-production]

TASK [Stop current services]
changed: [n8n-production]

TASK [Update current symlink]
changed: [n8n-production]

TASK [Start new release]
changed: [n8n-production]

TASK [Include global proxy setup]
included: proxy-setup.yml

TASK [Template global Caddyfile]
changed: [n8n-production]

RUNNING HANDLER [restart global proxy]
changed: [n8n-production]

✅ Deployment completed!
```

## Post-Deployment

### 1. Verify Deployment

```bash
# Check if containers are running
ssh -p 25222 deploy@yourserver 'docker ps'

# You should see:
# - global-caddy
# - n8n
# - n8n-worker (2 replicas)
# - postgres
# - redis
# - qdrant
# - crawl4ai
```

### 2. Test Services

```bash
# Test n8n
curl -I https://n8n.yourdomain.com
# Expected: HTTP/2 200

# Test Qdrant
curl -I https://qdrant.yourdomain.com
# Expected: HTTP/2 200 or 401 (API key required)

# Check Caddy logs for errors
ssh -p 25222 deploy@yourserver 'docker logs global-caddy --tail=50'
# Should show no 502 errors
```

### 3. Access N8N

1. Open `https://n8n.yourdomain.com` in your browser
2. Create your first admin user
3. Start creating workflows!

### 4. Test Auto-Restart

Verify that services restart after reboot:

```bash
# Restart Docker (simulates server reboot)
ssh -p 25222 deploy@yourserver 'sudo systemctl restart docker'

# Wait for containers to restart
sleep 15

# Verify all services are up
ssh -p 25222 deploy@yourserver 'docker ps'
curl -I https://n8n.yourdomain.com
```

## Ongoing Operations

### Deploy Updates

```bash
# Pull latest code
git pull origin main

# Update configuration if needed
nano ansible/configs/production.env

# Deploy
./ansible/deploy-capistrano.sh production
```

### Rollback

If something goes wrong:

```bash
./ansible/rollback.sh production
```

This switches the `current` symlink to the previous release.

### View Logs

```bash
# N8N main application
ssh -p 25222 deploy@yourserver \
  'cd /srv/www/n8n_production/current && docker compose logs -f n8n'

# All services
ssh -p 25222 deploy@yourserver \
  'cd /srv/www/n8n_production/current && docker compose logs -f'

# Caddy proxy
ssh -p 25222 deploy@yourserver 'docker logs -f global-caddy'
```

### Restart Services

```bash
# Restart all n8n services
ssh -p 25222 deploy@yourserver \
  'cd /srv/www/n8n_production/current && docker compose restart'

# Restart specific service
ssh -p 25222 deploy@yourserver \
  'cd /srv/www/n8n_production/current && docker compose restart n8n'

# Restart Caddy
ssh -p 25222 deploy@yourserver \
  'cd /srv/www/proxy && docker compose restart'
```

### Scale Workers

Edit `ansible/group_vars/production.yml`:

```yaml
n8n:
  worker_count: 4  # Increase workers
```

Then redeploy:

```bash
./ansible/deploy-capistrano.sh production
```

### Backup Data

```bash
# SSH to server
ssh -p 25222 deploy@yourserver

# Backup PostgreSQL
cd /srv/www/n8n_production/current
docker compose exec postgres pg_dump -U n8n_user n8n > backup_$(date +%Y%m%d).sql

# Backup n8n storage
tar -czf n8n_storage_backup_$(date +%Y%m%d).tar.gz \
  /srv/www/n8n_production/shared/n8n_storage/

# Download backups to local machine
exit
scp -P 25222 deploy@yourserver:/srv/www/n8n_production/current/backup_*.sql ./
scp -P 25222 deploy@yourserver:n8n_storage_backup_*.tar.gz ./
```

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues and solutions.

### Quick Checks

```bash
# Check container status
ssh -p 25222 deploy@yourserver 'docker ps -a'

# Check disk space
ssh -p 25222 deploy@yourserver 'df -h'

# Check memory usage
ssh -p 25222 deploy@yourserver 'free -h'

# Check Docker logs
ssh -p 25222 deploy@yourserver 'docker compose -f /srv/www/n8n_production/current/docker-compose.yaml logs --tail=100'
```

## Advanced Configuration

### Custom Docker Compose Override

Create `docker-compose.override.yml` in your release:

```yaml
services:
  n8n:
    environment:
      - N8N_LOG_LEVEL=debug
      - N8N_LOG_OUTPUT=console
```

### Custom Caddyfile Addons

Create files in `/srv/www/proxy/addons/`:

```caddy
# /srv/www/proxy/addons/custom-service.conf
myapp.yourdomain.com {
    reverse_proxy myapp:8080
}
```

### Environment-Specific Configuration

Create `ansible/group_vars/staging.yml` for staging environment:

```yaml
n8n:
  hostname: "n8n.staging.{{ server_domain }}"
  worker_count: 1  # Fewer workers for staging
  enable_langfuse: false
  enable_qdrant: false
```

Deploy to staging:

```bash
./ansible/deploy-capistrano.sh staging
```

## Security Checklist

- [ ] Changed default SSH port
- [ ] Disabled password authentication (SSH keys only)
- [ ] Configured firewall (only 80, 443, SSH open)
- [ ] Set strong passwords for all services
- [ ] Enabled automatic security updates
- [ ] Configured backup strategy
- [ ] Set up monitoring/alerting
- [ ] Reviewed Docker container permissions
- [ ] Configured log rotation

## Performance Tuning

### Database Optimization

```sql
-- Connect to PostgreSQL
docker exec -it postgres psql -U n8n_user -d n8n

-- Check database size
SELECT pg_size_pretty(pg_database_size('n8n'));

-- Vacuum analyze
VACUUM ANALYZE;
```

### Worker Scaling

Monitor CPU/memory usage and adjust workers:

```bash
# Check resource usage
ssh -p 25222 deploy@yourserver 'docker stats --no-stream'
```

If workers are underutilized, you can increase `worker_count`.

## Next Steps

- Read [CADDY_SETUP.md](CADDY_SETUP.md) for Caddy configuration details
- Check [N8N_MICROSERVICES_GUIDE.md](N8N_MICROSERVICES_GUIDE.md) for service details
- Review [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues
