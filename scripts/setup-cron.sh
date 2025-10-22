#!/bin/bash

#########################################
# Setup Cron Job for SSL Symlinks Monitoring
# Автоматическая установка cron задачи
#########################################

set -e

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Установка Cron для SSL Мониторинга${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Получаем текущую директорию проекта
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${YELLOW}Директория проекта: $PROJECT_DIR${NC}"
echo ""

# Проверяем существует ли уже задача
if crontab -l 2>/dev/null | grep -q "check-ssl-symlinks"; then
    echo -e "${YELLOW}⚠️  Cron задача уже существует${NC}"
    echo ""
    crontab -l | grep "check-ssl-symlinks"
    echo ""
    read -p "Обновить существующую задачу? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Отменено${NC}"
        exit 0
    fi

    # Удаляем старую задачу
    crontab -l 2>/dev/null | grep -v "SSL Symlinks" | grep -v "check-ssl-symlinks" | crontab -
fi

# Добавляем новую задачу
(crontab -l 2>/dev/null || true; echo "# SSL Symlinks Auto-Check and Fix (every 5 minutes)"; echo "*/5 * * * * $PROJECT_DIR/scripts/check-ssl-symlinks.sh > /dev/null 2>&1 || $PROJECT_DIR/manage.sh fix-ssl-symlinks >> /var/log/ssl-symlinks-fix.log 2>&1") | crontab -

echo -e "${GREEN}✅ Cron задача успешно установлена${NC}"
echo ""

echo -e "${BLUE}Установленная задача:${NC}"
crontab -l | tail -2
echo ""

echo -e "${YELLOW}Информация:${NC}"
echo "  • Проверка: каждые 5 минут"
echo "  • Логи: /var/log/ssl-symlinks-fix.log"
echo "  • Скрипт: $PROJECT_DIR/scripts/check-ssl-symlinks.sh"
echo ""

echo -e "${BLUE}Проверка cron сервиса...${NC}"
if systemctl is-active --quiet cron; then
    echo -e "${GREEN}✓ Cron сервис работает${NC}"
else
    echo -e "${YELLOW}⚠️  Cron сервис не запущен, запускаем...${NC}"
    systemctl start cron
    systemctl enable cron
    echo -e "${GREEN}✓ Cron сервис запущен${NC}"
fi
echo ""

echo -e "${BLUE}Полезные команды:${NC}"
echo "  crontab -l                           # Просмотр задач"
echo "  tail -f /var/log/ssl-symlinks-fix.log # Просмотр логов"
echo "  $PROJECT_DIR/manage.sh check-ssl-symlinks # Ручная проверка"
echo ""

echo -e "${GREEN}Готово!${NC} Симлинки SSL будут проверяться автоматически каждые 5 минут."
