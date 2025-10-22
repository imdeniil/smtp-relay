#!/bin/bash

#########################################
# SSL Symlinks Health Check
# Проверяет наличие и корректность SSL симлинков
#########################################

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Получаем домен из переменной окружения
RELAY_MYDOMAIN="${RELAY_MYDOMAIN:-keemor.su}"

# Определяем volume для сертификатов
CERT_VOLUME=""
if docker ps | grep -q nginx-proxy; then
    CERT_VOLUME=$(docker inspect nginx-proxy --format '{{range .Mounts}}{{if eq .Destination "/etc/nginx/certs"}}{{.Name}}{{end}}{{end}}' 2>/dev/null)
fi

if [ -z "$CERT_VOLUME" ]; then
    echo -e "${YELLOW}nginx-proxy не найден, используем volume 'certs' по умолчанию${NC}"
    CERT_VOLUME="certs"
fi

CERT_PATH="/var/lib/docker/volumes/${CERT_VOLUME}/_data"

# Проверяем существует ли директория с сертификатами
if [ ! -d "$CERT_PATH" ]; then
    echo -e "${RED}❌ Директория сертификатов не найдена: $CERT_PATH${NC}"
    exit 1
fi

# Проверяем существует ли папка с сертификатами домена
if [ ! -d "$CERT_PATH/$RELAY_MYDOMAIN" ]; then
    echo -e "${YELLOW}⚠️  Сертификаты для $RELAY_MYDOMAIN еще не созданы${NC}"
    exit 0
fi

# Проверяем существование основных файлов сертификатов
REQUIRED_FILES=(
    "$CERT_PATH/$RELAY_MYDOMAIN/fullchain.pem"
    "$CERT_PATH/$RELAY_MYDOMAIN/key.pem"
    "$CERT_PATH/$RELAY_MYDOMAIN/chain.pem"
)

MISSING_FILES=0
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}❌ Файл не найден: $file${NC}"
        MISSING_FILES=$((MISSING_FILES + 1))
    fi
done

if [ $MISSING_FILES -gt 0 ]; then
    echo -e "${RED}❌ Отсутствуют $MISSING_FILES файлов сертификата${NC}"
    exit 1
fi

# Проверяем симлинки
SYMLINKS_OK=1

check_symlink() {
    local link_name=$1
    local target=$2

    if [ -L "$CERT_PATH/$link_name" ]; then
        local current_target=$(readlink "$CERT_PATH/$link_name")
        if [ "$current_target" = "$target" ]; then
            echo -e "${GREEN}✓${NC} $link_name -> $target"
            return 0
        else
            echo -e "${YELLOW}⚠${NC}  $link_name указывает на $current_target (ожидается $target)"
            return 1
        fi
    else
        echo -e "${RED}✗${NC} $link_name отсутствует"
        return 1
    fi
}

echo "Проверка SSL симлинков для $RELAY_MYDOMAIN..."
echo ""

if ! check_symlink "${RELAY_MYDOMAIN}.crt" "./${RELAY_MYDOMAIN}/fullchain.pem"; then
    SYMLINKS_OK=0
fi

if ! check_symlink "${RELAY_MYDOMAIN}.key" "./${RELAY_MYDOMAIN}/key.pem"; then
    SYMLINKS_OK=0
fi

if ! check_symlink "${RELAY_MYDOMAIN}.chain.pem" "./${RELAY_MYDOMAIN}/chain.pem"; then
    SYMLINKS_OK=0
fi

if ! check_symlink "${RELAY_MYDOMAIN}.dhparam.pem" "./dhparam.pem"; then
    SYMLINKS_OK=0
fi

echo ""

if [ $SYMLINKS_OK -eq 0 ]; then
    echo -e "${RED}❌ Некоторые симлинки отсутствуют или некорректны${NC}"
    echo -e "${YELLOW}📝 Запустите: ./manage.sh fix-ssl-symlinks${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Все SSL симлинки корректны${NC}"
    exit 0
fi
