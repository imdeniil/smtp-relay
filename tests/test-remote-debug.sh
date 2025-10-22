#!/bin/bash

################################################################################
# SMTP Relay Debug Script
# Диагностический скрипт с подробным выводом
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Параметры
if [ $# -eq 4 ]; then
    SMTP_HOST="$1"
    SMTP_PORT="$2"
    SMTP_USER="$3"
    SMTP_PASS="$4"
else
    echo "Использование: $0 HOST PORT USER PASS"
    echo "Пример: $0 keemor.su 6025 user@gmail.com password"
    exit 1
fi

SENDER_USER="${SMTP_USER%%@*}"
SENDER_DOMAIN="${SMTP_HOST}"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}SMTP Debug Test${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo "Сервер: $SMTP_HOST:$SMTP_PORT"
echo "User:   $SMTP_USER"
echo ""

# Тест 1: DNS
echo -e "${CYAN}[1/6] DNS Resolution${NC}"
if command -v dig &> /dev/null; then
    IP=$(dig +short $SMTP_HOST | head -1)
    if [ -n "$IP" ]; then
        echo "✓ $SMTP_HOST -> $IP"
    else
        echo "✗ DNS не разрешается"
    fi
elif command -v nslookup &> /dev/null; then
    nslookup $SMTP_HOST | grep "Address" | tail -1
else
    echo "⚠ dig/nslookup не найдены"
fi
echo ""

# Тест 2: Ping
echo -e "${CYAN}[2/6] Connectivity${NC}"
if ping -c 2 -W 2 $SMTP_HOST &> /dev/null; then
    echo "✓ Хост доступен (ping)"
else
    echo "⚠ Ping не прошел (может быть заблокирован)"
fi
echo ""

# Тест 3: TCP порт
echo -e "${CYAN}[3/6] TCP Port Check${NC}"
if timeout 5 bash -c "echo > /dev/tcp/$SMTP_HOST/$SMTP_PORT" 2>/dev/null; then
    echo "✓ Порт $SMTP_PORT доступен"
else
    echo "✗ Порт $SMTP_PORT недоступен"
    exit 1
fi
echo ""

# Тест 4: Проверка доступности nc
echo -e "${CYAN}[4/6] Netcat Availability${NC}"
if command -v nc &> /dev/null; then
    NC_VERSION=$(nc -h 2>&1 | head -1 || echo "unknown")
    echo "✓ nc найден: $NC_VERSION"
else
    echo "✗ nc (netcat) не установлен"
    echo "Установите: apt-get install netcat-openbsd"
    exit 1
fi
echo ""

# Тест 5: Raw SMTP
echo -e "${CYAN}[5/6] Raw SMTP Test${NC}"
echo "Команда: (echo 'EHLO localhost'; sleep 2; echo 'QUIT') | nc -w 5 $SMTP_HOST $SMTP_PORT"
echo ""
echo "Ответ сервера:"
echo "---"
(echo 'EHLO localhost'; sleep 2; echo 'QUIT') | nc -w 5 $SMTP_HOST $SMTP_PORT 2>&1
echo "---"
echo ""

# Тест 6: Telnet (если доступен)
echo -e "${CYAN}[6/6] Telnet Test${NC}"
if command -v telnet &> /dev/null; then
    echo "Команда: echo 'QUIT' | timeout 3 telnet $SMTP_HOST $SMTP_PORT"
    echo ""
    echo "Ответ:"
    echo "---"
    (sleep 1; echo "EHLO localhost"; sleep 1; echo "QUIT") | timeout 5 telnet $SMTP_HOST $SMTP_PORT 2>&1 | grep -v "Escape character"
    echo "---"
else
    echo "⚠ telnet не установлен"
fi
echo ""

# Итог
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Проверьте вывод выше для диагностики${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo "Ожидаемые ответы SMTP сервера:"
echo "  220 ... ESMTP  - Приветствие"
echo "  250 ... - Успешная команда EHLO"
echo "  221 Bye - Выход"
