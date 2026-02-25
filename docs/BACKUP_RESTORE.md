# Backup and restore for n8n (PostgreSQL)

This guide covers backing up and restoring n8n on your **remote server**. Ubuntu/Linux is the primary environment; Windows is supported for transferring files and optional local use.

---

## Quick reference

### On the server (Ubuntu / Linux)

Run these from the **deploy root** on the server (the directory that has `docker-compose` and `.env`; see [Compatibility with this repo's deployment](#compatibility-with-this-repos-deployment)).

**Backup (full):**
```bash
./scripts/db/backup-n8n.sh
```

**Backup (simple – DB + encryption key only):**
```bash
./scripts/db/simple-backup.sh
```

---

## End-to-end backup (example commands)

These are real commands used from a **local machine** to backup a remote n8n instance. Replace host, port, user, and paths with yours; adjust the archive filename to match the one produced by the script.

### Workflow A: Copy script → run on server → download archive

**1. Copy the backup script to the server**

```bash
# From project root on your machine (port 25222 in this example)
scp -P 25222 ./scripts/db/backup-n8n.sh deploy@ssh.openorbit.pro:/srv/www/n8n_production/current/scripts/db
```

**2. SSH to the server and run the script**

```bash
ssh -p 25222 deploy@ssh.openorbit.pro
cd /srv/www/n8n_production/current
./scripts/db/backup-n8n.sh
```

**3. Copy the archive back to your machine**

```bash
# Create local backups dir if needed: mkdir -p backups
scp -P 25222 deploy@ssh.openorbit.pro:/srv/www/n8n_production/current/n8n_backup_20260224_232947.tar.gz ./backups/n8n_backup_20260224_232947.tar.gz
```

Use the actual `n8n_backup_YYYYMMDD_HHMMSS.tar.gz` filename produced by the script in step 2.

### Workflow B: SSH tunnel + direct pg_dump

Use this when you want only a database dump (e.g. for inspection or one-off migration) without running the full backup script.

**1. SSH with port forwarding (DB on server is 5433 → local 5434)**

```bash
ssh -L 5434:localhost:5433 -p 25222 deploy@ssh.openorbit.pro
```

Leave this session open (or run the next commands in another terminal while the tunnel is up).

**2. Dump the database from your machine**

```bash
# In another terminal, from your machine
mkdir -p backups/20260225_003729
pg_dump -h localhost -p 5434 -U n8n -d n8n_production > backups/20260225_003729/pg_dump_direct.sql
```

This gives you a plain SQL dump only (no `.env`, `n8n_storage`, or encryption key). For full restore you still need the encryption key and any files from a full backup or the server.

---

## Using the backup locally

Use a downloaded backup to load data into your **local** database so you can inspect it (psql, pgAdmin) or run n8n locally and open workflows in the UI.

### Option 1: Full local restore (run n8n locally and see workflows)

From the **project root** (where `docker-compose.yaml` or `docker-compose.dev.yaml` and `scripts/` live):

1. **Put the backup archive in the project** (e.g. in `backups/`):

   ```bash
   mkdir -p backups
   # archive is e.g. backups/n8n_backup_20260224_232947.tar.gz
   ```

2. **Run the restore script.** It will extract the archive, restore `.env`, start Postgres, restore the DB, then start n8n (and other services). Confirm when prompted.

   ```bash
   ./scripts/db/restore-n8n.sh backups/n8n_backup_20260224_232947.tar.gz
   ```

3. **Open n8n** at `http://localhost:5678` and log in with the same user as on the server. Workflows and credentials will decrypt correctly because the backup’s `.env` (including `N8N_ENCRYPTION_KEY`) is restored.

If you use a different Compose file for local dev (e.g. `docker-compose.dev.yaml`), run restore from the same directory and ensure that file is the one Compose uses (e.g. set `COMPOSE_FILE` or run from a directory where that file is the default).

### Option 2: Load only the database (inspect with psql or a GUI)

Use this when you only want to query the data (e.g. with psql or pgAdmin) and don’t need to run n8n.

1. **Extract the backup archive:**

   ```bash
   cd /path/to/n8n_deploy_example
   tar -xzf backups/n8n_backup_20260224_232947.tar.gz
   # creates folder: n8n_backup_20260224_232947/
   ```

2. **Start Postgres** (and only Postgres) from the project:

   ```bash
   docker compose up -d postgres
   # wait until healthy, e.g. 5–10 seconds
   ```

3. **Read DB user and database name from the backup’s `.env`** (optional; they must match the running Postgres):

   ```bash
   grep -E '^POSTGRES_USER=|^POSTGRES_DB=' n8n_backup_20260224_232947/.env
   ```

4. **Restore the custom-format dump into the running Postgres:**

   ```bash
   docker cp n8n_backup_20260224_232947/n8n_database.dump postgres:/tmp/n8n_backup.dump
   docker exec -it postgres pg_restore -U n8n -d n8n_production --clean --if-exists /tmp/n8n_backup.dump
   docker exec postgres rm /tmp/n8n_backup.dump
   ```

   Replace `n8n` and `n8n_production` with `POSTGRES_USER` and `POSTGRES_DB` from the backup’s `.env` if different.

5. **Inspect the data:**

   ```bash
   docker exec -it postgres psql -U n8n -d n8n_production -c "\dt"
   # or connect with pgAdmin / DBeaver to localhost, port 5432 (or the port exposed by your compose)
   ```

### Option 3: You have a plain SQL dump (from Workflow B)

If you used the [SSH tunnel + pg_dump](#workflow-b-ssh-tunnel--direct-pg_dump) workflow, you have a `.sql` file, not a `.dump` file.

1. **Start Postgres** (and create the DB if your compose doesn’t create it):

   ```bash
   docker compose up -d postgres
   docker exec -it postgres psql -U n8n -c "CREATE DATABASE n8n_production;"   # only if needed
   ```

2. **Load the SQL dump:**

   ```bash
   docker exec -i postgres psql -U n8n -d n8n_production < backups/20260225_003729/pg_dump_direct.sql
   ```

3. **Inspect** as in Option 2 step 5. Note: without the same `N8N_ENCRYPTION_KEY` and n8n app, credentials in the DB will not decrypt in the UI; the raw data is still visible in the database.

---

## What is included in a backup

| Component        | Contents                               | Criticality   |
|-----------------|----------------------------------------|---------------|
| **Database**    | Workflows, credentials, executions, users | Critical      |
| **.env**        | N8N_ENCRYPTION_KEY and other variables | Critical      |
| **n8n_storage/**| SSH keys, files, configs, custom nodes | Important     |
| **shared/**     | Shared files between containers        | Optional      |
| **docker-compose** | Service configuration                | Important     |

---

## N8N_ENCRYPTION_KEY and password storage

### Why it matters

**N8N_ENCRYPTION_KEY must be the same on the old and new server.**

If you lose this key or change it, all stored credentials (passwords, API keys, tokens) cannot be decrypted.

### Store the key in password storage

- **Do not rely only on `.env` or backup archives** for the encryption key.
- Store **N8N_ENCRYPTION_KEY** in a password manager (e.g. 1Password, Bitwarden, KeePass, LastPass) as soon as you set it.
- On restore or new server setup, take the value from password storage and put it into `.env` (or your secrets mechanism) before first start.

Check the key on the server:

```bash
grep N8N_ENCRYPTION_KEY .env
```

---

## Detailed instructions (Ubuntu / Linux – primary)

### Prerequisites on the server

- Docker and Docker Compose
- SSH access
- Project deployed (directory with `docker-compose.yaml` and `.env`)

### Step 1: Backup on the (old) server

```bash
# 1. SSH to the server
ssh user@your-server

# 2. Go to project root (deploy directory)
cd /srv/www/n8n_production/current   # or your actual deploy path

# 3. Make scripts executable (once)
chmod +x scripts/db/backup-n8n.sh scripts/db/restore-n8n.sh
chmod +x scripts/db/simple-backup.sh scripts/db/simple-restore.sh

# 4. Create full backup
./scripts/db/backup-n8n.sh

# 5. Check result
ls -lh n8n_backup_*.tar.gz
```

Optional: store **N8N_ENCRYPTION_KEY** from `.env` in your password manager if not already done.

### Step 2: Optional – copy backup to another machine

**From Ubuntu/Linux to another Linux:**

```bash
scp user@server:/path/to/n8n_backup_TIMESTAMP.tar.gz ./
```

**From server to Windows:** see [From Windows](#from-windows) below.

### Step 3: Restore on the (new) server

```bash
# 1. SSH to the new server
ssh user@new-server

# 2. Install Docker if needed
sudo apt update
sudo apt install -y docker.io docker-compose-plugin git

# 3. Clone or copy project and place backup archive in project root
# e.g. mv ~/n8n_backup_20260121_120000.tar.gz /path/to/n8n_deploy_example/

# 4. Go to project root
cd /path/to/n8n_deploy_example

# 5. (Optional) Set N8N_ENCRYPTION_KEY in .env from password storage before restore
# If .env does not exist yet, restore will create it from the backup.

# 6. Run restore
chmod +x scripts/db/restore-n8n.sh
./scripts/db/restore-n8n.sh n8n_backup_20260121_120000.tar.gz

# 7. Verify
docker compose ps
docker compose logs -f n8n
```

### Step 4: Verify after restore

```bash
docker compose ps
docker compose logs -f n8n
# Open n8n in browser (e.g. http://your-server:5678)
# Check workflows and credentials
```

---

## From Windows

These steps are for **downloading** backups from the server and **uploading** them (e.g. to a new server) when you use a Windows PC. The actual backup and restore commands still run on Ubuntu/Linux.

### Download backup from server to Windows

**Option A: PSCP (PuTTY)**

```cmd
cd C:\Program Files\PuTTY
pscp user@server:/path/to/n8n_deploy_example/n8n_backup_20260121_120000.tar.gz C:\Downloads\
```

**Option B: WinSCP**

1. Open WinSCP and connect to the server.
2. Go to the project directory and find `n8n_backup_*.tar.gz`.
3. Drag the file to a local folder (e.g. `C:\Downloads`).

### Upload backup from Windows to server

**Option A: PSCP**

```cmd
cd C:\Program Files\PuTTY
pscp C:\Downloads\n8n_backup_20260121_120000.tar.gz user@new-server:/home/user/
```

**Option B: WinSCP**

1. Connect to the new server with WinSCP.
2. Upload the `.tar.gz` file to the desired path (e.g. project root).

Then on the server (Ubuntu):

```bash
cd /path/to/n8n_deploy_example
mv ~/n8n_backup_20260121_120000.tar.gz .
./scripts/db/restore-n8n.sh n8n_backup_20260121_120000.tar.gz
```

### N8N_ENCRYPTION_KEY on Windows

- When you first set up n8n or restore, get **N8N_ENCRYPTION_KEY** from your **password storage** (e.g. 1Password, Bitwarden).
- Put it into the server’s `.env` (via SSH and `nano`/`vim`, or by editing the file through WinSCP). Do not rely only on the backup archive for this value.

---

## Script overview

### backup-n8n.sh

- Full backup: PostgreSQL dump, `.env`, `n8n_storage`, `shared`, docker-compose files, image versions.
- Produces: `n8n_backup_YYYYMMDD_HHMMSS.tar.gz`

### simple-backup.sh

- Lightweight: encryption key, DB connection info, workflows/credentials/users as CSV.
- Produces: folder `n8n_simple_backup_*` (can be tar’d for transfer).

### restore-n8n.sh

- Restores from a full backup archive: extracts, restores `.env`, compose, storage, DB, then brings up services.

### simple-restore.sh

- Restores only workflows and credentials from a simple backup folder (same encryption key required).

---

## Troubleshooting

### Credentials do not decrypt

- **Cause:** Different or missing N8N_ENCRYPTION_KEY.
- **Fix:** Get the key from password storage (or from the original backup’s `encryption_key.txt` / `.env`) and set it in the server’s `.env`, then restart n8n:  
  `docker compose restart n8n`

### Database restore fails

- Check PostgreSQL version: `docker compose exec postgres psql --version`
- Align image version in `docker-compose` with the one used for the backup if needed.
- Try clean start:  
  `docker compose down -v` then `docker compose up -d postgres` and run restore again.

### n8n does not start

- Check logs: `docker compose logs n8n` and `docker compose logs postgres`
- Check port 5678, memory, and permissions on `n8n_storage`:  
  `sudo chown -R 1000:1000 n8n_storage/`

---

## Automated backups (Ubuntu)

Example cron for a daily backup at 03:00:

```bash
crontab -e
# Add:
0 3 * * * cd /path/to/n8n_deploy_example && ./scripts/db/backup-n8n.sh >> /var/log/n8n-backup.log 2>&1
```

Keep **N8N_ENCRYPTION_KEY** in password storage regardless of cron; the backup archive is an extra copy, not the single source of truth for the key.

---

## Migration checklist

- [ ] Full backup created on old server (`./scripts/db/backup-n8n.sh`)
- [ ] N8N_ENCRYPTION_KEY stored in password manager
- [ ] Backup downloaded (or copied) to new server
- [ ] New server has Docker and project files
- [ ] N8N_ENCRYPTION_KEY set in `.env` on new server (from password storage)
- [ ] Restore run (`./scripts/db/restore-n8n.sh …`)
- [ ] Containers up, n8n reachable, workflows and credentials checked
- [ ] Old server can be retired

---

**Version:** 1.1  
**Updated:** 2026-02
