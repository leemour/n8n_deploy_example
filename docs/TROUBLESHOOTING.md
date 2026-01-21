# Troubleshooting Guide

## Understanding the Deployment

### Two Deployment Methods

This project supports **two different deployment approaches**:

#### Method 1: Capistrano-Style (Currently Used)
```bash
./ansible/deploy-capistrano.sh production
```

**How it works:**
- ✅ Uses local config files from `ansible/configs/production.env`
- ✅ No Ansible Vault needed
- ✅ Creates timestamped releases in `/srv/www/n8n_production/releases/`
- ✅ Symlinks `current` → latest release
- ✅ Copies `.env` and `Caddyfile` to `/srv/www/n8n_production/shared/`
- ✅ Supports rollback with `./ansible/rollback.sh production`

**Requirements:**
- User `deploy` must exist on server
- SSH key access configured
- No sudo password needed (uses `become: no`)

#### Method 2: Ansible Vault (Not Currently Used)
```bash
./ansible/deploy.sh production
```

**How it works:**
- Uses encrypted `ansible/vars/secrets.yml`
- Generates `.env` from templates
- Requires vault password and sudo access
- More secure for team environments

---

## Common Issues and Fixes

### Issue 1: 502 Bad Gateway After Server Restart

**Cause:** Docker Compose naming mismatch
- Caddy looks for: `n8n-network_n8n_1`
- Docker creates: `n8n` (with explicit container_name)

**Symptom:**
```
dial tcp: lookup n8n-network_n8n_1 on 127.0.0.11:53: server misbehaving
```

**Fix:**
```bash
# On server
docker network create n8n-network || true
docker network connect current_default global-caddy || true
docker network connect n8n-network n8n || true
docker network connect n8n-network qdrant || true

# Fix Caddyfile
sudo sed -i 's/n8n-network_n8n_1:5678/n8n:5678/g' /srv/www/proxy/Caddyfile
sudo sed -i 's/n8n-network_qdrant_1:6333/qdrant:6333/g' /srv/www/proxy/Caddyfile
sudo sed -i 's/n8n-network_langfuse-web_1:3000/langfuse-web:3000/g' /srv/www/proxy/Caddyfile

# Reload Caddy
docker exec global-caddy caddy reload --config /etc/caddy/Caddyfile
```

**Permanent Fix:** Already applied in commit fixing Ansible templates

---

### Issue 2: "Missing sudo password" Error

**Symptom:**
```
fatal: [n8n-production]: FAILED! => {"msg": "Task failed: Missing sudo password"}
```

**Cause:** Using wrong deployment script

**Fix:** Use `deploy-capistrano.sh` instead of `deploy.sh`

---

### Issue 3: Containers Don't Restart After Reboot

**Cause:** Docker Compose not set to auto-start

**Fix:** All services already have `restart: unless-stopped` in docker-compose.yaml

**Verify:**
```bash
ssh -p 25222 deploy@142.132.239.135
docker ps -a | grep n8n
```

Should show containers with "Up" status even after reboot.

---

## Deployment Checklist

### First-Time Setup

1. **Setup server:**
   ```bash
   ./ansible/server-setup.sh production
   ```

2. **Deploy global Caddy proxy:**
   ```bash
   ./ansible/deploy-capistrano.sh production
   ```

3. **Verify services:**
   ```bash
   ssh -p 25222 deploy@142.132.239.135
   docker ps
   docker network ls
   curl -I http://localhost:5678
   ```

### Regular Updates

1. **Update code:**
   ```bash
   git pull origin main
   ```

2. **Update config** (if needed):
   ```bash
   nano ansible/configs/production.env
   ```

3. **Deploy:**
   ```bash
   ./ansible/deploy-capistrano.sh production
   ```

4. **Rollback if needed:**
   ```bash
   ./ansible/rollback.sh production
   ```

---

## Understanding the Architecture

### Directory Structure on Server

```
/srv/www/
├── proxy/                          # Global Caddy
│   ├── docker-compose.yml
│   ├── Caddyfile
│   └── addons/
│       └── n8n.conf
│
└── n8n_production/
    ├── current -> releases/1757876633/  # Symlink to latest
    ├── releases/
    │   ├── 1757876150/
    │   ├── 1757876394/
    │   └── 1757876633/              # Latest release
    │       ├── docker-compose.yaml
    │       ├── .env -> ../shared/.env
    │       └── n8n_storage -> ../shared/n8n_storage
    └── shared/
        ├── .env                     # Persistent config
        ├── n8n_storage/             # Persistent data
        └── backups/
```

### Docker Networks

```
n8n-network (external)          # Shared by Caddy and all apps
└── global-caddy
└── n8n
└── qdrant
└── langfuse-web (if enabled)

current_default                 # Internal network for n8n services
└── n8n
└── n8n-worker
└── postgres
└── redis
└── qdrant
└── crawl4ai
```

### Container Names

All services use **explicit container names** (not auto-generated):
- `n8n` - Main application
- `n8n-worker` - Background workers
- `postgres` - Database
- `redis` - Queue system
- `qdrant` - Vector database
- `crawl4ai` - Web scraping service
- `global-caddy` - Reverse proxy

This ensures consistent naming across restarts.

---

## Verification Commands

```bash
# Check all containers
docker ps -a

# Check networks
docker network ls
docker network inspect n8n-network
docker network inspect current_default

# Check Caddy logs
docker logs global-caddy --tail=50

# Check n8n logs
cd /srv/www/n8n_production/current
docker compose logs -f n8n

# Check if n8n is accessible internally
curl -I http://localhost:5678
curl -I http://n8n:5678  # From global-caddy container
docker exec global-caddy curl -I http://n8n:5678

# Check external access
curl -I https://n8n.openorbit.pro
```

---

## Quick Reference

### SSH Access
```bash
ssh -p 25222 deploy@142.132.239.135
```

### Deploy
```bash
./ansible/deploy-capistrano.sh production
```

### Rollback
```bash
./ansible/rollback.sh production
```

### View Logs
```bash
ssh -p 25222 deploy@142.132.239.135 'cd /srv/www/n8n_production/current && docker compose logs -f'
```

### Restart Services
```bash
ssh -p 25222 deploy@142.132.239.135 'cd /srv/www/n8n_production/current && docker compose restart'
```
