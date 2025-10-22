#!/bin/bash

################################################################################
# SMTP Relay Remote Testing Script
# Скрипт для тестирования SMTP relay с удаленного сервера
#
# Использование:
#   ./test-remote.sh                          # Использует данные из .env
#   ./test-remote.sh HOST PORT USER PASS      # Указать параметры вручную
################################################################################

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

################################################################################
# Загрузка параметров
################################################################################

if [ $# -eq 4 ]; then
    # Параметры из аргументов командной строки
    SMTP_HOST="$1"
    SMTP_PORT="$2"
    SMTP_USER="$3"
    SMTP_PASS="$4"
    print_info "Используются параметры из командной строки"
elif [ -f .env ]; then
    # Параметры из .env файла
    source .env
    SMTP_HOST="${RELAY_MYDOMAIN}"
    SMTP_PORT="${SMTP_PORT:-6025}"
    SMTP_USER="${SASL_USERNAME}"
    SMTP_PASS="${SASL_PASSWORD}"
    print_info "Используются параметры из .env файла"
else
    print_error "Не найден .env файл и не переданы параметры"
    echo ""
    echo "Использование:"
    echo "  $0 HOST PORT USERNAME PASSWORD"
    echo ""
    echo "Пример:"
    echo "  $0 keemor.su 6025 user@gmail.com password123"
    exit 1
fi

# Извлекаем домен из SMTP_USER для sender address
SENDER_USER="${SMTP_USER%%@*}"
SENDER_DOMAIN="${RELAY_MYDOMAIN:-${SMTP_HOST}}"
SENDER_ADDRESS="${SENDER_USER}@${SENDER_DOMAIN}"

################################################################################
# Вывод информации о подключении
################################################################################

print_header "SMTP Relay Remote Testing"

echo -e "${CYAN}Параметры подключения:${NC}"
echo "  Сервер:         $SMTP_HOST"
echo "  Порт:           $SMTP_PORT"
echo "  Username:       $SMTP_USER"
echo "  Password:       ******** (скрыто)"
echo "  Sender Address: $SENDER_ADDRESS"
echo ""

################################################################################
# Тест 1: Проверка доступности порта
################################################################################

print_header "Тест 1/5: Проверка Доступности Порта"

if timeout 5 bash -c "echo > /dev/tcp/$SMTP_HOST/$SMTP_PORT" 2>/dev/null; then
    print_success "Порт $SMTP_HOST:$SMTP_PORT доступен"
else
    print_error "Не удается подключиться к $SMTP_HOST:$SMTP_PORT"
    echo ""
    print_info "Возможные причины:"
    echo "  - Firewall блокирует исходящие подключения"
    echo "  - Неправильный host или port"
    echo "  - SMTP сервер не запущен"
    exit 1
fi
echo ""

################################################################################
# Тест 2: SMTP EHLO (без шифрования)
################################################################################

print_header "Тест 2/5: SMTP EHLO (Базовое Подключение)"

EHLO_RESPONSE=$(timeout 10 bash -c "(echo 'EHLO localhost'; sleep 1; echo 'QUIT') | nc -w 5 $SMTP_HOST $SMTP_PORT 2>&1")

if echo "$EHLO_RESPONSE" | grep -q "220.*ESMTP"; then
    print_success "SMTP сервер отвечает корректно"
    echo ""
    echo -e "${CYAN}Ответ сервера:${NC}"
    echo "$EHLO_RESPONSE" | head -10 | sed 's/^/  /'
else
    print_error "SMTP сервер не отвечает корректно"
    echo "$EHLO_RESPONSE"
    exit 1
fi

# Проверка поддержки STARTTLS
if echo "$EHLO_RESPONSE" | grep -q "STARTTLS"; then
    print_success "STARTTLS поддерживается"
else
    print_warning "STARTTLS не найден в ответе сервера"
fi

# Проверка поддержки AUTH
if echo "$EHLO_RESPONSE" | grep -q "AUTH"; then
    print_success "Аутентификация поддерживается"
    echo "$EHLO_RESPONSE" | grep "AUTH" | sed 's/^/  /'
else
    print_warning "AUTH не найден в ответе сервера"
fi

echo ""

################################################################################
# Тест 3: STARTTLS подключение
################################################################################

print_header "Тест 3/5: STARTTLS Подключение"

# Проверка наличия openssl
if ! command -v openssl &> /dev/null; then
    print_warning "OpenSSL не установлен - пропуск STARTTLS теста"
    print_info "Установите: apt-get install openssl"
    SKIP_STARTTLS=true
else
    STARTTLS_RESPONSE=$(timeout 10 bash -c "(echo 'EHLO localhost'; sleep 2; echo 'QUIT') | openssl s_client -connect $SMTP_HOST:$SMTP_PORT -starttls smtp -quiet 2>&1")
    
    if echo "$STARTTLS_RESPONSE" | grep -q "250"; then
        print_success "STARTTLS соединение установлено"
        
        # Проверка сертификата
        if echo "$STARTTLS_RESPONSE" | grep -q "Verify return code: 0"; then
            print_success "SSL сертификат валиден"
        else
            print_warning "SSL сертификат не верифицирован (нормально для самоподписанных)"
        fi
    else
        print_error "Ошибка STARTTLS соединения"
        echo "$STARTTLS_RESPONSE" | grep -i "error" | head -5
    fi
    SKIP_STARTTLS=false
fi

echo ""

################################################################################
# Тест 4: Аутентификация
################################################################################

print_header "Тест 4/5: SASL Аутентификация"

if [ "$SKIP_STARTTLS" = "true" ]; then
    print_warning "Пропущено (OpenSSL не установлен)"
else
    # Кодируем credentials в base64
    USER_B64=$(printf "%s" "$SMTP_USER" | base64)
    PASS_B64=$(printf "%s" "$SMTP_PASS" | base64)
    
    AUTH_RESPONSE=$(timeout 15 bash -c "
        {
            sleep 1
            echo 'EHLO localhost'
            sleep 1
            echo 'AUTH LOGIN'
            sleep 1
            echo '$USER_B64'
            sleep 1
            echo '$PASS_B64'
            sleep 1
            echo 'QUIT'
        } | openssl s_client -connect $SMTP_HOST:$SMTP_PORT -starttls smtp -quiet 2>&1
    ")
    
    if echo "$AUTH_RESPONSE" | grep -q "235.*Authentication successful"; then
        print_success "Аутентификация успешна!"
    elif echo "$AUTH_RESPONSE" | grep -q "235"; then
        print_success "Аутентификация успешна (код 235)"
    elif echo "$AUTH_RESPONSE" | grep -q "535"; then
        print_error "Аутентификация не удалась (код 535)"
        echo "$AUTH_RESPONSE" | grep "535" | sed 's/^/  /'
    else
        print_warning "Результат аутентификации неясен"
        echo ""
        echo -e "${CYAN}Ответ сервера:${NC}"
        echo "$AUTH_RESPONSE" | grep -E "^(220|250|334|235|535)" | sed 's/^/  /'
    fi
fi

echo ""

################################################################################
# Тест 5: Python SMTP Test (если доступен)
################################################################################

print_header "Тест 5/5: Полный Тест с Python"

if ! command -v python3 &> /dev/null; then
    print_warning "Python3 не установлен - пропуск Python теста"
    print_info "Установите: apt-get install python3"
else
    # Создаем временный Python скрипт
    PYTHON_TEST=$(mktemp)
    cat > "$PYTHON_TEST" << PYEOF
import smtplib
import sys
from email.mime.text import MIMEText

try:
    server = smtplib.SMTP("$SMTP_HOST", $SMTP_PORT, timeout=10)
    server.starttls()
    server.login("$SMTP_USER", "$SMTP_PASS")
    
    # Пробуем отправить тестовое письмо
    msg = MIMEText("Test from remote server $(hostname) at $(date)")
    msg['Subject'] = "SMTP Relay Test"
    msg['From'] = "$SENDER_ADDRESS"
    msg['To'] = "$SMTP_USER"
    
    server.send_message(msg)
    server.quit()
    
    print("SUCCESS")
    sys.exit(0)
    
except smtplib.SMTPAuthenticationError as e:
    print(f"AUTH_ERROR: {e}")
    sys.exit(1)
except smtplib.SMTPException as e:
    print(f"SMTP_ERROR: {e}")
    sys.exit(2)
except Exception as e:
    print(f"ERROR: {e}")
    sys.exit(3)
PYEOF
    
    PYTHON_RESULT=$(python3 "$PYTHON_TEST" 2>&1)
    PYTHON_EXIT=$?
    
    rm -f "$PYTHON_TEST"
    
    if [ $PYTHON_EXIT -eq 0 ]; then
        print_success "Python тест успешен - письмо отправлено!"
    else
        print_error "Python тест не прошел"
        echo ""
        echo -e "${CYAN}Ошибка:${NC}"
        echo "$PYTHON_RESULT" | sed 's/^/  /'
    fi
fi

echo ""

################################################################################
# Финальный результат
################################################################################

print_header "Результаты Тестирования"

echo -e "${CYAN}Краткая сводка:${NC}"
echo "  Сервер:       $SMTP_HOST:$SMTP_PORT"
echo "  Username:     $SMTP_USER"
echo "  Sender:       $SENDER_ADDRESS"
echo ""

if [ $PYTHON_EXIT -eq 0 ] 2>/dev/null; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✅ ВСЕ ТЕСТЫ ПРОЙДЕНЫ!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "SMTP Relay полностью функционален и доступен с удаленного сервера."
    echo ""
    echo -e "${CYAN}Настройки для вашего приложения:${NC}"
    echo "  SMTP Host:     $SMTP_HOST"
    echo "  SMTP Port:     $SMTP_PORT"
    echo "  SMTP User:     $SMTP_USER"
    echo "  SMTP Password: (используйте ваш пароль)"
    echo "  Use STARTTLS:  true"
    echo "  Sender (FROM): *@$SENDER_DOMAIN"
    exit 0
else
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}⚠️  НЕКОТОРЫЕ ТЕСТЫ НЕ ПРОЙДЕНЫ${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    echo "Проверьте логи выше для деталей."
    exit 1
fi
