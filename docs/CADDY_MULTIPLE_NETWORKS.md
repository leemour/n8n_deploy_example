# Fixing Caddy Multi-Network Configuration

## Problem

When you have both n8n (docker-compose) and Rails (Kamal) deployments, Caddy needs to be on multiple Docker networks to reach all services. The default Ansible template only connects Caddy to one network.

## Solution

### Option 1: Update Ansible Template (Recommended)

Edit the Ansible template to include both networks:

**File**: `ansible/templates/global-proxy-compose.yml.j2`

```yaml
version: '3.8'

networks:
  {{ shared_docker_network }}:
    external: true
  kamal:  # Add Kamal network
    external: true

volumes:
  caddy-data:
  caddy-config:

services:
  caddy:
    container_name: global-caddy
    image: docker.io/library/caddy:2-alpine
    ports:
      - "80:80"
      - "443:443"
    restart: unless-stopped
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./addons:/etc/caddy/addons:ro
      - caddy-data:/data:rw
      - caddy-config:/config:rw
    environment:
      - LETSENCRYPT_EMAIL={{ letsencrypt_email }}
    networks:
      - {{ shared_docker_network }}  # n8n-network
      - kamal                         # Kamal network for Rails
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    logging:
      driver: "json-file"
      options:
        max-size: "1m"
        max-file: "3"
```

Then redeploy with Ansible:

```bash
cd /path/to/n8n_deploy_example
ansible-playbook ansible/playbooks/deploy.yml -i ansible/inventory/hosts.yml
```

### Option 2: Manual Docker Compose File (Quick Fix)

If you're managing Caddy manually (not via Ansible), edit the compose file directly on the server:

```bash
# SSH into server
ssh deploy@142.132.239.135 -p 25222

# Edit the compose file
sudo nano /srv/www/proxy/docker-compose.yml
```

Add `kamal` to the networks section:

```yaml
networks:
  n8n-network:
    external: true
  kamal:
    external: true

services:
  caddy:
    # ... existing config ...
    networks:
      - n8n-network
      - kamal
```

Then recreate the container:

```bash
cd /srv/www/proxy
docker-compose down
docker-compose up -d
```

### Option 3: Post-Deployment Hook (Workaround)

Create a script that runs after container start to ensure network connections:

**File**: `/srv/www/proxy/connect-networks.sh`

```bash
#!/bin/bash
# Ensure Caddy is connected to all required networks

# List of required networks
NETWORKS=("n8n-network" "kamal")

for network in "${NETWORKS[@]}"; do
    # Check if network exists
    if docker network inspect "$network" >/dev/null 2>&1; then
        # Check if container is connected
        if ! docker network inspect "$network" | grep -q "global-caddy"; then
            echo "Connecting global-caddy to $network..."
            docker network connect "$network" global-caddy
        else
            echo "global-caddy already connected to $network"
        fi
    else
        echo "Warning: Network $network does not exist"
    fi
done

echo "Network connections verified"
```

Make it executable:

```bash
chmod +x /srv/www/proxy/connect-networks.sh
```

Add to crontab to run after reboot:

```bash
crontab -e

# Add this line:
@reboot sleep 30 && /srv/www/proxy/connect-networks.sh >> /var/log/caddy-networks.log 2>&1
```

Or add to systemd service:

```bash
sudo nano /etc/systemd/system/caddy-network-fix.service
```

```ini
[Unit]
Description=Ensure Caddy is connected to all Docker networks
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/srv/www/proxy/connect-networks.sh
RemainOnExit=yes
User=deploy

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable caddy-network-fix.service
sudo systemctl start caddy-network-fix.service
```

## Verification

After implementing any solution, verify Caddy is connected to all networks:

```bash
# Check n8n-network
docker network inspect n8n-network | grep -A 10 global-caddy

# Check kamal network
docker network inspect kamal | grep -A 10 global-caddy

# Test connectivity to n8n
docker exec global-caddy wget -O- --timeout=5 http://n8n:5678

# Test connectivity to Rails
docker exec global-caddy wget -O- --timeout=5 http://alignio-scheduler:3000/up
```

## Prevention Checklist

- [ ] Update Ansible template to include all networks
- [ ] Test container recreation: `docker-compose down && docker-compose up -d`
- [ ] Test server reboot
- [ ] Document required networks in README
- [ ] Add health checks for network connectivity
- [ ] Consider using Docker Swarm or Kubernetes for production with proper networking

## Notes

- **Why external: true?** - Because these networks are created by other docker-compose files (n8n and Kamal)
- **Why not use a single network?** - Kamal and docker-compose create their own networks; you need to join them
- **Alternative**: Consider creating a dedicated shared network that all services join explicitly
