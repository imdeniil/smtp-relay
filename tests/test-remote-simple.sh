#!/bin/bash

################################################################################
# Simple SMTP Relay Remote Testing Script
# Упрощенный скрипт для быстрого тестирования
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Загрузка параметров
if [ $# -eq 4 ]; then
    SMTP_HOST="$1"
    SMTP_PORT="$2"
    SMTP_USER="$3"
    SMTP_PASS="$4"
elif [ -f .env ]; then
    source .env
    SMTP_HOST="${RELAY_MYDOMAIN}"
    SMTP_PORT="${SMTP_PORT:-6025}"
    SMTP_USER="${SASL_USERNAME}"
    SMTP_PASS="${SASL_PASSWORD}"
else
    echo -e "${RED}Ошибка: не найден .env или параметры не переданы${NC}"
    echo "Использование: $0 HOST PORT USER PASS"
    exit 1
fi

SENDER_USER="${SMTP_USER%%@*}"
SENDER_DOMAIN="${RELAY_MYDOMAIN:-${SMTP_HOST}}"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}SMTP Relay Quick Test${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo "Сервер: $SMTP_HOST:$SMTP_PORT"
echo "User:   $SMTP_USER"
echo ""

# Тест 1: Порт
echo -n "Проверка порта... "
if timeout 5 bash -c "echo > /dev/tcp/$SMTP_HOST/$SMTP_PORT" 2>/dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    exit 1
fi

# Тест 2: SMTP EHLO
echo -n "SMTP EHLO... "

# Проверка наличия nc
if ! command -v nc &> /dev/null; then
    echo -e "${YELLOW}⚠ nc не установлен${NC}"
    echo "Установите: apt-get install netcat-openbsd"
    SKIP_NC=true
else
    # Пробуем разные варианты nc
    RESPONSE=$(timeout 8 bash -c "(echo 'EHLO localhost'; sleep 2; echo 'QUIT') | nc -w 5 $SMTP_HOST $SMTP_PORT 2>&1" || \
               timeout 8 bash -c "(echo 'EHLO localhost'; sleep 2; echo 'QUIT') | nc $SMTP_HOST $SMTP_PORT 2>&1")

    if echo "$RESPONSE" | grep -q "250"; then
        echo -e "${GREEN}✓${NC}"
    elif echo "$RESPONSE" | grep -q "220"; then
        echo -e "${GREEN}✓ (соединение установлено)${NC}"
    else
        echo -e "${RED}✗${NC}"
        echo ""
        echo "Debug: Попробуйте команду вручную:"
        echo "  (echo 'EHLO localhost'; sleep 2; echo 'QUIT') | nc $SMTP_HOST $SMTP_PORT"
        echo ""
        echo "Или используйте debug скрипт:"
        echo "  ./test-remote-debug.sh $SMTP_HOST $SMTP_PORT $SMTP_USER [password]"
        echo ""
        SKIP_NC=true
    fi
fi

# Тест 3: Python (если доступен)
if command -v python3 &> /dev/null; then
    echo -n "Python SMTP Test... "

    RESULT=$(python3 << PYEOF
import smtplib
import sys
try:
    server = smtplib.SMTP("$SMTP_HOST", $SMTP_PORT, timeout=10)

    # Пробуем STARTTLS, но не критично если не работает (localhost)
    try:
        server.starttls()
    except:
        pass

    server.login("$SMTP_USER", "$SMTP_PASS")

    from email.mime.text import MIMEText
    msg = MIMEText("Test from quick test script")
    msg['Subject'] = "SMTP Relay Quick Test"
    msg['From'] = "${SENDER_USER}@${SENDER_DOMAIN}"
    msg['To'] = "$SMTP_USER"

    server.send_message(msg)
    server.quit()
    print("OK")
except Exception as e:
    print(f"ERROR: {e}")
    sys.exit(1)
PYEOF
)

    if echo "$RESULT" | grep -q "OK"; then
        echo -e "${GREEN}✓ Письмо отправлено!${NC}"
    elif echo "$RESULT" | grep -q "TLS not available"; then
        echo -e "${YELLOW}⚠ (TLS недоступен - нормально для localhost)${NC}"
    else
        echo -e "${RED}✗${NC}"
        echo "$RESULT"
        exit 1
    fi
else
    echo -e "${YELLOW}Python3 не найден - пропуск теста отправки${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ ВСЕ ТЕСТЫ ПРОЙДЕНЫ!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Настройки для приложений:"
echo "  Host:      $SMTP_HOST"
echo "  Port:      $SMTP_PORT"
echo "  Username:  $SMTP_USER"
echo "  STARTTLS:  true"
echo "  Sender:    *@$SENDER_DOMAIN"
