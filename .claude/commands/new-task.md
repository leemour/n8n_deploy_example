Scaffold a new Ansible task file for this project.

Follow these steps:

1. **Ask the user** (if not specified in $ARGUMENTS):
   - What is the task file name? (e.g., `monitoring-setup`)
   - What does this task do? (brief description)
   - Does it need to run as a specific user / require become: yes?
   - Which playbook should include it? (deploy.yml, deploy-capistrano.yml, server-setup.yml, or standalone)

2. **Create the file** at `ansible/tasks/{name}.yml` using this standard boilerplate:

```yaml
---
# {description}
# Included from: playbooks/{playbook}.yml

- name: {First meaningful task}
  # task here
```

Conventions to follow:
- Use `community.docker.docker_compose_v2` for Docker operations (NOT `docker_compose`)
- Use `ansible.builtin.*` fully-qualified module names
- Group related tasks with `block:` and add `rescue:` for critical operations
- Use variables from `group_vars/` — don't hardcode environment-specific values
- Add `tags:` to tasks that users might want to run selectively
- Use `{{ apps_dir }}`, `{{ proxy_dir }}`, `{{ backups_dir }}` path variables (defined in `all.yml`)
- Template files go in `ansible/templates/` with `.j2` extension

3. **If the task needs a playbook include**, add the `include_tasks` line to the appropriate playbook in `ansible/playbooks/`.

4. **Show the user** what was created and how to test it:
   ```bash
   # Dry run
   ansible-playbook -i inventory/hosts.yml playbooks/{playbook}.yml --limit staging --check
   # Run for real
   ansible-playbook -i inventory/hosts.yml playbooks/{playbook}.yml --limit staging
   ```
