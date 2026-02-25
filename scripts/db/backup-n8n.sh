#!/bin/bash

# Скрипт для полного бэкапа n8n
# Использование: ./backup-n8n.sh
# Запускать из корня деплоя (где есть .env и docker-compose):
#   - Capistrano: apps_dir/current (например /srv/www/n8n/current)
#   - Или каталог с docker-compose.yaml / docker-compose.yml и .env

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Проверка: запуск из каталога с .env и compose
if [ ! -f ".env" ]; then
    echo -e "${RED}❌ Ошибка: в текущем каталоге нет .env. Запускайте из корня деплоя (current или каталог с compose).${NC}"
    exit 1
fi
if [ ! -f "docker-compose.yaml" ] && [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}❌ Ошибка: не найден docker-compose.yaml или docker-compose.yml. Запускайте из корня деплоя.${NC}"
    exit 1
fi

echo -e "${GREEN}📦 === Начало бэкапа n8n ===${NC}"

# Создаем директорию для бэкапа с датой
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="n8n_backup_${BACKUP_DATE}"
mkdir -p "$BACKUP_DIR"

echo -e "${YELLOW}📁 Директория бэкапа: $BACKUP_DIR${NC}"

# 1. Бэкап базы данных (читаем только POSTGRES_* из .env, без source — в .env могут быть значения с пробелами)
echo -e "${GREEN}🗄️  1. Создание дампа базы данных...${NC}"
POSTGRES_USER=$(grep -E '^POSTGRES_USER=' .env | cut -d= -f2- | tr -d '\r' | sed -e "s/^['\"]//" -e "s/['\"]$//")
POSTGRES_DB=$(grep -E '^POSTGRES_DB=' .env | cut -d= -f2- | tr -d '\r' | sed -e "s/^['\"]//" -e "s/['\"]$//")
docker exec postgres pg_dump -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -F c -f /tmp/n8n_backup.dump
docker cp postgres:/tmp/n8n_backup.dump "$BACKUP_DIR/n8n_database.dump"
docker exec postgres rm /tmp/n8n_backup.dump
echo -e "${GREEN}   ✅ База данных сохранена${NC}"

# 2. Бэкап .env файла
echo -e "${GREEN}📄 2. Копирование .env файла...${NC}"
cp .env "$BACKUP_DIR/.env"
echo -e "${GREEN}   ✅ .env файл сохранен${NC}"

# 3. Бэкап n8n_storage (если симлинк — архивируется содержимое)
echo -e "${GREEN}📂 3. Архивирование n8n_storage...${NC}"
if [ -e "n8n_storage" ]; then
    tar -czf "$BACKUP_DIR/n8n_storage.tar.gz" \
        --exclude='n8n_storage/.cache' \
        --exclude='n8n_storage/n8nEventLog.log' \
        n8n_storage/
    echo -e "${GREEN}   ✅ n8n_storage заархивирован${NC}"
else
    echo -e "${YELLOW}   ⏭️  n8n_storage не найден, пропускаем${NC}"
fi

# 4. Бэкап shared директории (если есть)
if [ -d "shared" ]; then
    echo -e "${GREEN}📂 4. Архивирование shared директории...${NC}"
    tar -czf "$BACKUP_DIR/shared.tar.gz" shared/
    echo -e "${GREEN}   ✅ shared заархивирован${NC}"
else
    echo -e "${YELLOW}⏭️  4. Директория shared не найдена, пропускаем${NC}"
fi

# 5. Копирование docker-compose файлов (поддержка .yaml и .yml)
echo -e "${GREEN}🐳 5. Копирование docker-compose файлов...${NC}"
if [ -f "docker-compose.yaml" ]; then
    cp docker-compose.yaml "$BACKUP_DIR/docker-compose.yaml"
elif [ -f "docker-compose.yml" ]; then
    cp docker-compose.yml "$BACKUP_DIR/docker-compose.yaml"
fi
if [ -f "docker-compose.dev.yaml" ]; then
    cp docker-compose.dev.yaml "$BACKUP_DIR/"
fi
# init-dbs.sh нужен для восстановления (Evolution/Langfuse и т.д.)
if [ -f "scripts/db/init-dbs.sh" ]; then
    cp scripts/db/init-dbs.sh "$BACKUP_DIR/init-dbs.sh"
elif [ -f "init-dbs.sh" ]; then
    cp init-dbs.sh "$BACKUP_DIR/init-dbs.sh"
fi
echo -e "${GREEN}   ✅ Docker-compose и скрипты сохранены${NC}"

# 6. Сохранение версий образов
echo -e "${GREEN}🐳 6. Сохранение версий Docker образов...${NC}"
docker compose images > "$BACKUP_DIR/docker_images_versions.txt"
echo -e "${GREEN}   ✅ Версии образов сохранены${NC}"

# 7. Создание архива всего бэкапа
echo -e "${GREEN}📦 7. Создание финального архива...${NC}"
tar -czf "${BACKUP_DIR}.tar.gz" "$BACKUP_DIR/"
BACKUP_SIZE=$(du -h "${BACKUP_DIR}.tar.gz" | cut -f1)
echo -e "${GREEN}   ✅ Архив создан: ${BACKUP_DIR}.tar.gz (${BACKUP_SIZE})${NC}"

# 8. Создание информационного файла
echo -e "${GREEN}📋 8. Создание README...${NC}"
cat > "$BACKUP_DIR/RESTORE_README.md" << 'EOF'
# Инструкция по восстановлению n8n

## Что содержится в бэкапе:
- `n8n_database.dump` - полный дамп PostgreSQL (workflows, credentials, executions)
- `.env` - переменные окружения (включая N8N_ENCRYPTION_KEY!)
- `n8n_storage.tar.gz` - пользовательские файлы, SSH ключи, конфиги
- `shared.tar.gz` - общая директория (если есть)
- `docker-compose.yaml` - конфигурация Docker
- `docker_images_versions.txt` - версии используемых образов

## ⚠️ ВАЖНО:
**N8N_ENCRYPTION_KEY** из файла .env ОБЯЗАТЕЛЬНО должен быть таким же на новом сервере!
Без него credentials не расшифруются! Храните ключ в надёжном password storage (1Password, Bitwarden и т.д.).

## Восстановление на новом сервере:

См. скрипт restore-n8n.sh
EOF
echo -e "${GREEN}   ✅ README создан${NC}"

# Удаляем временную директорию (оставляем только архив)
rm -rf "$BACKUP_DIR"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ БЭКАП УСПЕШНО ЗАВЕРШЕН!                       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "📦 Архив: ${YELLOW}${BACKUP_DIR}.tar.gz${NC} (${BACKUP_SIZE})"
echo ""
echo -e "${YELLOW}💡 Скачать на Windows:${NC}"
echo -e "pscp user@server:$(pwd)/${BACKUP_DIR}.tar.gz C:\\Downloads\\"
echo ""
