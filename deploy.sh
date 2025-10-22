#!/bin/bash

################################################################################
# Скрипт Автоматического Развертывания SMTP Relay
# Поддерживает 2 режима развертывания:
#   1. Полный Стек (nginx-proxy + acme-companion + smtp-relay)
#   2. Только SMTP (интеграция с существующим nginx-proxy)
#
# Возможности:
#   - Поддержка STARTTLS (опционально)
#   - Автоматические сертификаты Let's Encrypt
#   - SASL аутентификация
#   - Интерактивная настройка
################################################################################

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Режим развертывания
DEPLOY_MODE=""
USE_STARTTLS="yes"
COMPOSE_FILE=""

################################################################################
# Вспомогательные Функции
################################################################################

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
# Функции Конфигурации
################################################################################

select_deployment_mode() {
    print_header "Выбор Режима Развертывания"

    echo "1) Полный Стек - Установить nginx-proxy + acme-companion + smtp-relay"
    echo "2) Только SMTP  - Интеграция с существующим nginx-proxy"
    echo ""
    read -p "Выберите режим (1 или 2): " mode_choice

    case $mode_choice in
        1)
            DEPLOY_MODE="full"
            COMPOSE_FILE="docker-compose.full.yml"
            print_info "Режим: Развертывание Полного Стека"
            ;;
        2)
            DEPLOY_MODE="smtp-only"
            COMPOSE_FILE="docker-compose.smtp-only.yml"
            print_info "Режим: Развертывание Только SMTP"
            ;;
        *)
            print_error "Неверный выбор"
            exit 1
            ;;
    esac
    echo ""
}

select_starttls_mode() {
    print_header "Настройка STARTTLS"

    echo "Хотите включить STARTTLS (TLS шифрование)?"
    echo "1) Да - Включить STARTTLS с сертификатами Let's Encrypt"
    echo "2) Нет - Обычный SMTP без TLS"
    echo ""
    read -p "Выберите опцию (1 или 2): " tls_choice

    case $tls_choice in
        1)
            USE_STARTTLS="yes"
            print_success "STARTTLS будет включен"
            ;;
        2)
            USE_STARTTLS="no"
            print_warning "STARTTLS будет отключен"
            ;;
        *)
            print_error "Неверный выбор"
            exit 1
            ;;
    esac
    echo ""
}

create_env_file() {
    print_header "Настройка Конфигурации"

    if [ -f .env ]; then
        print_warning "Файл .env уже существует"
        read -p "Хотите перезаписать его? (yes/no): " overwrite
        if [ "$overwrite" != "yes" ]; then
            print_info "Используется существующий файл .env"
            return
        fi
    fi

    echo "Введите ваши конфигурационные данные:"
    echo ""

    read -p "Домен SMTP Relay (например, relay.example.com): " relay_domain
    read -p "Имя хоста SMTP Relay (по умолчанию: ${relay_domain}): " relay_hostname
    relay_hostname=${relay_hostname:-$relay_domain}

    read -p "Email Postmaster: " postmaster_email

    echo ""
    echo "Настройка Upstream SMTP сервера:"
    read -p "Upstream SMTP хост (например, [smtp.gmail.com]:587): " upstream_host
    read -p "Upstream SMTP логин: " upstream_login
    read -sp "Upstream SMTP пароль: " upstream_password
    echo ""

    read -p "Upstream требует TLS? (yes/no, по умолчанию: no): " upstream_tls
    upstream_tls=${upstream_tls:-no}

    echo ""
    read -p "SASL имя пользователя (по умолчанию: ${upstream_login}): " sasl_username
    sasl_username=${sasl_username:-$upstream_login}

    read -sp "SASL пароль (по умолчанию: такой же как upstream): " sasl_password
    echo ""
    sasl_password=${sasl_password:-$upstream_password}

    read -p "Email для Let's Encrypt: " letsencrypt_email

    # Создание файла .env
    cat > .env << EOF
# Конфигурация SMTP Relay Сервера
RELAY_MYHOSTNAME=${relay_hostname}
RELAY_MYDOMAIN=${relay_domain}
RELAY_POSTMASTER=${postmaster_email}

# Upstream SMTP Сервер
RELAY_HOST=${upstream_host}
RELAY_LOGIN=${upstream_login}
RELAY_PASSWORD=${upstream_password}
RELAY_USE_TLS=${upstream_tls}

# SASL Аутентификация (для подключения к ВАШЕМУ relay)
SASL_USERNAME=${sasl_username}
SASL_PASSWORD=${sasl_password}

# Настройки Let's Encrypt
LETSENCRYPT_EMAIL=${letsencrypt_email}

# Конфигурация STARTTLS
ENABLE_STARTTLS=${USE_STARTTLS}

# Конфигурация Порта
SMTP_PORT=6025
EOF

    print_success "Файл .env создан"
    echo ""
}

################################################################################
# Предварительные Проверки
################################################################################

check_requirements() {
    print_header "Проверка Требований"

    # Проверка Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker не установлен"
        exit 1
    fi
    print_success "Docker найден"

    # Проверка Docker Compose
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose не установлен"
        exit 1
    fi
    print_success "Docker Compose найден"

    # Проверка прав
    if [ "$EUID" -ne 0 ] && ! groups | grep -q docker; then
        print_warning "Возможно потребуется запуск от root или добавление пользователя в группу docker"
    fi

    echo ""
}

check_existing_nginx_proxy() {
    if [ "$DEPLOY_MODE" = "smtp-only" ]; then
        print_header "Проверка Существующего nginx-proxy"

        if ! docker ps | grep -q nginx-proxy; then
            print_error "Контейнер nginx-proxy не найден"
            print_info "Пожалуйста, установите nginx-proxy сначала или выберите режим Полного Стека"
            exit 1
        fi
        print_success "nginx-proxy найден"

        # Проверка acme-companion
        if ! docker ps | grep -qE "nginx-proxy-acme|acme-companion"; then
            print_error "acme-companion не найден"
            print_info "STARTTLS требует acme-companion для сертификатов"
            exit 1
        fi
        print_success "acme-companion найден"

        # Определение volume для сертификатов
        CERT_VOLUME=$(docker inspect nginx-proxy --format '{{range .Mounts}}{{if eq .Destination "/etc/nginx/certs"}}{{.Name}}{{end}}{{end}}')
        if [ -z "$CERT_VOLUME" ]; then
            CERT_VOLUME="certs"
        fi
        print_info "Volume для сертификатов: $CERT_VOLUME"

        # Определение сети
        NETWORK_NAME=$(docker inspect nginx-proxy --format '{{range $net, $v := .NetworkSettings.Networks}}{{$net}}{{end}}' | head -1)
        if [ -z "$NETWORK_NAME" ]; then
            NETWORK_NAME="proxy"
        fi
        print_info "Сеть: $NETWORK_NAME"

        echo ""
    fi
}

check_dns() {
    print_header "Проверка Конфигурации DNS"

    source .env

    # Получение IP сервера
    SERVER_IP=$(curl -s ifconfig.me || curl -s icanhazip.com)
    print_info "IP сервера: $SERVER_IP"

    # Проверка DNS
    DOMAIN_IP=$(dig +short $RELAY_MYDOMAIN | head -n1)
    print_info "IP домена: $DOMAIN_IP"

    if [ "$SERVER_IP" != "$DOMAIN_IP" ]; then
        print_warning "Несоответствие DNS! Домен указывает на $DOMAIN_IP, но сервер $SERVER_IP"
        print_warning "Проверка Let's Encrypt может не пройти"
        read -p "Продолжить в любом случае? (yes/no): " continue_choice
        if [ "$continue_choice" != "yes" ]; then
            exit 1
        fi
    else
        print_success "DNS настроен правильно"
    fi

    echo ""
}

################################################################################
# Функции Развертывания
################################################################################

setup_network() {
    if [ "$DEPLOY_MODE" = "full" ]; then
        print_info "Создание сети proxy..."
        docker network create proxy 2>/dev/null || print_warning "Сеть 'proxy' уже существует"
        print_success "Сеть готова"
    fi
}

deploy_services() {
    print_header "Развертывание Сервисов"

    # Экспортируем переменные из .env для docker compose
    set -a
    source .env
    set +a

    # Если режим smtp-only, нужно подставить правильное имя volume для сертификатов
    if [ "$DEPLOY_MODE" = "smtp-only" ] && [ ! -z "$CERT_VOLUME" ]; then
        print_info "Настройка volume для сертификатов: $CERT_VOLUME"
        # Создаем временный docker-compose с правильным именем volume
        # Заменяем ВСЕ упоминания volume 'certs' на правильное имя
        cat configs/$COMPOSE_FILE | \
            sed "s/- certs:/- ${CERT_VOLUME}:/g" | \
            sed "s/certs:$/${CERT_VOLUME}:/g" | \
            sed "s/# *name: your_nginx_certs_volume_name/name: ${CERT_VOLUME}/g" \
            > /tmp/docker-compose-temp.yml
        COMPOSE_FILE_TO_USE="/tmp/docker-compose-temp.yml"
    else
        COMPOSE_FILE_TO_USE="configs/$COMPOSE_FILE"
    fi

    print_info "Запуск контейнеров..."

    # Если используем временный файл, указываем правильную базовую директорию
    if [ "$COMPOSE_FILE_TO_USE" = "/tmp/docker-compose-temp.yml" ]; then
        docker compose --project-directory configs/ -f $COMPOSE_FILE_TO_USE up -d
    else
        docker compose -f $COMPOSE_FILE_TO_USE up -d
    fi

    # Удаляем временный файл
    rm -f /tmp/docker-compose-temp.yml

    print_success "Контейнеры запущены"
    sleep 5
    echo ""
}

wait_for_certificate() {
    if [ "$USE_STARTTLS" = "no" ]; then
        return
    fi

    print_header "Ожидание Сертификата Let's Encrypt"

    source .env

    local max_attempts=60
    local attempt=0

    # Проверяем наличие папки с сертификатами (без симлинка)
    local cert_dir_path=""

    # Определение volume для сертификатов
    CERT_VOLUME=""
    if docker ps | grep -q nginx-proxy; then
        CERT_VOLUME=$(docker inspect nginx-proxy --format '{{range .Mounts}}{{if eq .Destination "/etc/nginx/certs"}}{{.Name}}{{end}}{{end}}' 2>/dev/null)
    fi

    if [ -z "$CERT_VOLUME" ]; then
        CERT_VOLUME="certs"
    fi

    print_info "Это может занять 1-3 минуты..."
    echo ""

    while [ $attempt -lt $max_attempts ]; do
        # Проверяем наличие файлов сертификатов в папке
        if [ -f "/var/lib/docker/volumes/${CERT_VOLUME}/_data/${RELAY_MYDOMAIN}/fullchain.pem" ]; then
            echo ""
            print_success "Сертификат получен!"

            # Показать информацию о сертификате
            print_info "Детали сертификата:"
            if command -v openssl &>/dev/null; then
                openssl x509 -in "/var/lib/docker/volumes/${CERT_VOLUME}/_data/${RELAY_MYDOMAIN}/fullchain.pem" -noout -subject -dates 2>/dev/null | sed 's/^/  /'
            else
                ls -lh "/var/lib/docker/volumes/${CERT_VOLUME}/_data/${RELAY_MYDOMAIN}/fullchain.pem" 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
            fi

            # Создание симлинков для сертификатов
            echo ""
            print_info "Создание символических ссылок для Postfix..."

            cd "/var/lib/docker/volumes/${CERT_VOLUME}/_data" || return 1

            # Удаление старых симлинков если существуют
            rm -f "${RELAY_MYDOMAIN}.crt" 2>/dev/null
            rm -f "${RELAY_MYDOMAIN}.key" 2>/dev/null
            rm -f "${RELAY_MYDOMAIN}.chain.pem" 2>/dev/null
            rm -f "${RELAY_MYDOMAIN}.dhparam.pem" 2>/dev/null

            # Создание новых симлинков
            ln -sf "./${RELAY_MYDOMAIN}/fullchain.pem" "${RELAY_MYDOMAIN}.crt"
            ln -sf "./${RELAY_MYDOMAIN}/key.pem" "${RELAY_MYDOMAIN}.key"
            ln -sf "./${RELAY_MYDOMAIN}/chain.pem" "${RELAY_MYDOMAIN}.chain.pem"

            if [ -f "./dhparam.pem" ]; then
                ln -sf "./dhparam.pem" "${RELAY_MYDOMAIN}.dhparam.pem"
            fi

            print_success "Симлинки созданы"

            return 0
        fi

        if [ $((attempt % 10)) -eq 0 ] && [ $attempt -gt 0 ]; then
            echo ""
            print_info "Все еще ожидаем... (попытка $attempt/$max_attempts)"
        fi

        attempt=$((attempt + 1))
        echo -n "."
        sleep 3
    done

    echo ""
    print_error "Не удалось получить сертификат в течение тайм-аута"
    print_warning "Проверьте логи: docker logs nginx-proxy-acme"
    return 1
}

create_sasl_user() {
    print_header "Создание SASL Пользователя"

    source .env

    sleep 3

    print_info "Создание пользователя: $SASL_USERNAME"

    # Создаем файл с SASL credentials на хосте
    # Формат: USERNAME PASSWORD (разделены пробелом)
    echo "$SASL_USERNAME $SASL_PASSWORD" > /tmp/sasl_passwd_temp

    # Копируем файл в контейнер
    docker cp /tmp/sasl_passwd_temp smtp-relay:/etc/postfix/client_sasl_passwd

    # Удаляем временный файл
    rm -f /tmp/sasl_passwd_temp

    # Перезапускаем контейнер для обработки SASL credentials
    print_info "Перезапуск контейнера для регистрации SASL пользователя..."
    docker restart smtp-relay > /dev/null 2>&1

    # Ждем запуска
    sleep 8

    # Проверяем что пользователь создан
    if docker logs smtp-relay 2>&1 | grep -q "registered user.*$SASL_USERNAME"; then
        print_success "SASL пользователь создан"
    else
        print_warning "Не удалось подтвердить создание пользователя (проверьте логи)"
    fi

    echo ""
    print_info "SASL пользователи:"
    docker exec smtp-relay /opt/listpasswd.sh 2>/dev/null | sed 's/^/  /'

    echo ""
}

stop_web_helper() {
    if [ "$DEPLOY_MODE" = "smtp-only" ] && [ "$USE_STARTTLS" = "yes" ]; then
        print_info "Остановка вспомогательного веб-контейнера..."
        docker stop smtp-relay-web 2>/dev/null || true
        print_success "Веб-помощник остановлен"
    fi
}

################################################################################
# Функции Верификации
################################################################################

verify_deployment() {
    print_header "Верификация Развертывания"

    source .env

    # Проверка статуса контейнера
    if docker ps | grep -q smtp-relay; then
        print_success "Контейнер smtp-relay запущен"
    else
        print_error "Контейнер smtp-relay не запущен"
        return 1
    fi

    # Проверка порта
    if nc -z localhost ${SMTP_PORT:-6025} 2>/dev/null; then
        print_success "SMTP порт ${SMTP_PORT:-6025} доступен"
    else
        print_error "SMTP порт ${SMTP_PORT:-6025} недоступен"
        return 1
    fi

    # Проверка STARTTLS
    if [ "$USE_STARTTLS" = "yes" ]; then
        print_info "Тестирование STARTTLS..."
        if command -v openssl &>/dev/null; then
            echo "QUIT" | timeout 3 openssl s_client -connect localhost:${SMTP_PORT:-6025} -starttls smtp -brief 2>/dev/null >/dev/null
            if [ $? -eq 0 ]; then
                print_success "STARTTLS работает"
            else
                print_warning "Тест STARTTLS не прошел (может потребоваться больше времени для инициализации)"
            fi
        else
            print_warning "openssl не установлен - пропущена проверка STARTTLS (используйте: ./manage.sh tls-check)"
        fi
    else
        print_info "STARTTLS отключен"
    fi

    echo ""
}

################################################################################
# Основной Процесс Развертывания
################################################################################

show_summary() {
    source .env

    print_header "Развертывание Завершено!"

    echo -e "${GREEN}Ваш SMTP Relay готов к использованию:${NC}"
    echo ""
    echo "  Сервер:    $RELAY_MYHOSTNAME"
    echo "  Порт:      ${SMTP_PORT:-6025}"
    if [ "$USE_STARTTLS" = "yes" ]; then
        echo "  Безопасность: STARTTLS (TLS шифрование)"
    else
        echo "  Безопасность: Нет (обычный SMTP)"
    fi
    echo "  Имя пользователя: $SASL_USERNAME"
    echo "  Пароль:    $SASL_PASSWORD"
    echo ""

    print_info "Полезные Команды:"
    echo "  ./manage.sh status              # Проверить статус"
    echo "  ./manage.sh logs                # Просмотр логов"
    echo "  ./manage.sh test <email>        # Отправить тестовое письмо"
    echo "  ./manage.sh tls-check           # Проверить STARTTLS"
    echo ""

    if [ "$DEPLOY_MODE" = "full" ]; then
        print_info "nginx-proxy доступен на портах 80 и 443"
        print_info "Вы можете добавлять другие сервисы с автоматическими SSL сертификатами!"
    fi

    echo ""
}

################################################################################
# Главный Скрипт
################################################################################

main() {
    clear
    print_header "Автоматическое Развертывание SMTP Relay"

    # Интерактивная настройка
    select_deployment_mode
    select_starttls_mode
    create_env_file

    # Предварительные проверки
    check_requirements
    check_existing_nginx_proxy

    if [ "$USE_STARTTLS" = "yes" ]; then
        check_dns
    fi

    # Подтверждение развертывания
    print_header "Готово к Развертыванию"
    echo "Режим развертывания: $DEPLOY_MODE"
    echo "STARTTLS:            $USE_STARTTLS"
    echo "Файл Compose:        $COMPOSE_FILE"
    echo ""
    read -p "Продолжить развертывание? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        print_warning "Развертывание отменено"
        exit 0
    fi

    # Развертывание
    setup_network
    deploy_services

    if [ "$USE_STARTTLS" = "yes" ]; then
        wait_for_certificate
    fi

    create_sasl_user
    stop_web_helper

    # Верификация
    verify_deployment

    # Показать итоговую информацию
    show_summary
}

# Запуск main
main "$@"
