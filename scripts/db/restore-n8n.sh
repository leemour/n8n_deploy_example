#!/bin/bash

# Скрипт для восстановления n8n из бэкапа
# Использование: ./restore-n8n.sh <путь_к_архиву_бэкапа>
# Запускать из корня проекта (где есть docker-compose)

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

if [ "$#" -ne 1 ]; then
    echo -e "${RED}Использование: $0 <путь_к_архиву_бэкапа>${NC}"
    echo "Пример: $0 n8n_backup_20260121_120000.tar.gz"
    exit 1
fi

BACKUP_ARCHIVE="$1"

if [ ! -f "$BACKUP_ARCHIVE" ]; then
    echo -e "${RED}Ошибка: файл $BACKUP_ARCHIVE не найден!${NC}"
    exit 1
fi

echo -e "${GREEN}=== Начало восстановления n8n ===${NC}"
echo -e "${YELLOW}Архив: $BACKUP_ARCHIVE${NC}"
echo ""

# Извлекаем архив
echo -e "${GREEN}1. Извлечение архива...${NC}"
BACKUP_DIR=$(basename "$BACKUP_ARCHIVE" .tar.gz)
tar -xzf "$BACKUP_ARCHIVE"
cd "$BACKUP_DIR"
echo -e "${GREEN}   ✓ Архив извлечен${NC}"

# Проверяем наличие необходимых файлов
echo -e "${GREEN}2. Проверка содержимого бэкапа...${NC}"
REQUIRED_FILES=("n8n_database.dump" ".env" "docker-compose.yaml")
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}   ✗ Отсутствует критический файл: $file${NC}"
        exit 1
    fi
    echo -e "${GREEN}   ✓ $file${NC}"
done
[ -f "n8n_storage.tar.gz" ] && echo -e "${GREEN}   ✓ n8n_storage.tar.gz${NC}" || echo -e "${YELLOW}   (n8n_storage.tar.gz отсутствует)${NC}"

# Предупреждение
echo ""
echo -e "${YELLOW}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  ⚠️  ВНИМАНИЕ!                                     ║${NC}"
echo -e "${YELLOW}║                                                    ║${NC}"
echo -e "${YELLOW}║  Это действие перезапишет текущие данные!         ║${NC}"
echo -e "${YELLOW}║  Убедитесь, что вы на правильном сервере!         ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════╝${NC}"
echo ""
read -p "Продолжить? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${RED}Восстановление отменено${NC}"
    exit 1
fi

# Переходим в родительскую директорию
cd ..

# Останавливаем текущие контейнеры (если есть)
echo -e "${GREEN}3. Остановка существующих контейнеров...${NC}"
if [ -f "docker-compose.yaml" ]; then
    docker compose down 2>/dev/null || true
    echo -e "${GREEN}   ✓ Контейнеры остановлены${NC}"
else
    echo -e "${YELLOW}   docker-compose.yaml не найден, пропускаем${NC}"
fi

# Восстанавливаем .env
# echo -e "${GREEN}4. Восстановление .env файла...${NC}"
# cp "$BACKUP_DIR/.env" .env
# echo -e "${GREEN}   ✓ .env восстановлен${NC}"

# Восстанавливаем docker-compose файлы
# echo -e "${GREEN}5. Восстановление docker-compose файлов...${NC}"
# cp "$BACKUP_DIR/docker-compose.yaml" .
# if [ -f "$BACKUP_DIR/docker-compose.dev.yaml" ]; then
#     cp "$BACKUP_DIR/docker-compose.dev.yaml" .
# fi
# # init-dbs.sh (для Evolution/Langfuse и т.д.)
# if [ -f "$BACKUP_DIR/init-dbs.sh" ]; then
#     cp "$BACKUP_DIR/init-dbs.sh" ./init-dbs.sh
#     chmod +x ./init-dbs.sh
# fi
# echo -e "${GREEN}   ✓ Docker-compose и скрипты восстановлены${NC}"

# Восстанавливаем n8n_storage
echo -e "${GREEN}6. Восстановление n8n_storage...${NC}"
if [ -f "$BACKUP_DIR/n8n_storage.tar.gz" ]; then
    rm -rf n8n_storage 2>/dev/null || true
    tar -xzf "$BACKUP_DIR/n8n_storage.tar.gz"
    echo -e "${GREEN}   ✓ n8n_storage восстановлен${NC}"
else
    echo -e "${YELLOW}   n8n_storage.tar.gz отсутствует, пропускаем${NC}"
fi

# Восстанавливаем shared (если есть)
if [ -f "$BACKUP_DIR/shared.tar.gz" ]; then
    echo -e "${GREEN}7. Восстановление shared директории...${NC}"
    rm -rf shared 2>/dev/null || true
    tar -xzf "$BACKUP_DIR/shared.tar.gz"
    echo -e "${GREEN}   ✓ shared восстановлен${NC}"
else
    echo -e "${YELLOW}7. shared.tar.gz не найден, пропускаем${NC}"
fi

# Создаем сеть Docker (если не существует)
echo -e "${GREEN}8. Создание Docker сети...${NC}"
docker network create n8n-network 2>/dev/null || echo -e "${YELLOW}   Сеть n8n-network уже существует${NC}"

# Запускаем только PostgreSQL
echo -e "${GREEN}9. Запуск PostgreSQL...${NC}"
docker compose up -d postgres
echo -e "${YELLOW}   Ожидание готовности PostgreSQL...${NC}"
sleep 10
echo -e "${GREEN}   ✓ PostgreSQL запущен${NC}"

# Восстанавливаем базу данных (читаем POSTGRES_* из .env без source — в .env могут быть значения с пробелами)
echo -e "${GREEN}10. Восстановление базы данных...${NC}"
POSTGRES_USER=$(grep -E '^POSTGRES_USER=' .env | cut -d= -f2- | tr -d '\r' | sed -e "s/^['\"]//" -e "s/['\"]$//")
POSTGRES_DB=$(grep -E '^POSTGRES_DB=' .env | cut -d= -f2- | tr -d '\r' | sed -e "s/^['\"]//" -e "s/['\"]$//")

# Копируем дамп в контейнер
docker cp "$BACKUP_DIR/n8n_database.dump" postgres:/tmp/n8n_backup.dump

# Восстанавливаем
docker exec postgres pg_restore -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" --clean --if-exists /tmp/n8n_backup.dump 2>/dev/null || {
    echo -e "${YELLOW}   Некоторые предупреждения при восстановлении (это нормально для первого раза)${NC}"
}

# Удаляем временный файл
docker exec postgres rm /tmp/n8n_backup.dump
echo -e "${GREEN}   ✓ База данных восстановлена${NC}"

# Запускаем все сервисы
echo -e "${GREEN}11. Запуск всех сервисов n8n...${NC}"
docker compose up -d
echo -e "${GREEN}   ✓ Все сервисы запущены${NC}"

# Показываем статус
echo ""
echo -e "${GREEN}12. Проверка статуса...${NC}"
sleep 5
docker compose ps

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ ВОССТАНОВЛЕНИЕ УСПЕШНО ЗАВЕРШЕНО!              ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Важные проверки:${NC}"
echo -e "1. Проверьте логи: ${YELLOW}docker compose logs -f n8n${NC}"
echo -e "2. Проверьте доступность: ${YELLOW}http://localhost:5678${NC}"
echo -e "3. Войдите и проверьте workflows и credentials"
echo ""
echo -e "${YELLOW}Ключ шифрования в .env:${NC}"
grep -E '^N8N_ENCRYPTION_KEY=' .env 2>/dev/null || true
echo ""
