# Локальная проверка и деплой на сервер

## 1. Локальная проверка (полный пересбор и тест)

Используйте эти команды из корня репозитория (`n8n_deploy_example`).

### 1.1 Подготовка

```bash
# Перейти в корень проекта
cd /home/leemour/Projects/AI/AgentsCourse/n8n_deploy_example

# Убедиться, что .env есть и заполнен (в т.ч. EVOLUTION_DB_*, LANGFUSE_DB_*)
cp -n .env.example .env
# Отредактируйте .env: пароли, POSTGRES_*, EVOLUTION_DB_*, LANGFUSE_DB_*

# Скрипт инициализации БД должен быть исполняемым
chmod +x scripts/db/init-dbs.sh
```

### 1.2 Остановить старые контейнеры и (при необходимости) очистить данные Postgres

Чтобы **заново выполнить init-dbs.sh** (создание отдельных пользователей и БД для Evolution и Langfuse), том Postgres нужно удалить. Иначе скрипт при следующем запуске не выполнится (он работает только при первом создании БД).

**Вариант A — ⚠️ ОПАСНО!! чистая проверка (удаляются все данные в томах):**

```bash
# Остановить и удалить контейнеры и тома
docker compose -f docker-compose.dev.yaml --profile langfuse down -v

# Удалить только том Postgres (остальные тома сохранятся)
# Имя тома зависит от имени каталога проекта; посмотреть: docker volume ls | grep postgres
docker volume rm n8n_deploy_example_langfuse_postgres_data 2>/dev/null || true
```

**Вариант B — сохранить данные n8n, сбросить только Postgres:**

```bash
docker compose -f docker-compose.dev.yaml down
docker volume rm n8n_deploy_example_langfuse_postgres_data 2>/dev/null || true
# Тома n8n_storage (bind mount), qdrant_storage и т.д. не трогаем
```

### 1.3 Сборка и запуск

```bash
# Сборка образов без кэша (чтобы подтянуть актуальный Dockerfile и зависимости)
docker compose -f docker-compose.dev.yaml build --no-cache n8n-import

# Запуск без профиля Langfuse (только n8n, postgres, redis, qdrant, caddy, evolution-api, crawl4ai)
docker compose -f docker-compose.dev.yaml up -d

# Или с Langfuse (дольше: clickhouse, minio, langfuse-worker, langfuse-web)
# docker compose -f docker-compose.dev.yaml --profile langfuse up -d
```

Дождитесь, пока Postgres станет healthy и выполнится `init-dbs.sh` (только при первом создании тома). Обычно 10–30 секунд.

### 1.4 Проверка контейнеров

```bash
# Все сервисы в состоянии running (или completed для n8n-import)
docker compose -f docker-compose.dev.yaml ps

# Логи Postgres (должны быть строки про выполнение init-dbs)
docker compose -f docker-compose.dev.yaml logs postgres | tail -50

# Логи Evolution API (не должно быть "database does not exist")
docker compose -f docker-compose.dev.yaml logs evolution-api | tail -20
```

### 1.5 Проверка баз и пользователей в Postgres

```bash
# Список БД и пользователей (должны быть: n8n_production + evolution + langfuse)
docker compose -f docker-compose.dev.yaml exec postgres psql -U "${POSTGRES_USER:-n8n}" -d "${POSTGRES_DB:-n8n_production}" -c "\l"

# Проверка, что пользователи evolution и langfuse есть
docker compose -f docker-compose.dev.yaml exec postgres psql -U "${POSTGRES_USER:-n8n}" -d "${POSTGRES_DB:-n8n_production}" -c "\du"
```

Если в `.env` другие `POSTGRES_USER`/`POSTGRES_DB`, подставьте их или выполните без переменных (подставьте вручную):

```bash
docker compose -f docker-compose.dev.yaml exec postgres psql -U n8n -d n8n_production -c "\l"
docker compose -f docker-compose.dev.yaml exec postgres psql -U n8n -d n8n_production -c "\du"
```

### 1.6 Проверка сервисов по HTTP

```bash
# Evolution API (должен ответить 200 или 401 без "database" ошибки)
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/

# n8n через Caddy (если в .env есть N8N_HOSTNAME и Caddy проксирует) или напрямую, если проброшен порт
# Пример: запрос к UI
curl -s -o /dev/null -w "%{http_code}" http://localhost:80/   # или https://localhost при наличии сертификата
```

При необходимости проверьте n8n изнутри сети:

```bash
docker compose -f docker-compose.dev.yaml exec n8n wget -qO- -S http://localhost:5678 2>&1 | head -5
```

### 1.7 Остановка после теста

```bash
docker compose -f docker-compose.dev.yaml down
# С томами (полная очистка):
# docker compose -f docker-compose.dev.yaml down -v
```

---

## 2. Деплой на сервер (старые контейнеры, один пользователь Postgres)

На сервере уже крутятся старые контейнеры: один Postgres без раздельных пользователей, другой docker-compose/образы для n8n. Ниже — пошаговый переход на новую схему (отдельные БД и пользователи для n8n, Evolution, Langfuse).

### 2.1 Подготовка конфигов локально

В репозитории деплой идёт по Capistrano: код клонируется в `releases/<timestamp>`, в `current` — симлинк на последний релиз. Конфиги лежат в **shared**: `.env` и при необходимости `Caddyfile` копируются из **локальных** `ansible/configs/`.

1. **Добавить в `ansible/configs/production.env` и `ansible/configs/staging.env`** переменные для отдельных БД (скопировать из `.env.example` и подставить свои пароли):

   ```bash
   # Evolution API (отдельный пользователь и БД)
   EVOLUTION_DB_USER=evolution_user
   EVOLUTION_DB_PASSWORD=<надёжный_пароль>
   EVOLUTION_DB_NAME=evolution

   # Langfuse (если используете профиль langfuse)
   LANGFUSE_DB_USER=langfuse_user
   LANGFUSE_DB_PASSWORD=<надёжный_пароль>
   LANGFUSE_DB_NAME=langfuse
   ```

2. Убедиться, что в этих же файлах заданы:
   - `POSTGRES_HOST=postgres`
   - `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` — только для n8n.
   - **На сервере:** `N8N_DATA_PATH=/mnt/data/n8n` (данные БД и сервисов на Hetzner volume; Ansible создаёт подкаталоги при деплое).

### 2.2 Важно: Postgres на сервере уже с данными

Скрипт **`init-dbs.sh`** выполняется только при **первом** создании тома Postgres (пустой каталог данных). Если на сервере уже есть работающий том с данными, скрипт при следующем запуске не выполнится, и БД `evolution`/`langfuse` и пользователи не появятся.

Возможны два пути.

---

#### Вариант A: Миграция без потери данных (рекомендуется)

Оставить существующий том Postgres и вручную создать БД и пользователей.

1. **Бэкап БД n8n** (на сервере или с локальной машины через Ansible):

   ```bash
   ssh deploy@<server> "cd /srv/www/n8n/current && docker compose exec -T postgres pg_dump -U <postgres_user> <postgres_db> > /tmp/n8n_backup_$(date +%Y%m%d).sql"
   ```

   Или через ваш существующий backup-скрипт из репозитория.

2. **После деплоя** (см. п. 2.4) зайти на сервер и один раз выполнить в контейнере Postgres создание пользователей и БД. Подставьте значения из вашего `.env` (пароли экранируйте: одиночная кавычка в пароле → две одиночные `''`).

   ```bash
   ssh deploy@<server>
   cd /srv/www/n8n/current   # или ваш apps_dir/current

   # Загрузить переменные из .env (если есть)
   set -a; [ -f .env ] && source .env; set +a

   # Evolution API: пользователь и БД
   docker compose exec -T postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "CREATE USER ${EVOLUTION_DB_USER:-evolution_user} WITH PASSWORD '${EVOLUTION_DB_PASSWORD}';"
   docker compose exec -T postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "CREATE DATABASE ${EVOLUTION_DB_NAME:-evolution};"
   docker compose exec -T postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "GRANT ALL PRIVILEGES ON DATABASE ${EVOLUTION_DB_NAME:-evolution} TO ${EVOLUTION_DB_USER:-evolution_user};"
   docker compose exec -T postgres psql -U "${POSTGRES_USER}" -d "${EVOLUTION_DB_NAME:-evolution}" -c "GRANT ALL ON SCHEMA public TO ${EVOLUTION_DB_USER:-evolution_user};"

   # Langfuse: пользователь и БД
   docker compose exec -T postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "CREATE USER ${LANGFUSE_DB_USER:-langfuse_user} WITH PASSWORD '${LANGFUSE_DB_PASSWORD}';"
   docker compose exec -T postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "CREATE DATABASE ${LANGFUSE_DB_NAME:-langfuse};"
   docker compose exec -T postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "GRANT ALL PRIVILEGES ON DATABASE ${LANGFUSE_DB_NAME:-langfuse} TO ${LANGFUSE_DB_USER:-langfuse_user};"
   docker compose exec -T postgres psql -U "${POSTGRES_USER}" -d "${LANGFUSE_DB_NAME:-langfuse}" -c "GRANT ALL ON SCHEMA public TO ${LANGFUSE_DB_USER:-langfuse_user};"
   ```

   Если какой-то объект уже есть (например, после повторного запуска), команды могут вернуть ошибку «already exists» — тогда их можно пропустить.

3. Перезапустить только Evolution API и Langfuse (если используете), чтобы они подхватили новые БД:

   ```bash
   docker compose restart evolution-api
   docker compose --profile langfuse restart langfuse-worker langfuse-web
   ```

---

#### Вариант B: Чистый старт Postgres (потеря данных в БД)

Если можно потерять текущие данные Postgres (n8n, evolution, langfuse):

1. На сервере после деплоя остановить стек и удалить том Postgres:

   ```bash
   cd /srv/www/n8n/current   # или ваш apps_dir/current
   docker compose down
   docker volume ls | grep postgres
   docker volume rm <имя_тона_postgres>
   ```

2. Запустить снова: при первом старте Postgres выполнится `init-dbs.sh`, создадутся все БД и пользователи.

3. Восстановить данные n8n из бэкапа (если делали в п. 2.2 вариант A):

   ```bash
   docker compose up -d postgres
   # дождаться healthy
   cat /path/to/n8n_backup_*.sql | docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"
   docker compose up -d
   ```

### 2.3 Первоначальная настройка сервера (один раз)

Перед первым деплоем нужно запустить `server-setup.sh`. Он создаёт:
- системные каталоги (`/srv/www/n8n_production`, `/mnt/data/backups/...`)
- каталоги данных на Hetzner volume (`/mnt/data/n8n/postgres`, `redis`, `qdrant` и т.д.) с правильными владельцами для контейнеров
- Docker-сети (`n8n-network`, `n8n_default`)

Требует sudo (запрашивает пароль пользователя `kulibin`):

```bash
cd /home/leemour/Projects/AI/AgentsCourse/n8n_deploy_example/ansible
./server-setup.sh production
```

Этот скрипт безопасно запустить повторно — все задачи идемпотентны.

### 2.4 Запуск деплоя (Capistrano)

После настройки сервера все последующие деплои выполняются без sudo:

```bash
cd /home/leemour/Projects/AI/AgentsCourse/n8n_deploy_example/ansible

# Обычный деплой (быстро: образы не перекачиваются и не пересобираются)
./deploy-capistrano.sh production

# После обновления образов или Dockerfile n8n — подтянуть образы и пересобрать:
./deploy-capistrano.sh production -e force_pull_build=true
```

Что делает playbook:
- клонирует репозиторий в `releases/<timestamp>`;
- копирует из `configs/production.env` / `configs/staging.env` в `shared/.env`;
- делает симлинк `current` на новый релиз;
- останавливает старые контейнеры (`docker compose down` в `current`);
- поднимает новые (`docker compose up` из нового `current`);
- хранит 5 последних релизов, старые удаляет.

Используется **compose-файл из репозитория** (`docker-compose.yaml`).

**Первый деплой с данными на Hetzner volume (перенос существующей БД):**

Если раньше Postgres писал в именованный том Docker, при первом переходе на `N8N_DATA_PATH=/mnt/data/n8n` новый каталог будет пустой. Чтобы перенести данные один раз:

```bash
# Узнать имя тома на сервере
ssh -p 25222 deploy@<server> "docker volume ls | grep postgres"

# Деплой с миграцией (подставьте имя тома из вывода выше)
./deploy-capistrano.sh production -e migrate_postgres_to_hetzner=true -e postgres_old_volume_name=current_langfuse_postgres_data
```

### 2.5 После деплоя

1. Проверить, что контейнеры поднялись:
   ```bash
   ssh deploy@<server> "cd /srv/www/n8n/current && docker compose ps"
   ```

2. Если выбирали **вариант A (миграция)** — выполнить ручное создание БД/пользователей (см. п. 2.2, вариант A) и перезапуск evolution-api (и langfuse при необходимости).

3. Проверить логи:
   ```bash
   ssh deploy@<server> "cd /srv/www/n8n/current && docker compose logs postgres --tail 30"
   ssh deploy@<server> "cd /srv/www/n8n/current && docker compose logs evolution-api --tail 30"
   ```

4. Проверить доступ к n8n и Evolution API по домену/портам (как настроено в Caddy/прокси).

---

## 3. Краткая шпаргалка команд

| Задача | Команда |
|--------|--------|
| Локально: полная очистка и запуск | `docker compose -f docker-compose.dev.yaml down -v` → `docker compose -f docker-compose.dev.yaml build --no-cache n8n-import` → `docker compose -f docker-compose.dev.yaml up -d` |
| Локально: проверка БД и пользователей | `docker compose -f docker-compose.dev.yaml exec postgres psql -U n8n -d n8n_production -c "\l"` и `-c "\du"` |
| Сервер: первоначальная настройка (один раз) | `./ansible/server-setup.sh production` |
| Сервер: деплой | `./ansible/deploy-capistrano.sh production` |
| Сервер: деплой с пересборкой образов | `./ansible/deploy-capistrano.sh production -e force_pull_build=true` |
| Сервер: после деплоя — миграция БД вручную | Подключиться по SSH и выполнить в контейнере postgres `CREATE USER`/`CREATE DATABASE`/`GRANT` как в п. 2.2 вариант A |

Подробности по переменным и секретам — в [SETUP.md](SETUP.md).
