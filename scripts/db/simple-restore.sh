#!/bin/bash

# Простое восстановление n8n - только workflows и credentials
# Использование: ./simple-restore.sh <папка_с_бэкапом>
# Запускать из корня проекта (где есть .env и docker-compose)

set -e

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [ "$#" -ne 1 ]; then
    echo -e "${RED}❌ Ошибка: нужно указать папку с бэкапом${NC}"
    echo ""
    echo "Использование: $0 <папка_с_бэкапом>"
    echo "Пример: $0 n8n_simple_backup_2026-01-21_12-00-00"
    echo ""
    exit 1
fi

BACKUP_DIR="$1"

if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}❌ Папка $BACKUP_DIR не найдена!${NC}"
    exit 1
fi

echo -e "${GREEN}=== Восстановление n8n ===${NC}"
echo ""

# Проверяем наличие необходимых файлов
echo -e "${YELLOW}🔍 Проверка файлов...${NC}"
REQUIRED_FILES=("encryption_key.txt" "workflows.csv" "credentials.csv")
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$BACKUP_DIR/$file" ]; then
        echo -e "${RED}❌ Файл $file не найден в бэкапе!${NC}"
        exit 1
    fi
    echo -e "${GREEN}   ✅ $file${NC}"
done
echo ""

# ВАЖНОЕ ПРЕДУПРЕЖДЕНИЕ
echo -e "${YELLOW}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  ⚠️  ВНИМАНИЕ!                                     ║${NC}"
echo -e "${YELLOW}║                                                    ║${NC}"
echo -e "${YELLOW}║  Перед восстановлением убедитесь что:              ║${NC}"
echo -e "${YELLOW}║  1. N8N_ENCRYPTION_KEY в .env совпадает с бэкапом  ║${NC}"
echo -e "${YELLOW}║  2. n8n запущен и работает                         ║${NC}"
echo -e "${YELLOW}║  3. База данных доступна                           ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# Показываем ключ из бэкапа
echo -e "${YELLOW}🔑 Ключ шифрования из бэкапа:${NC}"
cat "$BACKUP_DIR/encryption_key.txt"
echo ""

# Показываем текущий ключ
echo -e "${YELLOW}🔑 Текущий ключ шифрования в .env:${NC}"
if [ -f ".env" ]; then
    grep "N8N_ENCRYPTION_KEY=" .env
else
    echo -e "${RED}❌ Файл .env не найден!${NC}"
    exit 1
fi
echo ""

read -p "Ключи совпадают? Продолжить? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${RED}❌ Восстановление отменено${NC}"
    echo ""
    echo -e "${YELLOW}Скопируйте ключ из $BACKUP_DIR/encryption_key.txt в ваш .env файл${NC}"
    exit 1
fi

# Читаем POSTGRES_* из .env без source (в .env могут быть значения с пробелами)
POSTGRES_USER=$(grep -E '^POSTGRES_USER=' .env | cut -d= -f2- | tr -d '\r' | sed -e "s/^['\"]//" -e "s/['\"]$//")
POSTGRES_DB=$(grep -E '^POSTGRES_DB=' .env | cut -d= -f2- | tr -d '\r' | sed -e "s/^['\"]//" -e "s/['\"]$//")

echo ""
echo -e "${GREEN}1️⃣  Копируем файлы в контейнер базы данных...${NC}"
docker cp "$BACKUP_DIR/workflows.csv" postgres:/tmp/
docker cp "$BACKUP_DIR/credentials.csv" postgres:/tmp/
docker cp "$BACKUP_DIR/users.csv" postgres:/tmp/
echo -e "${GREEN}   ✅ Файлы скопированы${NC}"

echo -e "${GREEN}2️⃣  Импортируем workflows...${NC}"
docker exec postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "\COPY workflow_entity FROM '/tmp/workflows.csv' WITH CSV HEADER;"
echo -e "${GREEN}   ✅ Workflows импортированы${NC}"

echo -e "${GREEN}3️⃣  Импортируем credentials...${NC}"
docker exec postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "\COPY credentials_entity FROM '/tmp/credentials.csv' WITH CSV HEADER;"
echo -e "${GREEN}   ✅ Credentials импортированы${NC}"

echo -e "${GREEN}4️⃣  Очистка временных файлов...${NC}"
docker exec postgres rm /tmp/workflows.csv /tmp/credentials.csv /tmp/users.csv
echo -e "${GREEN}   ✅ Очищено${NC}"

echo -e "${GREEN}5️⃣  Перезапуск n8n...${NC}"
docker compose restart n8n
echo -e "${GREEN}   ✅ n8n перезапущен${NC}"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ ВОССТАНОВЛЕНИЕ ЗАВЕРШЕНО!                      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Проверьте n8n в браузере:${NC}"
echo -e "http://localhost:5678"
echo ""
