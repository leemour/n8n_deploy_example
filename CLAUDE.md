# N8N Production Deployment — Claude Instructions

## Project Overview
Real production system deploying n8n workflow automation to a Hetzner VPS (openorbit.pro).
Also serves as an AI Agents Course example demonstrating production-grade deployment patterns.

## Architecture
- **Reverse Proxy**: Global Caddy container, handles SSL via Let's Encrypt
- **n8n**: Main workflow engine + scalable worker replicas + Redis/Valkey queue
- **PostgreSQL**: Primary database on Hetzner volume at `/mnt/data`
- **Qdrant**: Vector DB for embeddings (production only)
- **Langfuse**: LLM observability (production only)
- **Deployment style**: Capistrano-style via Ansible — timestamped releases + symlinks
- **Networks**: `n8n-network` (10.20.0.0/24) shared, `default` bridge (10.25.0.0/24)

## Server
- Host: `142.132.239.135`, SSH port `25222`
- User: `deploy` (sudo not required for capistrano-style deployment)
- Sudo user: `kulibin`
- Domains: `openorbit.pro` (production), `staging.openorbit.pro` (staging)

## Key Local Paths
| Path | Purpose |
|------|---------|
| `docker-compose.yaml` | Main production compose file |
| `docker-compose.dev.yaml` | Local development compose |
| `.env.example` | Template for environment variables |
| `ansible/playbooks/` | Top-level Ansible playbooks |
| `ansible/tasks/` | Reusable task includes |
| `ansible/templates/` | Jinja2 templates (.j2) |
| `ansible/inventory/hosts.yml` | Server inventory |
| `ansible/inventory/group_vars/` | Per-environment variables |
| `ansible/handlers/main.yml` | Ansible handlers |
| `docs/` | All documentation guides |
| `scripts/` | Utility scripts (db, pgadmin, utils) |
| `n8n/` | Custom n8n Dockerfile + import scripts |

## Key Remote Paths (on server)
| Path | Purpose |
|------|---------|
| `/srv/www/n8n_production/releases/` | All releases (keep last 5) |
| `/srv/www/n8n_production/current` | Symlink → active release |
| `/srv/www/n8n_production/shared/` | Shared .env, Caddyfile, n8n_storage |
| `/srv/www/proxy/` | Global Caddy proxy |
| `/mnt/data/n8n/` | Persistent data (postgres, redis, qdrant…) |

---

## SAFETY RULES — ALWAYS FOLLOW

1. **NEVER** print or log full contents of:
   - `ansible/configs/production.env`
   - `ansible/configs/staging.env`
   - `ansible/vars/secrets.yml`
   - `.env` (local)
2. **NEVER** suggest committing secret files (`configs/*.env`, `vars/secrets.yml`, `.env`)
3. **ALWAYS CONFIRM** before suggesting any `ansible-playbook` command targeting production
4. **ALWAYS CONFIRM** before any destructive operation: rollback, volume deletion, network recreation, `docker system prune`
5. Do not bypass `.gitignore` — secrets must stay out of git
6. When editing `ansible/inventory/hosts.yml`, double-check you're not accidentally exposing IPs in docs

---

## Common Commands

### Deployment
```bash
# Capistrano-style (preferred — no sudo needed)
cd ansible && ./deploy-capistrano.sh production
cd ansible && ./deploy-capistrano.sh staging

# Pre-deploy validation first
cd ansible && ./pre-deploy-check.sh production

# Full deploy with vault (requires --ask-vault-pass + sudo)
cd ansible && ./deploy.sh production
```

### Rollback
```bash
cd ansible && ./rollback.sh production
```

### Direct Ansible
```bash
# From ansible/ directory
ansible-playbook -i inventory/hosts.yml playbooks/deploy-capistrano.yml --limit production
ansible-playbook -i inventory/hosts.yml playbooks/rollback.yml --limit production
```

### Docker (local dev)
```bash
docker compose up -d
docker compose -f docker-compose.dev.yaml up -d
docker compose logs -f n8n
docker compose ps
```

### Secrets generation
```bash
./scripts/utils/generate-secrets.sh
```

---

## Conventions & Patterns

- **Ansible module**: always use `community.docker.docker_compose_v2` (not v1 / `docker_compose`)
- **Templates**: Jinja2 `.j2` files in `ansible/templates/`, variables use `{{ var_name }}`
- **Variables**: snake_case; env-specific vars in `group_vars/{env}.yml`, globals in `group_vars/all.yml`
- **Environments**: always specify `--limit production` or `--limit staging` explicitly
- **Release naming**: Unix epoch timestamp (`{{ ansible_date_time.epoch }}`)
- **Release retention**: keep last 5 releases — handled in `tasks/n8n-capistrano-deploy.yml`
- **Caddy**: global proxy handles all SSL; routing defined in `templates/global-Caddyfile.j2`
- **Docker profiles**: Langfuse uses `profiles: [langfuse]` — only started when enabled

## Adding a New Service (checklist)
1. Add service block to `docker-compose.yaml` (and `docker-compose.dev.yaml` if needed)
2. Add hostname/feature vars to `inventory/group_vars/production.yml` and `staging.yml`
3. Add Caddy routing block to `ansible/templates/global-Caddyfile.j2`
4. Add required env vars to `.env.example` and `ansible/templates/n8n.env.j2`
5. Add data directory creation to `tasks/n8n-capistrano-deploy.yml` (Hetzner volume section)
6. Update `docs/SERVICE_CONNECTIONS.md` and `README.md`
