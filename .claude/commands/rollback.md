Roll back the n8n deployment to the previous release.

Follow these steps:

1. **Ask the user** which environment to roll back: `production` or `staging` (if not specified in $ARGUMENTS).

2. **Explain what rollback does**:
   - The Capistrano-style deployment keeps the last 5 releases in `/srv/www/n8n_{environment}/releases/`
   - Rollback stops the current services, switches the `current` symlink to the previous release, and restarts
   - The current (broken) release is NOT deleted — it remains in releases/ for inspection

3. **Show the rollback command** that will run:
   ```bash
   cd ansible && ./rollback.sh {environment}
   # or directly:
   ansible-playbook -i inventory/hosts.yml playbooks/rollback.yml --limit {environment}
   ```

4. **Warn and confirm** — this is a production operation. Ask the user:
   - "Are you sure you want to roll back {environment}? The current release will be deactivated."

5. **Only after explicit confirmation**, execute the rollback.

6. **After rollback**, recommend:
   - Check logs to confirm the previous version is healthy: `docker compose logs -f n8n`
   - Investigate the failed release before deleting it

Safety: NEVER execute rollback without explicit user confirmation. This affects live production traffic.
