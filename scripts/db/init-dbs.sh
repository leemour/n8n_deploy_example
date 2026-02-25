#!/bin/bash
set -e

# Creates databases and users for Evolution API and Langfuse.
# Uses env vars passed to the postgres container. Runs once on first start (docker-entrypoint-initdb.d).
# n8n uses POSTGRES_USER/POSTGRES_DB (created by the default postgres image).

# Escape single quotes for use in SQL: ' -> ''
escape_sql_string() { printf '%s' "$1" | sed "s/'/''/g"; }

EVO_PASS_SQL=$(escape_sql_string "${EVOLUTION_DB_PASSWORD}")
LANG_PASS_SQL=$(escape_sql_string "${LANGFUSE_DB_PASSWORD}")

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<EOSQL
-- Evolution API: dedicated user and database
CREATE USER ${EVOLUTION_DB_USER} WITH PASSWORD '${EVO_PASS_SQL}';
CREATE DATABASE ${EVOLUTION_DB_NAME};
GRANT ALL PRIVILEGES ON DATABASE ${EVOLUTION_DB_NAME} TO ${EVOLUTION_DB_USER};
\c ${EVOLUTION_DB_NAME}
GRANT ALL ON SCHEMA public TO ${EVOLUTION_DB_USER};

-- Langfuse: dedicated user and database
CREATE USER ${LANGFUSE_DB_USER} WITH PASSWORD '${LANG_PASS_SQL}';
CREATE DATABASE ${LANGFUSE_DB_NAME};
GRANT ALL PRIVILEGES ON DATABASE ${LANGFUSE_DB_NAME} TO ${LANGFUSE_DB_USER};
\c ${LANGFUSE_DB_NAME}
GRANT ALL ON SCHEMA public TO ${LANGFUSE_DB_USER};
EOSQL
