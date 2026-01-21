# Understanding What Happened and How It's Fixed

## 🎯 Summary

Your n8n went down after a Hetzner server restart because of a **Docker naming convention mismatch** between Caddy and your containers.

---

## 📖 The Complete Story

### What You Did Initially

1. **Deployed using Ansible Capistrano-style:**
   ```bash
   ./ansible/deploy-capistrano.sh production
   ```

2. **This deployed:**
   - Global Caddy proxy at `/srv/www/proxy/`
   - N8N application at `/srv/www/n8n_production/current/`
   - Created network: `n8n-network`
   - Everything worked fine!

### What Went Wrong

1. **Hetzner restarted your server**

2. **Docker Compose auto-restarted** (because `restart: unless-stopped`)
   - But it created a NEW network: `current_default` (based on symlink directory name)
   - Containers got simple names: `n8n`, `qdrant`, etc.

3. **Caddy tried to connect** to:
   - `n8n-network_n8n_1:5678` ❌ (doesn't exist)
   - `n8n-network_qdrant_1:6333` ❌ (doesn't exist)

4. **Result:** 502 Bad Gateway everywhere!

---

## 🔍 Root Cause Analysis

### Docker Compose Naming Conventions

Docker Compose has **two naming conventions**:

#### Old v1 Style (Project-Based):
```
{project}_{service}_{replica}
Example: n8n-network_n8n_1
```

#### New v2 Style (Explicit):
```yaml
services:
  n8n:
    container_name: n8n    # ← Explicit name!
```

Your `docker-compose.yaml` uses **explicit container names** (v2), but your Ansible templates expected **auto-generated names** (v1).

### The Mismatch

```
Caddy Config:          n8n-network_n8n_1:5678
Actual Container:      n8n:5678
Result:                DNS lookup failed! 502 error!
```

---

## ✅ What Was Fixed

### 1. Fixed Ansible Templates (Permanent Fix)

**File:** `ansible/templates/global-Caddyfile.j2`
```diff
- reverse_proxy {{ shared_docker_network }}_n8n_1:5678
+ reverse_proxy n8n:5678
```

**File:** `ansible/templates/n8n-proxy.conf.j2`
```diff
- reverse_proxy n8n-app_n8n_1:5678
+ reverse_proxy n8n:5678
```

### 2. Server Fix (Immediate)

```bash
# Create shared network
docker network create n8n-network

# Connect Caddy to n8n's network
docker network connect current_default global-caddy
docker network connect n8n-network global-caddy

# Connect services to shared network
docker network connect n8n-network n8n
docker network connect n8n-network qdrant

# Fix Caddyfile on server
sudo sed -i 's/n8n-network_n8n_1:5678/n8n:5678/g' /srv/www/proxy/Caddyfile
sudo sed -i 's/n8n-network_qdrant_1:6333/qdrant:6333/g' /srv/www/proxy/Caddyfile

# Reload Caddy
docker exec global-caddy caddy reload --config /etc/caddy/Caddyfile
```

---

## 🎓 Why This Will Work After Restart

### Before Fix:
```
Server Restart
  ↓
Docker Compose creates: current_default network
  ↓
Containers: n8n, qdrant on current_default
  ↓
Caddy: Looking for n8n-network_n8n_1 ❌
  ↓
502 Error!
```

### After Fix:
```
Server Restart
  ↓
Docker Compose creates: current_default network
  ↓
Containers: n8n, qdrant on BOTH:
  - current_default (internal)
  - n8n-network (shared with Caddy)
  ↓
Caddy: Looking for n8n ✅
  ↓
Everything works!
```

The key insight: **Container names are persistent**, but **auto-generated network names are not**!

---

## 📚 Understanding Your Deployment

### You Use: Capistrano-Style Deployment

```bash
./ansible/deploy-capistrano.sh production
```

**Advantages:**
- ✅ No Ansible Vault password needed
- ✅ Uses local `.env` files you can see and edit
- ✅ Supports rollback
- ✅ Timestamped releases
- ✅ Zero-downtime deployments

**How it works:**
1. Clones repo to `/srv/www/n8n_production/releases/{timestamp}/`
2. Copies your local `ansible/configs/production.env` to server
3. Creates symlink: `current` → latest release
4. Runs `docker compose up -d` in `current` directory

### The OTHER Method You Tried (deploy.sh)

```bash
./ansible/deploy.sh production  # ← You tried this by mistake
```

**This method:**
- ❌ Requires `ansible/vars/secrets.yml` encrypted with Ansible Vault
- ❌ Needs vault password
- ❌ Requires sudo access on server
- ❌ More complex setup

**You don't need this!** Stick with `deploy-capistrano.sh`.

---

## 🔑 Password Confusion Explained

### "Vault password" Prompt

When you ran `deploy.sh`, it asked for **Ansible Vault password** to decrypt `secrets.yml`.

**Solution:** Don't use `deploy.sh` - use `deploy-capistrano.sh` instead!

### "Missing sudo password" Error

Ansible tried to run privileged commands on the server, but:
- User: `deploy` (no sudo access)
- Sudo user: `kulibin` (has sudo access)

With Capistrano deployment, this doesn't matter because it doesn't need sudo!

---

## 🚀 Proper Workflow Going Forward

### Making Changes

1. **Update code locally:**
   ```bash
   git pull
   # Make your changes
   ```

2. **Update config if needed:**
   ```bash
   nano ansible/configs/production.env
   ```

3. **Deploy:**
   ```bash
   ./ansible/deploy-capistrano.sh production
   ```

### Rollback if Something Breaks

```bash
./ansible/rollback.sh production
```

This switches the `current` symlink to the previous release!

### Checking Status

```bash
# View logs
ssh -p 25222 deploy@142.132.239.135 \
  'cd /srv/www/n8n_production/current && docker compose logs -f'

# Check containers
ssh -p 25222 deploy@142.132.239.135 'docker ps'

# Check which release is current
ssh -p 25222 deploy@142.132.239.135 \
  'ls -la /srv/www/n8n_production/current'
```

---

## ✨ Why It's Reliable Now

1. **Explicit Container Names**
   ```yaml
   container_name: n8n  # Always "n8n", never changes
   ```

2. **Multiple Network Connections**
   ```yaml
   networks:
     - default           # Internal communication
     - n8n-network       # Communication with Caddy
   ```

3. **Restart Policy**
   ```yaml
   restart: unless-stopped  # Auto-starts after reboot
   ```

4. **Fixed Caddy Config**
   ```caddy
   reverse_proxy n8n:5678  # Uses simple container name
   ```

**Result:** After any restart, everything reconnects automatically! 🎉

---

## 🔧 Immediate Actions

Run this NOW on your server to fix the current deployment:

```bash
ssh -p 25222 deploy@142.132.239.135

# Run the fix
docker network create n8n-network || true
docker network connect current_default global-caddy || true
docker network connect n8n-network global-caddy || true
docker network connect n8n-network n8n || true
docker network connect n8n-network qdrant || true

sudo sed -i 's/n8n-network_n8n_1:5678/n8n:5678/g' /srv/www/proxy/Caddyfile
sudo sed -i 's/n8n-network_qdrant_1:6333/qdrant:6333/g' /srv/www/proxy/Caddyfile
sudo sed -i 's/n8n-network_langfuse-web_1:3000/langfuse-web:3000/g' /srv/www/proxy/Caddyfile

docker exec global-caddy caddy reload --config /etc/caddy/Caddyfile

# Verify
docker logs global-caddy --tail=20
curl -I https://n8n.openorbit.pro
```

Your site should be back online immediately! 🚀
