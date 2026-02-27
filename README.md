# N8N Production Deployment

Production-ready n8n deployment with microservices architecture, automated deployment via Ansible, and SSL certificates management through Caddy.

## 🚀 Quick Start

```bash
# 1. Clone the repository
git clone git@github.com:leemour/n8n_deploy_example.git
cd n8n_deploy_example

# 2. Configure your environment
cp ansible/configs/production.env.example ansible/configs/production.env
nano ansible/configs/production.env  # Add your secrets

# 3. Update inventory with your server details
nano ansible/inventory/hosts.yml

# 4. Deploy to production
./ansible/deploy-capistrano.sh production
```

Your n8n will be available at `https://n8n.yourdomain.com` 🎉

## 📋 Features

- **Microservices Architecture** - n8n, PostgreSQL, Redis, Qdrant, Crawl4AI, Langfuse, pgAdmin, pgWeb
- **Database Management** - pgAdmin for PostgreSQL administration, pgWeb for quick database access
- **Automated Deployment** - Capistrano-style with Ansible (no vault passwords needed)
- **SSL Certificates** - Automatic Let's Encrypt via Caddy
- **Worker Queue System** - Scalable background job processing
- **Easy Rollback** - Keep last 5 releases, rollback with one command
- **Production Ready** - Auto-restart, health checks, resource limits

## 🏗️ Architecture

```
Internet
  ↓ HTTPS (443)
Global Caddy (Reverse Proxy)
  ├─→ n8n.yourdomain.com → n8n:5678
  ├─→ qdrant.yourdomain.com → qdrant:6333
  ├─→ langfuse.yourdomain.com → langfuse-web:3000
  ├─→ pgadmin.yourdomain.com → pgadmin:80
  └─→ pgweb.yourdomain.com → host:8081

Docker Network: n8n-network (shared)
  ├─ n8n (main application)
  ├─ n8n-worker (background jobs)
  ├─ postgres (database - exposed on 5433)
  ├─ redis (queue)
  ├─ qdrant (vector DB)
  ├─ crawl4ai (web scraping)
  ├─ langfuse (LLM monitoring)
  └─ pgadmin (database admin)
```

## 📚 Documentation

### Getting Started
- **[Deployment Guide](docs/DEPLOYMENT_GUIDE.md)** - Complete deployment walkthrough
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Detailed setup instructions

### Configuration
- **[Caddy Setup](docs/CADDY_SETUP.md)** - Reverse proxy and SSL configuration
- **[Service Connections](docs/SERVICE_CONNECTIONS.md)** - How to connect to all services (PostgreSQL, pgAdmin, Qdrant, etc.)
- **[Caddy Multiple Networks](docs/CADDY_MULTIPLE_NETWORKS.md)** - Configuring Caddy for multiple Docker networks
- **[N8N Microservices Guide](docs/N8N_MICROSERVICES_GUIDE.md)** - Detailed service configuration (Russian)
- **[N8N Custom Docker Image](docs/N8N_CUSTOM_IMAGE.md)** - Building custom n8n image with community nodes

### Troubleshooting
- **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)** - Common issues and solutions

## 🎯 Key Concepts

### Capistrano-Style Deployment

We use a **Capistrano-style deployment** approach:
- Code from git repository
- Config from local machine (no Ansible Vault needed)
- Timestamped releases in `/srv/www/n8n_production/releases/`
- Symlink `current` → latest release
- Keep last 5 releases for easy rollback

**Directory structure on server:**
```
/srv/www/n8n_production/
├── current → releases/1234567890/    # Symlink to latest
├── releases/
│   ├── 1234567890/                   # Latest
│   ├── 1234567880/
│   └── 1234567870/
└── shared/
    ├── .env                          # Persistent config
    ├── n8n_storage/                  # Persistent data
    └── backups/
```

### Container Naming

All containers use **explicit names** for reliability:
```yaml
services:
  n8n:
    container_name: n8n    # Simple, predictable name
```

This ensures:
- ✅ Consistent naming across restarts
- ✅ No network prefix confusion
- ✅ Works with both manual and automated deployments

## 🛠️ Common Operations

### Deploy New Version
```bash
./ansible/deploy-capistrano.sh production
```

### Rollback to Previous Release
```bash
./ansible/rollback.sh production
```

### View Logs
```bash
ssh -p 25222 deploy@yourserver \
  'cd /srv/www/n8n_production/current && docker compose logs -f n8n'
```

### Restart Services
```bash
ssh -p 25222 deploy@yourserver \
  'cd /srv/www/n8n_production/current && docker compose restart'
```

### Check Status
```bash
ssh -p 25222 deploy@yourserver 'docker ps'
```

## 🔧 Configuration

### Environment Variables

Edit `ansible/configs/production.env`:

```bash
# N8N Configuration
N8N_ENCRYPTION_KEY=your-32-char-key
N8N_USER_MANAGEMENT_JWT_SECRET=your-jwt-secret

# Database
POSTGRES_PASSWORD=your-postgres-password
PGADMIN_DEFAULT_EMAIL=admin@yourdomain.com
PGADMIN_DEFAULT_PASSWORD=your-pgadmin-password

# Optional Services
QDRANT_API_KEY=your-qdrant-key
LANGFUSE_SALT=your-langfuse-salt
```

### Server Inventory

Edit `ansible/inventory/hosts.yml`:

```yaml
production:
  hosts:
    n8n-production:
      ansible_host: YOUR_SERVER_IP
      ansible_port: 25222
      ansible_user: deploy
      server_domain: yourdomain.com
      letsencrypt_email: admin@yourdomain.com
```

### Service Configuration

Edit `ansible/group_vars/production.yml`:

```yaml
n8n:
  hostname: "n8n.yourdomain.com"
  worker_count: 2                    # Number of workers
  enable_langfuse: true              # LLM monitoring
  enable_qdrant: true                # Vector database
  enable_crawl4ai: true              # Web scraping
```

## 🧪 Testing After Deployment

```bash
# Test SSL and accessibility
curl -I https://n8n.yourdomain.com

# Test server restart behavior
ssh -p 25222 deploy@yourserver 'sudo systemctl restart docker'
sleep 10
curl -I https://n8n.yourdomain.com

# Check logs for errors
ssh -p 25222 deploy@yourserver 'docker logs global-caddy --tail=30'
```

## 🏥 Health Checks

All services have health checks:
- **PostgreSQL** - `pg_isready` every 3 seconds
- **Redis** - `redis-cli ping` every 3 seconds
- **Crawl4AI** - HTTP check
- **Langfuse dependencies** - Built-in checks

## 📊 Resource Limits

Configured in `ansible/group_vars/production.yml`:

```yaml
resource_limits:
  n8n_memory: "2g"
  postgres_memory: "1g"
  redis_memory: "512m"
  crawl4ai_memory: "4g"
```

## 🔒 Security

- **SSL/TLS** - Automatic Let's Encrypt certificates via Caddy
- **Firewall** - Only ports 80, 443, and SSH open
- **Secrets** - Stored in local `.env` files (not in git)
- **Container Isolation** - Dropped capabilities, read-only filesystems where possible

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📝 License

MIT License - See LICENSE file for details

## 🆘 Support

- **Issues** - GitHub issues for bugs and feature requests
- **Documentation** - Check the `docs/` folder
- **Examples** - See `ansible/configs/` for configuration examples

## 🎓 Learn More

- [N8N Documentation](https://docs.n8n.io/)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Ansible Documentation](https://docs.ansible.com/)
