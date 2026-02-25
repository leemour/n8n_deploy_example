# Настройка окружения: зависимости, сеть, секреты

Краткая инструкция, как поднять стек локально и на сервере после правок в `docker-compose` и Postgres.

## Зависимости

- **Docker** и **Docker Compose** (v2+).
- Локально: скопировать `.env.example` в `.env` и заполнить секреты.
- На сервере: `.env` создаётся Ansible из шаблонов (см. [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)).

## Сеть

- В `docker-compose.yaml` (prod) используется внешняя сеть `n8n-network` для n8n, qdrant, pgadmin. Создаётся один раз:
  ```bash
  docker network create n8n-network
  ```
- В `docker-compose.dev.yaml` все сервисы в одной default-сети, внешняя сеть не нужна.
- Имя хоста БД в контейнерах всегда **`postgres`** (имя сервиса). В `.env` для Docker должен быть `POSTGRES_HOST=postgres`.

## Секреты и переменные (.env)

Обязательно задать (см. `.env.example`):

| Переменная | Назначение |
|------------|------------|
| `N8N_ENCRYPTION_KEY` | Ключ шифрования n8n (длинная случайная строка) |
| `N8N_USER_MANAGEMENT_JWT_SECRET` | JWT для управления пользователями n8n |
| `POSTGRES_HOST` | Для Docker: **`postgres`** |
| `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` | БД и пользователь только для **n8n** |
| `EVOLUTION_DB_USER`, `EVOLUTION_DB_PASSWORD`, `EVOLUTION_DB_NAME` | Пользователь и БД только для **Evolution API** (создаются в `init-dbs.sh`) |
| `LANGFUSE_DB_USER`, `LANGFUSE_DB_PASSWORD`, `LANGFUSE_DB_NAME` | Пользователь и БД только для **Langfuse** (создаются в `init-dbs.sh`; нужны при `--profile langfuse`) |
| `QDRANT_API_KEY` | API-ключ Qdrant |
| `PGADMIN_DEFAULT_PASSWORD` | Пароль pgAdmin |

Для профиля **Langfuse** (профиль `langfuse`):

- `LANGFUSE_SALT`, `ENCRYPTION_KEY`, `NEXTAUTH_SECRET` (например: `openssl rand -hex 32`)
- `CLICKHOUSE_PASSWORD`, `MINIO_ROOT_PASSWORD`
- `LANGFUSE_INIT_*` — по желанию для первого пользователя и проекта

Evolution API: ключ API задаётся в compose как `AUTHENTICATION_API_KEY` (на проде лучше вынести в `.env`).

## Инициализация Postgres (несколько БД в одном контейнере)

В одном контейнере Postgres поднимаются три отдельные БД с разными пользователями:

- **n8n**: БД и пользователь из `POSTGRES_DB` / `POSTGRES_USER` / `POSTGRES_PASSWORD` (создаются образом postgres по умолчанию).
- **Evolution API**: БД и пользователь из `EVOLUTION_DB_*` (создаются скриптом `init-dbs.sh`).
- **Langfuse** (при профиле `langfuse`): БД и пользователь из `LANGFUSE_DB_*` (создаются скриптом `init-dbs.sh`).

Скрипт **`init-dbs.sh`** выполняется при первом запуске тома Postgres (монтируется в `/docker-entrypoint-initdb.d/`). Пароли и имена пользователей/БД берутся из переменных окружения контейнера postgres (из `.env`).

Перед первым запуском сделайте скрипт исполняемым:

```bash
chmod +x init-dbs.sh
```

Если том Postgres уже был создан без этого скрипта, нужно либо удалить том и запустить заново, либо вручную создать БД и пользователя в psql.

## Minio (профиль Langfuse)

Healthcheck использует `mc alias set ... && mc ready local`, чтобы не зависеть от предустановленного alias. В новых образах MinIO нет `curl`/`wget`, поэтому используется только `mc`.

## Crawl4Ai

В обоих compose-файлах для сервиса `crawl4ai` указан `env_file: - .env`. Если переменные не нужны, блок можно удалить; не оставляйте закомментированный `env_file`, чтобы не путать парсер YAML.

## Запуск локально

1. Создать `.env` из `.env.example`, выставить `POSTGRES_HOST=postgres` и все обязательные секреты.
2. `chmod +x init-dbs.sh`
3. Без Langfuse:
   ```bash
   docker compose -f docker-compose.dev.yaml up -d
   ```
4. С Langfuse:
   ```bash
   docker compose -f docker-compose.dev.yaml --profile langfuse up -d
   ```

## Запуск на сервере (prod)

1. В prod используется `docker-compose.yaml` и внешняя сеть:
   ```bash
   docker network create n8n-network
   ```
2. `.env` на сервере формируется из Ansible-шаблонов (см. [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)); убедитесь, что в шаблоне для хоста БД указано имя сервиса **postgres**.
3. После деплоя контейнер Postgres при первом запуске выполнит `init-dbs.sh` и создаст БД и пользователей для Evolution API и Langfuse согласно переменным `EVOLUTION_DB_*` и `LANGFUSE_DB_*` в `.env`.

## Проверка после запуска

- n8n: порт 5678 (или через Caddy в dev).
- Evolution API: порт 8080.
- Postgres: порт 5433 (только в prod compose), внутри сети — 5432.
- Langfuse (при профиле `langfuse`): через Caddy по `LANGFUSE_HOSTNAME`.

Если Langfuse или Evolution API падают с ошибкой «database does not exist», проверьте, что при первом запуске Postgres был смонтирован `init-dbs.sh` и том данных создавался уже с этим скриптом.
