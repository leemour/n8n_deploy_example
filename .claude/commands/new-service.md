Add a new Docker service to the n8n stack — both locally and for Ansible-managed production deployment.

Follow these steps:

1. **Gather requirements** from the user (if not specified in $ARGUMENTS):
   - Service name (e.g., `flowise`, `meilisearch`)
   - Docker image and version
   - Does it need a web UI exposed via Caddy? (needs hostname + SSL)
   - Does it need persistent data storage? (needs volume on Hetzner path)
   - Production only, or also staging?
   - Any environment variables / secrets needed?

2. **Make changes in this order**:

   a. **`docker-compose.yaml`** — Add the service block:
      - Use the `n8n-network` external network
      - Add restart policy, health check if applicable
      - Mount data to `/mnt/data/n8n/{service-name}/` for persistent storage
      - Add memory limit via `deploy.resources.limits`

   b. **`docker-compose.dev.yaml`** (if applicable) — Add lighter dev variant

   c. **`.env.example`** — Add any new environment variables with placeholder values and comments

   d. **`ansible/inventory/group_vars/production.yml`** — Add hostname and feature flag vars

   e. **`ansible/inventory/group_vars/staging.yml`** — Add vars (disable if production-only)

   f. **`ansible/templates/global-Caddyfile.j2`** — Add routing block:
      ```
      {$SERVICE_HOSTNAME} {
        reverse_proxy {service-name}:{port}
      }
      ```

   g. **`ansible/templates/n8n.env.j2`** — Add templated env vars for the service

   h. **`ansible/tasks/n8n-capistrano-deploy.yml`** — Add data directory creation in the Hetzner volume setup section:
      ```yaml
      - name: Create {service} data directory
        ansible.builtin.file:
          path: "{{ n8n_data_path }}/{service-name}"
          state: directory
          mode: '0755'
      ```

   i. **`docs/SERVICE_CONNECTIONS.md`** — Document how to access and connect to the service

   j. **`README.md`** — Add service to the architecture overview if significant

3. **Show a summary** of all changes made and remind the user to:
   - Add any real secret values to `ansible/configs/production.env` (NOT committed to git)
   - Test locally with `docker compose up -d {service-name}`
   - Deploy to staging first: `cd ansible && ./deploy-capistrano.sh staging`

Safety: Never add real credentials or secrets to `.env.example` — use placeholder values only.
