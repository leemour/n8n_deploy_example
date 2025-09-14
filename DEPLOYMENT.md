# N8N Deployment Guide with Ansible

1. Run `./pre-deploy-check.sh` to check the prerequisites
2. Run `./ansible/server-setup.sh production` to setup the server
3. Run `./ansible/deploy-capistrano.sh production` to deploy the application

This guide explains how to deploy your N8N application to Ubuntu 24 servers using Ansible with a common proxy architecture.

## Architecture Overview

```
Server Structure:
├── /opt/proxy/ (Global Caddy - handles SSL & routing for all apps)
├── /opt/apps/n8n/ (This N8N application)
├── /opt/apps/app2/ (Your other applications)
└── /opt/apps/app3/
```

### Key Benefits:
- **Single SSL management** - One Caddy instance handles all certificates
- **Easy multi-app deployment** - Each app in its own directory
- **Shared Docker network** - Apps can communicate if needed
- **Centralized logging & monitoring**
- **Easy scaling** - Add new apps without proxy conflicts

## Prerequisites

1. **Server Requirements:**
   - Ubuntu 24.04 LTS
   - 4+ CPU cores, 8+ GB RAM, 100+ GB SSD
   - Docker and Docker Compose installed
   - SSH access with sudo privileges

2. **DNS Setup:**
   - Point your domains to server IP:
     - `n8n.yourdomain.com` → Server IP
     - `qdrant.yourdomain.com` → Server IP (if enabled)
     - `langfuse.yourdomain.com` → Server IP (if enabled)

3. **Local Requirements:**
   - Ansible installed (`pip install ansible`)
   - SSH key access to target server

## Quick Start

### 1. Configure Inventory

Edit `ansible/inventory/hosts.yml`:

```yaml
all:
  children:
    production:
      hosts:
        n8n-server:
          ansible_host: YOUR_SERVER_IP
          ansible_user: ubuntu
          ansible_ssh_private_key_file: ~/.ssh/id_rsa
          server_domain: yourdomain.com
          letsencrypt_email: admin@yourdomain.com
```

### 2. Configure Secrets

```bash
# Copy and edit secrets
cp ansible/vars/secrets.yml.example ansible/vars/secrets.yml
nano ansible/vars/secrets.yml

# Encrypt secrets file
ansible-vault encrypt ansible/vars/secrets.yml
```

**Required secrets to configure:**
- `n8n_encryption_key` - 32 character random string
- `n8n_jwt_secret` - Random string for JWT signing
- `postgres_password` - Secure database password
- `qdrant_api_key` - API key for Qdrant (if enabled)

### 3. Deploy

```bash
cd ansible
./deploy.sh production
```

Enter your vault password when prompted.

## Configuration Options

### Environment Variables

Edit `ansible/group_vars/production.yml`:

```yaml
# N8N Configuration
n8n:
  hostname: "n8n.yourdomain.com"
  worker_count: 3                    # Number of worker processes
  enable_langfuse: true             # Enable LLM monitoring
  enable_qdrant: true               # Enable vector database
  enable_crawl4ai: true             # Enable web scraping

# Resource Limits
resource_limits:
  n8n_memory: "2g"
  postgres_memory: "1g"
  redis_memory: "512m"
  crawl4ai_memory: "4g"
```

### Adding More Applications

To add another application to the same server:

1. **Create new app directory structure:**
   ```bash
   /opt/apps/myapp/
   ├── docker-compose.yml
   ├── .env
   └── (app files)
   ```

2. **Configure app to use shared network:**
   ```yaml
   # In your app's docker-compose.yml
   networks:
     shared-network:
       external: true
   ```

3. **Add proxy configuration:**
   ```bash
   # Create /opt/proxy/addons/myapp.conf
   myapp.yourdomain.com {
       reverse_proxy myapp_web_1:3000
   }
   ```

4. **Restart global proxy:**
   ```bash
   cd /opt/proxy && docker-compose restart
   ```

## Deployment Commands

### Initial Deployment
```bash
cd ansible
./deploy.sh production
```

### Update Deployment
```bash
# Update only N8N services
ansible-playbook -i inventory/hosts.yml --limit production --tags n8n --ask-vault-pass playbooks/deploy.yml

# Update only proxy
ansible-playbook -i inventory/hosts.yml --limit production --tags proxy --ask-vault-pass playbooks/deploy.yml
```

### Backup and Restore

**Automated Backups** (configured automatically):
- Daily at 2 AM UTC
- Retains 30 days of backups
- Located in `/opt/backups/`

**Manual Backup:**
```bash
ssh user@server '/opt/backups/scripts/backup.sh'
```

**Restore from Backup:**
```bash
# On server
cd /opt/apps/n8n
docker-compose down

# Restore database
docker-compose up -d postgres
sleep 10
docker-compose exec -T postgres psql -U n8n_user -d n8n < /opt/backups/postgres/BACKUP_DATE/n8n_db.sql

# Restore storage
tar -xzf /opt/backups/n8n/BACKUP_DATE/n8n_storage.tar.gz

# Restart services
docker-compose up -d
```

## Monitoring and Maintenance

### Check Service Status
```bash
# All services
ssh user@server 'docker ps'

# N8N specific
ssh user@server 'cd /opt/apps/n8n && docker-compose ps'

# Global proxy
ssh user@server 'cd /opt/proxy && docker-compose ps'
```

### View Logs
```bash
# N8N logs
ssh user@server 'cd /opt/apps/n8n && docker-compose logs -f n8n'

# Proxy logs
ssh user@server 'cd /opt/proxy && docker-compose logs -f caddy'

# All services
ssh user@server 'docker logs -f container_name'
```

### Updates
```bash
# Update images and restart
ssh user@server 'cd /opt/apps/n8n && docker-compose pull && docker-compose up -d'
```

## Alternative Proxy Options

### Option 1: Traefik (Instead of Caddy)

If you prefer Traefik for better service discovery:

```yaml
# In global proxy docker-compose.yml
services:
  traefik:
    image: traefik:v3.0
    command:
      - --api.dashboard=true
      - --providers.docker=true
      - --providers.docker.network=shared-network
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.letsencrypt.acme.email=admin@yourdomain.com
      - --certificatesresolvers.letsencrypt.acme.storage=/acme.json
      - --certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web
```

### Option 2: Nginx Proxy Manager

For a web UI-based proxy management:

```yaml
services:
  nginx-proxy-manager:
    image: 'jc21/nginx-proxy-manager:latest'
    ports:
      - '80:80'
      - '443:443'
      - '81:81'  # Admin interface
```

## Troubleshooting

### Common Issues

1. **SSL Certificate Issues:**
   ```bash
   # Check Caddy logs
   ssh user@server 'cd /opt/proxy && docker-compose logs caddy'
   
   # Verify DNS resolution
   nslookup n8n.yourdomain.com
   ```

2. **Service Won't Start:**
   ```bash
   # Check service logs
   ssh user@server 'cd /opt/apps/n8n && docker-compose logs service_name'
   
   # Check resource usage
   ssh user@server 'docker stats'
   ```

3. **Database Connection Issues:**
   ```bash
   # Check PostgreSQL health
   ssh user@server 'cd /opt/apps/n8n && docker-compose exec postgres pg_isready -U n8n_user'
   ```

4. **Network Issues:**
   ```bash
   # Verify shared network exists
   ssh user@server 'docker network ls | grep shared'
   
   # Check container network connectivity
   ssh user@server 'docker exec n8n ping postgres'
   ```

### Performance Tuning

1. **Scale N8N Workers:**
   ```yaml
   # In group_vars/production.yml
   n8n:
     worker_count: 5  # Increase based on CPU cores
   ```

2. **Optimize Database:**
   ```yaml
   # Add to postgres service
   environment:
     - POSTGRES_SHARED_PRELOAD_LIBRARIES=pg_stat_statements
   command: >
     postgres
     -c shared_preload_libraries=pg_stat_statements
     -c max_connections=200
     -c shared_buffers=256MB
   ```

3. **Redis Optimization:**
   ```yaml
   # Add to redis service
   command: >
     valkey-server
     --save 30 1
     --maxmemory 1gb
     --maxmemory-policy allkeys-lru
   ```

## Security Considerations

1. **Firewall Configuration:**
   - Only ports 22 (SSH), 80 (HTTP), 443 (HTTPS) should be open
   - All other services should be internal only

2. **Secret Management:**
   - Always encrypt secrets with ansible-vault
   - Use strong, unique passwords
   - Rotate secrets regularly

3. **Updates:**
   - Enable automatic security updates
   - Regularly update Docker images
   - Monitor security advisories

4. **Backup Security:**
   - Encrypt backup files
   - Store backups off-server
   - Test restore procedures regularly

## Next Steps

After successful deployment:

1. **Access N8N:** https://n8n.yourdomain.com
2. **Create admin user** in N8N web interface
3. **Configure workflows** and test functionality
4. **Set up monitoring** (optional)
5. **Configure additional applications** using the same pattern

## Support

For issues specific to this deployment:
1. Check logs first: `docker-compose logs service_name`
2. Verify configuration files
3. Check DNS and SSL certificate status
4. Review firewall and network settings
