#!/bin/bash

################################################################################
# Скрипт Управления SMTP Relay
# Унифицированный инструмент управления для всех режимов развертывания
################################################################################

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Автоопределение файла compose
detect_compose_file() {
    if [ -f "configs/docker-compose.full.yml" ] && docker ps | grep -q "nginx-proxy.*smtp"; then
        COMPOSE_FILE="configs/docker-compose.full.yml"
    elif [ -f "configs/docker-compose.smtp-only.yml" ]; then
        COMPOSE_FILE="configs/docker-compose.smtp-only.yml"
    else
        echo -e "${RED}Файл compose не найден${NC}"
        exit 1
    fi
}

# Загрузка окружения
load_env() {
    if [ -f .env ]; then
        set -a
        source .env
        set +a
    else
        echo -e "${RED}Файл .env не найден${NC}"
        exit 1
    fi
}

################################################################################
# Справка
################################################################################

show_help() {
    cat << EOF
${CYAN}========================================
Инструмент Управления SMTP Relay
========================================${NC}

${YELLOW}Использование:${NC} $0 [команда] [опции]

${YELLOW}Управление Сервисом:${NC}
  start               Запустить SMTP relay
  stop                Остановить SMTP relay
  restart             Перезапустить SMTP relay
  status              Показать статус сервиса
  logs [service]      Показать логи (добавьте -f для отслеживания)

${YELLOW}Управление SASL Пользователями:${NC}
  users               Список SASL пользователей
  add-user            Добавить нового SASL пользователя
  del-user            Удалить SASL пользователя
  reset-password      Сбросить пароль пользователя

${YELLOW}Операции с Почтой:${NC}
  test [email]        Отправить тестовое письмо
  queue               Показать очередь почты
  flush               Очистить очередь почты
  stats               Показать статистику почты

${YELLOW}TLS/Сертификаты:${NC}
  tls-check           Проверить функциональность STARTTLS
  tls-info            Показать информацию о сертификате
  cert-renew          Принудительное обновление сертификата
  fix-ssl-symlinks    Исправить симлинки SSL сертификатов

${YELLOW}Устранение Неполадок:${NC}
  health              Полная проверка здоровья
  diagnose            Запустить диагностику
  fix-permissions     Исправить права на volume

${YELLOW}Расширенные:${NC}
  clean               Удалить все данные (ОПАСНО)
  backup              Резервное копирование конфигурации и данных
  restore [file]      Восстановить из резервной копии
  shell               Открыть оболочку в контейнере

${YELLOW}Примеры:${NC}
  $0 status
  $0 logs -f
  $0 test user@example.com
  $0 add-user

EOF
}

################################################################################
# Управление Сервисом
################################################################################

start_service() {
    echo -e "${YELLOW}Запуск SMTP relay...${NC}"
    docker compose -f $COMPOSE_FILE up -d smtp-relay
    sleep 3

    if docker ps | grep -q smtp-relay; then
        echo -e "${GREEN}✓ SMTP relay запущен${NC}"
    else
        echo -e "${RED}✗ Не удалось запустить SMTP relay${NC}"
        docker compose -f $COMPOSE_FILE logs smtp-relay
        exit 1
    fi
}

stop_service() {
    echo -e "${YELLOW}Остановка SMTP relay...${NC}"
    docker compose -f $COMPOSE_FILE stop smtp-relay
    echo -e "${GREEN}✓ SMTP relay остановлен${NC}"
}

restart_service() {
    echo -e "${YELLOW}Перезапуск SMTP relay...${NC}"
    docker compose -f $COMPOSE_FILE restart smtp-relay
    sleep 3
    echo -e "${GREEN}✓ SMTP relay перезапущен${NC}"
}

show_status() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}Статус Сервиса${NC}"
    echo -e "${CYAN}========================================${NC}"

    # Статус контейнера
    if docker ps | grep -q smtp-relay; then
        echo -e "${GREEN}● smtp-relay: работает${NC}"
        docker ps --format "  {{.Status}}" | grep smtp-relay || true
    else
        echo -e "${RED}● smtp-relay: остановлен${NC}"
    fi

    echo ""
    echo -e "${BLUE}Конфигурация:${NC}"
    echo "  Имя хоста: $RELAY_MYHOSTNAME"
    echo "  Домен:     $RELAY_MYDOMAIN"
    echo "  Порт:      ${SMTP_PORT:-6025}"
    echo "  Upstream:  $RELAY_HOST"

    echo ""
    echo -e "${BLUE}Проверки Здоровья:${NC}"

    # Проверка порта
    if nc -z localhost ${SMTP_PORT:-6025} 2>/dev/null; then
        echo -e "${GREEN}  ✓ SMTP порт доступен${NC}"
    else
        echo -e "${RED}  ✗ SMTP порт недоступен${NC}"
    fi

    # Проверка STARTTLS
    if [ "${ENABLE_STARTTLS:-yes}" = "yes" ]; then
        if command -v openssl &>/dev/null; then
            echo "QUIT" | timeout 2 openssl s_client -connect localhost:${SMTP_PORT:-6025} -starttls smtp -brief 2>/dev/null >/dev/null
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}  ✓ STARTTLS активен${NC}"
            else
                echo -e "${YELLOW}  ⚠ STARTTLS не отвечает${NC}"
            fi
        else
            echo -e "${YELLOW}  ⚠ openssl не установлен (невозможно проверить STARTTLS)${NC}"
        fi
    else
        echo -e "${YELLOW}  ○ STARTTLS отключен${NC}"
    fi

    # Здоровье контейнера
    HEALTH=$(docker inspect smtp-relay --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
    if [ "$HEALTH" = "healthy" ]; then
        echo -e "${GREEN}  ✓ Здоровье контейнера: здоров${NC}"
    elif [ "$HEALTH" = "unknown" ]; then
        echo -e "${YELLOW}  ○ Здоровье контейнера: нет healthcheck${NC}"
    else
        echo -e "${RED}  ✗ Здоровье контейнера: $HEALTH${NC}"
    fi

    echo ""
}

show_logs() {
    local service="${1:-smtp-relay}"
    local follow="${2}"

    if [ "$follow" = "-f" ]; then
        docker compose -f $COMPOSE_FILE logs -f $service
    else
        docker compose -f $COMPOSE_FILE logs --tail=100 $service
    fi
}

################################################################################
# Управление Пользователями
################################################################################

list_users() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}SASL Пользователи${NC}"
    echo -e "${CYAN}========================================${NC}"
    docker exec smtp-relay /opt/listpasswd.sh 2>/dev/null || echo "Пользователи не найдены"
}

add_user() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}Добавить SASL Пользователя${NC}"
    echo -e "${CYAN}========================================${NC}"

    read -p "Имя пользователя (можно с доменом, например: user@domain.com): " username
    read -sp "Пароль: " password
    echo ""
    read -sp "Подтвердите пароль: " password2
    echo ""

    if [ "$password" != "$password2" ]; then
        echo -e "${RED}✗ Пароли не совпадают${NC}"
        exit 1
    fi

    # Извлекаем username и домен
    if [[ "$username" == *"@"* ]]; then
        SASL_USER="${username%%@*}"
        SASL_DOMAIN="${username##*@}"
    else
        SASL_USER="$username"
        SASL_DOMAIN="${RELAY_MYDOMAIN}"
    fi

    printf "${password}\n${password}\n" | \
        docker exec -i smtp-relay /opt/saslpasswd.sh -u "$SASL_DOMAIN" -c "$SASL_USER"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Пользователь ${SASL_USER}@${SASL_DOMAIN} создан${NC}"
    else
        echo -e "${RED}✗ Не удалось создать пользователя${NC}"
        exit 1
    fi
}

delete_user() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}Удалить SASL Пользователя${NC}"
    echo -e "${CYAN}========================================${NC}"

    list_users
    echo ""

    read -p "Имя пользователя для удаления (можно с доменом): " username
    read -p "Вы уверены? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        echo "Отменено"
        exit 0
    fi

    # Извлекаем username и домен
    if [[ "$username" == *"@"* ]]; then
        SASL_USER="${username%%@*}"
        SASL_DOMAIN="${username##*@}"
    else
        SASL_USER="$username"
        SASL_DOMAIN="${RELAY_MYDOMAIN}"
    fi

    docker exec smtp-relay /opt/saslpasswd.sh -u "$SASL_DOMAIN" -d "$SASL_USER"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Пользователь ${SASL_USER}@${SASL_DOMAIN} удален${NC}"
    else
        echo -e "${RED}✗ Не удалось удалить пользователя${NC}"
    fi
}

reset_password() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}Сбросить Пароль Пользователя${NC}"
    echo -e "${CYAN}========================================${NC}"

    list_users
    echo ""

    read -p "Имя пользователя (можно с доменом): " username
    read -sp "Новый пароль: " password
    echo ""
    read -sp "Подтвердите пароль: " password2
    echo ""

    if [ "$password" != "$password2" ]; then
        echo -e "${RED}✗ Пароли не совпадают${NC}"
        exit 1
    fi

    # Извлекаем username и домен
    if [[ "$username" == *"@"* ]]; then
        SASL_USER="${username%%@*}"
        SASL_DOMAIN="${username##*@}"
    else
        SASL_USER="$username"
        SASL_DOMAIN="${RELAY_MYDOMAIN}"
    fi

    printf "${password}\n${password}\n" | \
        docker exec -i smtp-relay /opt/saslpasswd.sh -u "$SASL_DOMAIN" -c "$SASL_USER"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Пароль обновлен для ${SASL_USER}@${SASL_DOMAIN}${NC}"
    else
        echo -e "${RED}✗ Не удалось обновить пароль${NC}"
    fi
}

################################################################################
# Операции с Почтой
################################################################################

send_test() {
    local recipient="${1:-$RELAY_POSTMASTER}"

    echo -e "${YELLOW}Отправка тестового письма на ${recipient}...${NC}"

    # Sender должен быть с доменом RELAY_MYDOMAIN (smtpd_sender_restrictions)
    # Используем первую часть SASL_USERNAME + RELAY_MYDOMAIN
    local sender_user="${SASL_USERNAME%%@*}"
    local sender="${sender_user}@${RELAY_MYDOMAIN}"

    echo -e "${CYAN}Отправитель: ${sender}${NC}"
    echo -e "${CYAN}Аутентификация: ${SASL_USERNAME}${NC}"

    # Создание тестового сообщения
    docker exec smtp-relay /opt/smtp_client.py \
        -s "Тест от SMTP Relay - $(date)" \
        -f "$sender" \
        --user "$SASL_USERNAME:$SASL_PASSWORD" \
        "$recipient" 2>&1

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Тестовое письмо отправлено${NC}"
    else
        echo -e "${RED}✗ Не удалось отправить тестовое письмо${NC}"
    fi
}

show_queue() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}Очередь Почты${NC}"
    echo -e "${CYAN}========================================${NC}"
    docker exec smtp-relay postqueue -p
}

flush_queue() {
    echo -e "${YELLOW}Очистка очереди почты...${NC}"
    docker exec smtp-relay postqueue -f
    echo -e "${GREEN}✓ Очистка очереди инициирована${NC}"
}

show_stats() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}Статистика Почты${NC}"
    echo -e "${CYAN}========================================${NC}"

    echo -e "${YELLOW}Отправленные сообщения (последние 10):${NC}"
    docker exec smtp-relay sh -c 'grep "status=sent" /var/log/mail.log 2>/dev/null | tail -10' || echo "  Нет отправленных сообщений"

    echo ""
    echo -e "${YELLOW}Отложенные сообщения (последние 10):${NC}"
    docker exec smtp-relay sh -c 'grep "status=deferred" /var/log/mail.log 2>/dev/null | tail -10' || echo "  Нет отложенных сообщений"

    echo ""
    echo -e "${YELLOW}Ошибки (последние 10):${NC}"
    docker exec smtp-relay sh -c 'grep -iE "(error|reject|warning)" /var/log/mail.log 2>/dev/null | tail -10' || echo "  Нет ошибок"

    echo ""
    echo -e "${YELLOW}Размер очереди:${NC}"
    QUEUE_SIZE=$(docker exec smtp-relay sh -c 'find /var/spool/postfix/deferred -type f 2>/dev/null | wc -l')
    echo "  $QUEUE_SIZE сообщений в очереди"
}

################################################################################
# TLS/Сертификаты
################################################################################

check_tls() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}Проверка STARTTLS${NC}"
    echo -e "${CYAN}========================================${NC}"

    if [ "${ENABLE_STARTTLS:-yes}" = "no" ]; then
        echo -e "${YELLOW}STARTTLS отключен в конфигурации${NC}"
        return
    fi

    if ! command -v openssl &>/dev/null; then
        echo -e "${RED}✗ openssl не установлен${NC}"
        echo -e "${YELLOW}Установите openssl для проверки STARTTLS:${NC}"
        echo -e "  apt-get install openssl   # Debian/Ubuntu"
        echo -e "  yum install openssl        # CentOS/RHEL"
        return 1
    fi

    echo -e "${YELLOW}Тестирование STARTTLS соединения...${NC}"
    echo ""

    echo "QUIT" | openssl s_client -connect localhost:${SMTP_PORT:-6025} -starttls smtp -showcerts 2>&1 | \
        grep -E "(CONNECTED|Verify return code|subject=|issuer=)" || true

    echo ""

    if echo "QUIT" | timeout 3 openssl s_client -connect localhost:${SMTP_PORT:-6025} -starttls smtp -brief 2>/dev/null >/dev/null; then
        echo -e "${GREEN}✓ STARTTLS работает${NC}"
    else
        echo -e "${RED}✗ STARTTLS не удался${NC}"
    fi
}

show_cert_info() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}Информация о Сертификате${NC}"
    echo -e "${CYAN}========================================${NC}"

    CERT_PATH="/etc/nginx/certs/${RELAY_MYDOMAIN}.crt"

    if docker exec smtp-relay test -f "$CERT_PATH" 2>/dev/null; then
        if docker exec smtp-relay which openssl &>/dev/null; then
            docker exec smtp-relay openssl x509 -in "$CERT_PATH" -noout -text 2>/dev/null | \
                grep -E "(Subject:|Issuer:|Not Before|Not After|DNS:)"
        else
            echo -e "${YELLOW}openssl не доступен в контейнере${NC}"
            echo -e "Файл сертификата существует:"
            docker exec smtp-relay ls -lh "$CERT_PATH" 2>/dev/null
        fi
    else
        echo -e "${RED}Сертификат не найден${NC}"
    fi
}

renew_certificate() {
    echo -e "${YELLOW}Принудительное обновление сертификата...${NC}"

    # Определение контейнера acme
    ACME_CONTAINER=""
    if docker ps | grep -q nginx-proxy-acme; then
        ACME_CONTAINER="nginx-proxy-acme"
    elif docker ps | grep -q acme-companion; then
        ACME_CONTAINER="acme-companion"
    else
        echo -e "${RED}acme-companion не найден${NC}"
        exit 1
    fi

    # Триггер обновления
    docker exec $ACME_CONTAINER /app/signal_le_service 2>/dev/null || \
        echo -e "${YELLOW}Используется автоматический график обновления${NC}"

    echo -e "${GREEN}✓ Обновление инициировано${NC}"
    echo "Проверьте логи: docker logs $ACME_CONTAINER"
}

fix_ssl_symlinks() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}Исправление SSL Симлинков${NC}"
    echo -e "${CYAN}========================================${NC}"

    if [ "${ENABLE_STARTTLS:-yes}" = "no" ]; then
        echo -e "${YELLOW}STARTTLS отключен - симлинки не требуются${NC}"
        return 0
    fi

    # Определение volume для сертификатов
    CERT_VOLUME=""
    if docker ps | grep -q nginx-proxy; then
        CERT_VOLUME=$(docker inspect nginx-proxy --format '{{range .Mounts}}{{if eq .Destination "/etc/nginx/certs"}}{{.Name}}{{end}}{{end}}' 2>/dev/null)
    fi

    if [ -z "$CERT_VOLUME" ]; then
        CERT_VOLUME="certs"
        echo -e "${YELLOW}nginx-proxy не найден, используется volume по умолчанию: $CERT_VOLUME${NC}"
    else
        echo -e "${BLUE}Найден volume для сертификатов: $CERT_VOLUME${NC}"
    fi

    CERT_PATH="/var/lib/docker/volumes/${CERT_VOLUME}/_data"

    # Проверка существования volume
    if [ ! -d "$CERT_PATH" ]; then
        echo -e "${RED}✗ Volume для сертификатов не найден: $CERT_PATH${NC}"
        return 1
    fi

    # Проверка существования папки с сертификатами
    if [ ! -d "$CERT_PATH/${RELAY_MYDOMAIN}" ]; then
        echo -e "${RED}✗ Папка с сертификатами не найдена: $CERT_PATH/${RELAY_MYDOMAIN}${NC}"
        echo -e "${YELLOW}Возможно, сертификат еще не получен. Подождите несколько минут.${NC}"
        return 1
    fi

    echo -e "${BLUE}Проверка сертификатов для домена: ${RELAY_MYDOMAIN}${NC}"

    # Проверка наличия файлов сертификатов
    if [ ! -f "$CERT_PATH/${RELAY_MYDOMAIN}/fullchain.pem" ]; then
        echo -e "${RED}✗ fullchain.pem не найден${NC}"
        return 1
    fi

    if [ ! -f "$CERT_PATH/${RELAY_MYDOMAIN}/key.pem" ]; then
        echo -e "${RED}✗ key.pem не найден${NC}"
        return 1
    fi

    echo -e "${GREEN}✓ Сертификаты найдены${NC}"

    # Создание симлинков
    echo -e "${YELLOW}Создание символических ссылок...${NC}"

    cd "$CERT_PATH" || exit 1

    # Удаление старых симлинков если существуют
    rm -f "${RELAY_MYDOMAIN}.crt" 2>/dev/null
    rm -f "${RELAY_MYDOMAIN}.key" 2>/dev/null
    rm -f "${RELAY_MYDOMAIN}.chain.pem" 2>/dev/null
    rm -f "${RELAY_MYDOMAIN}.dhparam.pem" 2>/dev/null

    # Создание новых симлинков
    ln -sf "./${RELAY_MYDOMAIN}/fullchain.pem" "${RELAY_MYDOMAIN}.crt"
    ln -sf "./${RELAY_MYDOMAIN}/key.pem" "${RELAY_MYDOMAIN}.key"
    ln -sf "./${RELAY_MYDOMAIN}/chain.pem" "${RELAY_MYDOMAIN}.chain.pem"

    # dhparam.pem может не существовать в старых установках
    if [ -f "./dhparam.pem" ]; then
        ln -sf "./dhparam.pem" "${RELAY_MYDOMAIN}.dhparam.pem"
    fi

    echo -e "${GREEN}✓ Символические ссылки созданы${NC}"

    # Проверка созданных симлинков
    echo ""
    echo -e "${BLUE}Созданные симлинки:${NC}"
    ls -lh "${RELAY_MYDOMAIN}".* 2>/dev/null | sed 's/^/  /'

    # Перезапуск smtp-relay
    echo ""
    echo -e "${YELLOW}Перезапуск smtp-relay...${NC}"
    docker restart smtp-relay >/dev/null 2>&1
    sleep 5

    # Проверка логов на ошибки TLS
    echo -e "${YELLOW}Проверка логов...${NC}"
    if docker logs smtp-relay 2>&1 | tail -20 | grep -qi "warning.*certificate\|TLS.*problem"; then
        echo -e "${RED}✗ Найдены предупреждения TLS в логах${NC}"
        docker logs smtp-relay 2>&1 | grep -i "tls\|certificate" | tail -5 | sed 's/^/  /'
    else
        echo -e "${GREEN}✓ Ошибок TLS не найдено${NC}"
    fi

    # Проверка STARTTLS
    echo ""
    echo -e "${YELLOW}Проверка STARTTLS...${NC}"
    if command -v openssl &>/dev/null; then
        if echo "QUIT" | timeout 3 openssl s_client -connect localhost:${SMTP_PORT:-6025} -starttls smtp -brief 2>/dev/null >/dev/null; then
            echo -e "${GREEN}✓ STARTTLS работает корректно${NC}"
        else
            echo -e "${RED}✗ STARTTLS не работает${NC}"
            echo -e "${YELLOW}Запустите ./manage.sh tls-check для детальной диагностики${NC}"
        fi
    else
        echo -e "${YELLOW}openssl не установлен - пропущена проверка STARTTLS${NC}"
    fi

    echo ""
    echo -e "${GREEN}Готово! ${NC}"
    echo -e "${BLUE}Для полной проверки запустите: ./manage.sh tls-check${NC}"
}

################################################################################
# Устранение Неполадок
################################################################################

health_check() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}Полная Проверка Здоровья${NC}"
    echo -e "${CYAN}========================================${NC}"

    echo -e "${YELLOW}1. Статус Контейнера${NC}"
    docker ps --filter "name=smtp-relay" --format "  {{.Names}}: {{.Status}}"

    echo ""
    echo -e "${YELLOW}2. Доступность Порта${NC}"
    if nc -z localhost ${SMTP_PORT:-6025}; then
        echo -e "  ${GREEN}✓ Порт ${SMTP_PORT:-6025} доступен${NC}"
    else
        echo -e "  ${RED}✗ Порт ${SMTP_PORT:-6025} недоступен${NC}"
    fi

    echo ""
    echo -e "${YELLOW}3. Конфигурация SASL${NC}"
    docker exec smtp-relay /opt/listpasswd.sh 2>/dev/null | wc -l | xargs echo "  Настроено пользователей:"

    echo ""
    echo -e "${YELLOW}4. Статус TLS${NC}"
    if [ "${ENABLE_STARTTLS:-yes}" = "yes" ]; then
        if docker exec smtp-relay test -f "/etc/nginx/certs/${RELAY_MYDOMAIN}.crt" 2>/dev/null; then
            echo -e "  ${GREEN}✓ Сертификат найден${NC}"
        else
            echo -e "  ${RED}✗ Сертификат не найден${NC}"
        fi
    else
        echo "  STARTTLS отключен"
    fi

    echo ""
    echo -e "${YELLOW}5. Очередь Почты${NC}"
    QUEUE_SIZE=$(docker exec smtp-relay sh -c 'find /var/spool/postfix/deferred -type f 2>/dev/null | wc -l')
    echo "  Размер очереди: $QUEUE_SIZE"

    echo ""
    echo -e "${YELLOW}6. Недавние Ошибки${NC}"
    ERROR_COUNT=$(docker exec smtp-relay sh -c 'grep -c -iE "(error|reject)" /var/log/mail.log 2>/dev/null' || echo "0")
    if [ "$ERROR_COUNT" -gt 0 ]; then
        echo -e "  ${YELLOW}⚠ $ERROR_COUNT ошибок в логе${NC}"
    else
        echo -e "  ${GREEN}✓ Недавних ошибок нет${NC}"
    fi

    echo ""
}

diagnose() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}Диагностика${NC}"
    echo -e "${CYAN}========================================${NC}"

    echo -e "${YELLOW}Запуск диагностики...${NC}"
    echo ""

    # Проверка статуса Postfix
    echo "1. Статус Postfix:"
    docker exec smtp-relay postfix status 2>&1 | sed 's/^/  /'

    echo ""
    echo "2. Проверка конфигурации Postfix:"
    docker exec smtp-relay postfix check 2>&1 | sed 's/^/  /'

    echo ""
    echo "3. SMTP возможности:"
    (echo "EHLO test"; sleep 1; echo "QUIT") | nc localhost ${SMTP_PORT:-6025} 2>&1 | sed 's/^/  /'

    echo ""
    echo "4. Недавние записи лога:"
    docker logs smtp-relay --tail=20 2>&1 | sed 's/^/  /'
}

fix_permissions() {
    echo -e "${YELLOW}Исправление прав на volume...${NC}"

    docker exec smtp-relay sh -c '
        chown -R postfix:postfix /var/spool/postfix
        chown -R postfix:postfix /data
        chmod 755 /var/spool/postfix
    ' 2>&1

    echo -e "${GREEN}✓ Права исправлены${NC}"
    echo "Может потребоваться перезапуск: $0 restart"
}

################################################################################
# Расширенные
################################################################################

clean_all() {
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}ВНИМАНИЕ: Это удалит ВСЕ данные!${NC}"
    echo -e "${RED}========================================${NC}"
    echo ""
    echo "Это удалит:"
    echo "  - Всех SASL пользователей"
    echo "  - Очередь почты"
    echo "  - Логи"
    echo ""
    read -p "Введите 'DELETE' для подтверждения: " confirm

    if [ "$confirm" != "DELETE" ]; then
        echo "Отменено"
        exit 0
    fi

    echo -e "${YELLOW}Остановка и удаление контейнеров...${NC}"
    docker compose -f $COMPOSE_FILE down -v

    echo -e "${GREEN}✓ Все данные удалены${NC}"
    echo "Запустите ./deploy.sh для повторного развертывания"
}

backup_data() {
    BACKUP_FILE="smtp-relay-backup-$(date +%Y%m%d-%H%M%S).tar.gz"

    echo -e "${YELLOW}Создание резервной копии...${NC}"

    # Создание директории для резервных копий
    mkdir -p backups

    # Резервное копирование конфигурации и volumes
    tar czf "backups/$BACKUP_FILE" .env configs/ 2>/dev/null || true

    # Резервное копирование базы данных SASL
    docker exec smtp-relay tar czf /tmp/sasl-backup.tar.gz /data 2>/dev/null || true
    docker cp smtp-relay:/tmp/sasl-backup.tar.gz backups/sasl-$(date +%Y%m%d-%H%M%S).tar.gz 2>/dev/null || true

    echo -e "${GREEN}✓ Резервная копия создана: backups/$BACKUP_FILE${NC}"
}

restore_data() {
    local backup_file="$1"

    if [ -z "$backup_file" ]; then
        echo "Доступные резервные копии:"
        ls -1 backups/*.tar.gz 2>/dev/null || echo "  Резервные копии не найдены"
        echo ""
        read -p "Введите файл резервной копии: " backup_file
    fi

    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}Файл резервной копии не найден: $backup_file${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Восстановление из резервной копии...${NC}"
    tar xzf "$backup_file"

    echo -e "${GREEN}✓ Резервная копия восстановлена${NC}"
    echo "Перезапустите сервисы: $0 restart"
}

open_shell() {
    echo -e "${CYAN}Открытие оболочки в контейнере smtp-relay${NC}"
    echo -e "${YELLOW}Введите 'exit' для выхода${NC}"
    echo ""
    docker exec -it smtp-relay /bin/sh
}

################################################################################
# Main
################################################################################

main() {
    detect_compose_file
    load_env

    case "${1:-help}" in
        start)
            start_service
            ;;
        stop)
            stop_service
            ;;
        restart)
            restart_service
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs "${2:-smtp-relay}" "$3"
            ;;
        users)
            list_users
            ;;
        add-user)
            add_user
            ;;
        del-user)
            delete_user
            ;;
        reset-password)
            reset_password
            ;;
        test)
            send_test "$2"
            ;;
        queue)
            show_queue
            ;;
        flush)
            flush_queue
            ;;
        stats)
            show_stats
            ;;
        tls-check)
            check_tls
            ;;
        tls-info)
            show_cert_info
            ;;
        cert-renew)
            renew_certificate
            ;;
        fix-ssl-symlinks)
            fix_ssl_symlinks
            ;;
        health)
            health_check
            ;;
        diagnose)
            diagnose
            ;;
        fix-permissions)
            fix_permissions
            ;;
        clean)
            clean_all
            ;;
        backup)
            backup_data
            ;;
        restore)
            restore_data "$2"
            ;;
        shell)
            open_shell
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Неизвестная команда: $1${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
