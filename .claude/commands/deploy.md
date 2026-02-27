Deploy the n8n stack to the target environment using the Capistrano-style Ansible workflow.

Follow these steps:

1. **Ask the user** which environment to deploy to: `production` or `staging` (if not specified in $ARGUMENTS).

2. **Read and show** the current state:
   - Check `ansible/pre-deploy-check.sh` exists and show its key checks
   - Remind the user to verify `ansible/configs/{environment}.env` is up to date
   - Check that `ansible/inventory/hosts.yml` has the correct host for the environment

3. **Show the deploy command** that will be run:
   ```bash
   cd ansible && ./pre-deploy-check.sh {environment}
   cd ansible && ./deploy-capistrano.sh {environment}
   ```

4. **Confirm with the user** before running anything that touches production.

5. **After confirmation**, run `pre-deploy-check.sh` first. If it passes, run `deploy-capistrano.sh`.

6. **After deploy**, show useful follow-up commands:
   - View logs: `docker compose logs -f n8n`
   - Check status: `docker compose ps`
   - Rollback if needed: `cd ansible && ./rollback.sh {environment}`

Safety: NEVER run ansible-playbook commands targeting production without explicit user confirmation.
