# Caddy Reverse Proxy Setup

Complete guide to Caddy configuration for n8n deployment.

## 📋 Overview

Caddy acts as a reverse proxy that:
- **Handles SSL/TLS** - Automatic Let's Encrypt certificates
- **Routes Traffic** - Directs requests to appropriate containers
- **Manages Multiple Domains** - Production and staging on same server
- **Provides Security** - TLS termination, rate limiting

## 🏗️ Architecture

```
Internet (HTTPS)
      ↓
   Caddy :443
      ↓
Docker Network: n8n-network
      ├─→ n8n:5678 (n8n.yourdomain.com)
      ├─→ qdrant:6333 (qdrant.yourdomain.com)
      └─→ langfuse-web:3000 (langfuse.yourdomain.com)
```

## 📂 File Structure

```
/srv/www/proxy/
├── docker-compose.yml      # Caddy container definition
├── Caddyfile              # Main routing configuration
├── .env                   # Environment variables
├── addons/                # Additional site configurations
│   └── n8n.conf          # N8N-specific routes (unused in global setup)
├── config/               # Caddy internal config (auto-generated)
└── data/                 # SSL certificates (auto-generated)
```

## 🔧 Configuration Files

### Global Caddyfile

Location: `/srv/www/proxy/Caddyfile`

```caddy
{
    # Global options
    email leemour@gmail.com
}

# Production domains (openorbit.pro)
n8n.openorbit.pro {
    reverse_proxy n8n:5678
}

qdrant.openorbit.pro {
    reverse_proxy qdrant:6333
}

langfuse.openorbit.pro {
    reverse_proxy langfuse-web:3000
}

# Staging domains (staging.openorbit.pro)
n8n.staging.openorbit.pro {
    reverse_proxy n8n:5678
}

qdrant.staging.openorbit.pro {
    reverse_proxy qdrant:6333
}

langfuse.staging.openorbit.pro {
    reverse_proxy langfuse-web:3000
}

# Import all application configurations from addons
import /etc/caddy/addons/*.conf
```

**Key points:**
- Uses **simple container names** (`n8n:5678`), not network-prefixed names
- Automatic HTTPS for all domains
- Production and staging on same server
- Extensible via addons

### Docker Compose Configuration

Location: `/srv/www/proxy/docker-compose.yml`

```yaml
version: '3.8'

networks:
  n8n-network:
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
      - LETSENCRYPT_EMAIL=leemour@gmail.com
    networks:
      - n8n-network
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

**Security features:**
- Drops all capabilities except `NET_BIND_SERVICE`
- Read-only Caddyfile
- Limited logging
- Restart policy

## 🚀 Deployment

### Automatic (via Ansible)

Caddy is deployed automatically with Capistrano deployment:

```bash
./ansible/deploy-capistrano.sh production
```

This:
1. Templates the Caddyfile with correct domains
2. Creates docker-compose.yml
3. Starts/restarts Caddy if configuration changed

### Manual Deployment

If you need to deploy Caddy separately:

```bash
ssh -p 25222 deploy@yourserver

# Navigate to proxy directory
cd /srv/www/proxy

# Start Caddy
docker compose up -d

# View logs
docker compose logs -f
```

## 🔐 SSL Certificates

### Automatic Certificate Management

Caddy automatically:
1. **Obtains certificates** from Let's Encrypt on first request
2. **Renews certificates** before expiration (60 days before)
3. **Serves HTTPS** automatically for all domains

### Certificate Storage

Certificates are stored in Docker volume:
```
/var/lib/docker/volumes/proxy_caddy-data/_data/caddy/certificates/
```

### Verify Certificates

```bash
# Check certificate expiration
echo | openssl s_client -servername n8n.openorbit.pro \
  -connect n8n.openorbit.pro:443 2>/dev/null | \
  openssl x509 -noout -dates

# View Caddy's certificate info
ssh -p 25222 deploy@yourserver \
  'docker exec global-caddy caddy list-modules'
```

### Force Certificate Renewal

```bash
ssh -p 25222 deploy@yourserver

# Stop Caddy
cd /srv/www/proxy
docker compose stop

# Remove certificates
docker volume rm proxy_caddy-data

# Start Caddy (will obtain new certificates)
docker compose up -d
```

## 🔄 Container Name Resolution

### How It Works

Caddy resolves container names via Docker's **internal DNS**:

1. Container `global-caddy` is on network `n8n-network`
2. Container `n8n` is ALSO on network `n8n-network`
3. Docker DNS resolves `n8n` → `10.20.0.X` (internal IP)
4. Caddy connects directly to `n8n:5678`

### Network Configuration

Both Caddy and application containers must be on the **same Docker network**:

```yaml
# Caddy
networks:
  - n8n-network

# N8N
networks:
  - default          # Internal communication (postgres, redis)
  - n8n-network      # External communication (Caddy)
```

### Troubleshooting DNS

```bash
# Check if containers are on same network
docker network inspect n8n-network

# Test DNS resolution from Caddy container
docker exec global-caddy nslookup n8n
docker exec global-caddy ping -c 1 n8n

# Test HTTP connection
docker exec global-caddy curl -I http://n8n:5678
```

## 🛠️ Operations

### Reload Configuration

After changing Caddyfile:

```bash
ssh -p 25222 deploy@yourserver

# Reload without downtime
docker exec global-caddy caddy reload --config /etc/caddy/Caddyfile

# Or restart container
cd /srv/www/proxy
docker compose restart
```

### View Logs

```bash
# Real-time logs
ssh -p 25222 deploy@yourserver 'docker logs -f global-caddy'

# Last 50 lines
ssh -p 25222 deploy@yourserver 'docker logs --tail=50 global-caddy'

# Filter for errors
ssh -p 25222 deploy@yourserver 'docker logs global-caddy 2>&1 | grep -i error'
```

### Check Configuration

```bash
# Validate Caddyfile syntax
docker exec global-caddy caddy validate --config /etc/caddy/Caddyfile

# Format Caddyfile
docker exec global-caddy caddy fmt --overwrite /etc/caddy/Caddyfile
```

### Monitor Performance

```bash
# Check resource usage
docker stats global-caddy --no-stream

# Check active connections (from inside container)
docker exec global-caddy netstat -an | grep ESTABLISHED | wc -l
```

## 🎨 Customization

### Add New Service

Create `/srv/www/proxy/addons/myapp.conf`:

```caddy
myapp.yourdomain.com {
    reverse_proxy myapp:8080
}
```

Reload Caddy:
```bash
docker exec global-caddy caddy reload --config /etc/caddy/Caddyfile
```

### Add Custom Headers

```caddy
n8n.openorbit.pro {
    reverse_proxy n8n:5678
    
    header {
        # Security headers
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
    }
}
```

### Add Basic Auth

```caddy
admin.yourdomain.com {
    basicauth {
        admin $2a$14$Zkx19XLiW6VYouLHR5NmfOFU0z2GTNmpkT/5qqR7hx4IjWJPDhjvG
    }
    reverse_proxy admin-panel:3000
}
```

Generate password hash:
```bash
docker exec global-caddy caddy hash-password --plaintext 'your-password'
```

### Add Rate Limiting

```caddy
n8n.openorbit.pro {
    rate_limit {
        zone n8n {
            key {remote_host}
            events 100
            window 1m
        }
    }
    reverse_proxy n8n:5678
}
```

### Add Access Logging

```caddy
n8n.openorbit.pro {
    log {
        output file /var/log/caddy/n8n-access.log {
            roll_size 100mb
            roll_keep 10
        }
        format json
    }
    reverse_proxy n8n:5678
}
```

## 🐛 Troubleshooting

### 502 Bad Gateway

**Symptom**: `dial tcp: lookup n8n on 127.0.0.11:53: server misbehaving`

**Cause**: Container name mismatch or network issue

**Solutions**:

1. **Check container name**:
   ```bash
   docker ps --format "table {{.Names}}\t{{.Networks}}"
   ```
   Make sure container is named exactly `n8n` (not `n8n-network_n8n_1`)

2. **Check network**:
   ```bash
   docker network inspect n8n-network | grep -A 5 "n8n"
   ```
   Make sure both `global-caddy` and `n8n` are on `n8n-network`

3. **Connect to network**:
   ```bash
   docker network connect n8n-network global-caddy
   docker network connect n8n-network n8n
   docker restart global-caddy
   ```

4. **Fix Caddyfile**:
   ```bash
   # Use simple names
   sed -i 's/n8n-network_n8n_1:5678/n8n:5678/g' /srv/www/proxy/Caddyfile
   docker exec global-caddy caddy reload --config /etc/caddy/Caddyfile
   ```

### Certificate Issues

**Can't obtain certificate**:

1. **Check DNS**:
   ```bash
   nslookup n8n.yourdomain.com
   dig n8n.yourdomain.com
   ```

2. **Check ports**:
   ```bash
   sudo ufw status
   sudo netstat -tlnp | grep -E ':80|:443'
   ```

3. **Check logs**:
   ```bash
   docker logs global-caddy 2>&1 | grep -i "acme\|certificate"
   ```

4. **Force renewal**:
   ```bash
   docker exec global-caddy caddy reload --config /etc/caddy/Caddyfile --force
   ```

### High Memory Usage

```bash
# Check Caddy memory
docker stats global-caddy --no-stream

# If too high, restart
docker restart global-caddy
```

### Connection Refused

```bash
# Test from Caddy container
docker exec global-caddy wget -O- http://n8n:5678

# Check if n8n is running
docker ps | grep n8n

# Check n8n logs
docker logs n8n --tail=50
```

## 📊 Monitoring

### Health Check Endpoint

Caddy automatically provides a health endpoint:

```bash
curl http://yourserver:2019/health
```

### Metrics (Optional)

Enable metrics in Caddyfile:

```caddy
{
    servers {
        metrics
    }
}
```

Access metrics:
```bash
curl http://localhost:2019/metrics
```

### Integration with Monitoring Tools

**Prometheus**:
```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'caddy'
    static_configs:
      - targets: ['caddy:2019']
```

## 🔒 Security Best Practices

1. **Use HTTPS only**:
   ```caddy
   http://n8n.yourdomain.com {
       redir https://{host}{uri} permanent
   }
   ```

2. **Set security headers**:
   ```caddy
   header {
       Strict-Transport-Security "max-age=31536000"
       X-Content-Type-Options "nosniff"
       X-Frame-Options "DENY"
       Referrer-Policy "no-referrer-when-downgrade"
   }
   ```

3. **Limit request size**:
   ```caddy
   request_body {
       max_size 10MB
   }
   ```

4. **Block bots** (if needed):
   ```caddy
   @bots {
       header User-Agent *bot*
       header User-Agent *crawler*
   }
   respond @bots 403
   ```

## 📚 Further Reading

- [Caddy Documentation](https://caddyserver.com/docs/)
- [Caddyfile Syntax](https://caddyserver.com/docs/caddyfile)
- [Reverse Proxy Guide](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy)
- [Automatic HTTPS](https://caddyserver.com/docs/automatic-https)
