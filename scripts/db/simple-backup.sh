#!/bin/bash

# Простой бэкап n8n - только workflows, credentials и ключ шифрования
# Использование: ./simple-backup.sh
# Запускать из корня проекта (где есть .env и docker-compose)

set -e

# Цвета для красивого вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Простой бэкап n8n ===${NC}"
echo ""

# Создаем папку для бэкапа с датой
DATE=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_NAME="n8n_simple_backup_${DATE}"
mkdir -p "$BACKUP_NAME"

echo -e "${GREEN}📁 Создана папка: $BACKUP_NAME${NC}"
echo ""

# 1. Получаем ключ шифрования из .env
echo -e "${GREEN}1️⃣  Сохраняем ключ шифрования...${NC}"
if [ -f ".env" ]; then
    grep "N8N_ENCRYPTION_KEY=" .env > "$BACKUP_NAME/encryption_key.txt"
    echo -e "${GREEN}   ✅ Ключ шифрования сохранен${NC}"
else
    echo -e "${YELLOW}   ⚠️  Файл .env не найден!${NC}"
fi

# 2. Сохраняем учетные данные для базы данных
echo -e "${GREEN}2️⃣  Сохраняем данные для подключения к базе...${NC}"
if [ -f ".env" ]; then
    grep "POSTGRES_" .env > "$BACKUP_NAME/database_info.txt"
    echo -e "${GREEN}   ✅ Данные базы сохранены${NC}"
else
    echo -e "${YELLOW}   ⚠️  Файл .env не найден!${NC}"
fi

# 3. Экспортируем workflows и credentials из базы данных
echo -e "${GREEN}3️⃣  Экспортируем workflows и credentials из базы данных...${NC}"

# Читаем POSTGRES_* из .env без source (в .env могут быть значения с пробелами)
POSTGRES_USER=$(grep -E '^POSTGRES_USER=' .env | cut -d= -f2- | tr -d '\r' | sed -e "s/^['\"]//" -e "s/['\"]$//")
POSTGRES_DB=$(grep -E '^POSTGRES_DB=' .env | cut -d= -f2- | tr -d '\r' | sed -e "s/^['\"]//" -e "s/['\"]$//")

# Создаем SQL скрипт для экспорта
cat > /tmp/export_n8n.sql << 'EOF'
-- Экспорт workflows
COPY (SELECT * FROM workflow_entity) TO '/tmp/workflows.csv' WITH CSV HEADER;

-- Экспорт credentials
COPY (SELECT * FROM credentials_entity) TO '/tmp/credentials.csv' WITH CSV HEADER;

-- Экспорт пользователей (на всякий случай)
COPY (SELECT * FROM "user") TO '/tmp/users.csv' WITH CSV HEADER;
EOF

# Копируем SQL скрипт в контейнер
docker cp /tmp/export_n8n.sql postgres:/tmp/export_n8n.sql

# Выполняем экспорт
docker exec postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -f /tmp/export_n8n.sql

# Копируем результаты из контейнера
docker cp postgres:/tmp/workflows.csv "$BACKUP_NAME/"
docker cp postgres:/tmp/credentials.csv "$BACKUP_NAME/"
docker cp postgres:/tmp/users.csv "$BACKUP_NAME/"

# Удаляем временные файлы
docker exec postgres rm /tmp/workflows.csv /tmp/credentials.csv /tmp/users.csv /tmp/export_n8n.sql
rm /tmp/export_n8n.sql

echo -e "${GREEN}   ✅ Workflows и credentials экспортированы${NC}"

# 4. Создаем простую инструкцию по восстановлению
cat > "$BACKUP_NAME/КАК_ВОССТАНОВИТЬ.txt" << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║         📋 ИНСТРУКЦИЯ ПО ВОССТАНОВЛЕНИЮ N8N                      ║
╚══════════════════════════════════════════════════════════════════╝

📦 ЧТО НАХОДИТСЯ В ЭТОЙ ПАПКЕ:

1. encryption_key.txt       - Ключ шифрования (САМОЕ ВАЖНОЕ!)
2. database_info.txt        - Данные для подключения к базе
3. workflows.csv            - Все ваши workflows
4. credentials.csv          - Все сохраненные credentials
5. users.csv                - Пользователи системы

⚠️  КРИТИЧЕСКИ ВАЖНО:

Ключ шифрования (N8N_ENCRYPTION_KEY) ОБЯЗАТЕЛЬНО должен быть
таким же на новом сервере! Без него credentials не расшифруются!
Храните ключ в password storage (1Password, Bitwarden и т.д.).

📝 ДЛЯ ВОССТАНОВЛЕНИЯ НА НОВОМ СЕРВЕРЕ:

1. Установите n8n на новом сервере
2. ПЕРЕД первым запуском установите N8N_ENCRYPTION_KEY из файла
   encryption_key.txt (или из password storage) в файл .env на новом сервере
3. Используйте скрипт simple-restore.sh для восстановления данных

Дата создания бэкапа: DATE_PLACEHOLDER
EOF

# Заменяем DATE_PLACEHOLDER на реальную дату
sed -i "s/DATE_PLACEHOLDER/$(date)/" "$BACKUP_NAME/КАК_ВОССТАНОВИТЬ.txt"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ БЭКАП ГОТОВ!                                   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "📁 Папка с бэкапом: ${YELLOW}$BACKUP_NAME${NC}"
echo ""
echo -e "${YELLOW}📥 Чтобы скачать на Windows компьютер:${NC}"
echo ""
echo -e "1. Откройте программу WinSCP или используйте команду:"
echo -e "   ${GREEN}pscp user@server:$(pwd)/$BACKUP_NAME C:\\Downloads\\${NC}"
echo ""
echo -e "2. Или создайте архив и скачайте его:"
echo -e "   ${GREEN}tar -czf ${BACKUP_NAME}.tar.gz $BACKUP_NAME${NC}"
echo -e "   ${GREEN}pscp user@server:$(pwd)/${BACKUP_NAME}.tar.gz C:\\Downloads\\${NC}"
echo ""
