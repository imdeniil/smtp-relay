# Решение Проблемы SSL Сертификатов для STARTTLS

## Проблема

При включенном STARTTLS relay сервер может выдавать ошибку:
```
warning: cannot get RSA certificate from file "/etc/nginx/certs/keemor.su.crt": disabling TLS support
```

Это приводит к ошибкам подключения:
```
MailKit.Net.Smtp.SmtpCommandException: 4.7.0 TLS not available due to local problem
```

## Причина

**acme-companion** (Let's Encrypt) создает сертификаты в следующей структуре:
```
/var/lib/docker/volumes/nginx_certs/_data/
├── keemor.su/              # Папка с сертификатами
│   ├── cert.pem
│   ├── chain.pem
│   ├── fullchain.pem
│   └── key.pem
```

Но **Postfix** в контейнере smtp-relay ожидает найти сертификаты по следующим путям:
```
/etc/nginx/certs/keemor.su.crt  -> должен указывать на ./keemor.su/fullchain.pem
/etc/nginx/certs/keemor.su.key  -> должен указывать на ./keemor.su/key.pem
```

## Решение

### Автоматическое (Рекомендуется)

Используйте команду manage.sh для автоматического создания симлинков:

```bash
./manage.sh fix-ssl-symlinks
```

Эта команда:
1. Проверит наличие сертификатов в volume
2. Создаст необходимые символические ссылки
3. Перезапустит smtp-relay контейнер
4. Проверит работоспособность STARTTLS

### Ручное Решение

Если автоматическое решение не работает, выполните вручную:

```bash
# 1. Определить имя volume для сертификатов
CERT_VOLUME=$(docker inspect nginx-proxy --format '{{range .Mounts}}{{if eq .Destination "/etc/nginx/certs"}}{{.Name}}{{end}}{{end}}')
echo "Cert volume: $CERT_VOLUME"

# 2. Определить ваш домен из .env
source .env
echo "Domain: $RELAY_MYDOMAIN"

# 3. Проверить наличие сертификатов
ls -la /var/lib/docker/volumes/${CERT_VOLUME}/_data/${RELAY_MYDOMAIN}/

# 4. Создать символические ссылки
cd /var/lib/docker/volumes/${CERT_VOLUME}/_data/
ln -sf ./${RELAY_MYDOMAIN}/fullchain.pem ${RELAY_MYDOMAIN}.crt
ln -sf ./${RELAY_MYDOMAIN}/key.pem ${RELAY_MYDOMAIN}.key
ln -sf ./${RELAY_MYDOMAIN}/chain.pem ${RELAY_MYDOMAIN}.chain.pem
ln -sf ./dhparam.pem ${RELAY_MYDOMAIN}.dhparam.pem

# 5. Проверить созданные ссылки
ls -la | grep "${RELAY_MYDOMAIN}\."

# 6. Перезапустить smtp-relay
docker restart smtp-relay

# 7. Проверить логи
docker logs smtp-relay 2>&1 | grep -i tls

# 8. Проверить STARTTLS
echo "QUIT" | openssl s_client -connect ${RELAY_MYHOSTNAME}:${SMTP_PORT:-6025} -starttls smtp
```

## Проверка Результата

### 1. Проверка логов

После перезапуска в логах НЕ должно быть ошибок TLS:
```bash
docker logs smtp-relay 2>&1 | grep -E "(TLS|certificate)" | tail -20
```

**Хорошо:** Логи без ошибок или только INFO сообщения
**Плохо:** `warning: cannot get RSA certificate`, `TLS not available`

### 2. Проверка STARTTLS соединения

```bash
./manage.sh tls-check
```

Должно показать:
```
✓ STARTTLS работает
Subject: CN = keemor.su
Issuer: C = US, O = Let's Encrypt
Verify return code: 0 (ok)
```

### 3. Тест отправки письма

```bash
./manage.sh test your-email@example.com
```

Письмо должно отправиться успешно без ошибок TLS.

## Когда Запускать Исправление

### Сразу После Развертывания

Если вы используете режим **smtp-only** (интеграция с существующим nginx-proxy), запустите исправление после получения сертификата:

```bash
./deploy.sh
# Дождитесь получения сертификата
./manage.sh fix-ssl-symlinks
./manage.sh tls-check
```

### После Обновления Сертификатов

Сертификаты Let's Encrypt автоматически обновляются каждые 60-90 дней. После обновления **может** потребоваться пересоздание симлинков:

```bash
# Проверить дату последнего обновления сертификата
./manage.sh tls-info

# Если STARTTLS перестал работать
./manage.sh fix-ssl-symlinks
```

### Симптомы Проблемы

Запустите исправление, если видите:
- ❌ Ошибки "TLS not available" в логах smtp-relay
- ❌ `./manage.sh tls-check` показывает ошибку
- ❌ Клиенты не могут подключиться с STARTTLS
- ❌ `./manage.sh status` показывает "STARTTLS не отвечает"

## Предотвращение Проблемы

### При Развертывании

Скрипт `deploy.sh` был обновлен и теперь автоматически создает симлинки после получения сертификата. Если вы развертываете заново:

```bash
./deploy.sh
# Симлинки создаются автоматически
```

### Добавить в Cron (Опционально)

Для автоматической проверки и исправления симлинков можно добавить задачу в cron:

```bash
# Редактировать crontab
crontab -e

# Добавить строку (проверка каждый день в 3:00)
0 3 * * * cd /root/rl && ./manage.sh fix-ssl-symlinks >/dev/null 2>&1
```

## Технические Детали

### Почему Это Происходит?

1. **nginx-proxy/acme-companion** создает структуру:
   ```
   certs/
   └── domain.com/
       ├── cert.pem       # Сертификат
       ├── chain.pem      # Цепочка CA
       ├── fullchain.pem  # cert.pem + chain.pem
       └── key.pem        # Приватный ключ
   ```

2. **Другие сервисы** (например nginx) используют эту структуру через переменные окружения:
   ```
   CERT_NAME=domain.com
   # nginx-proxy автоматически находит certs/domain.com/*
   ```

3. **Postfix в smtp-relay** настроен на прямые пути:
   ```
   POSTCONF_smtpd_tls_cert_file=/etc/nginx/certs/domain.com.crt
   POSTCONF_smtpd_tls_key_file=/etc/nginx/certs/domain.com.key
   ```

4. **Решение** - создать симлинки для совместимости:
   ```
   domain.com.crt -> domain.com/fullchain.pem
   domain.com.key -> domain.com/key.pem
   ```

### Альтернативное Решение

Вместо симлинков можно было бы:
- Изменить docker-compose чтобы мапить сертификаты по-другому
- Использовать init-скрипт внутри контейнера
- Форкнуть turgon37/smtp-relay и добавить поддержку структуры acme-companion

Но **симлинки** - это самое простое и надежное решение, которое:
- ✅ Не требует изменения docker image
- ✅ Не требует сложных монтирований
- ✅ Работает с существующей инфраструктурой
- ✅ Легко автоматизируется

## Дополнительная Помощь

Если проблема не решается:

1. Проверьте права доступа:
```bash
docker exec smtp-relay ls -la /etc/nginx/certs/
```

2. Проверьте volume монтирование:
```bash
docker inspect smtp-relay | grep -A 10 "Mounts"
```

3. Проверьте конфигурацию Postfix:
```bash
docker exec smtp-relay postconf | grep tls_cert
docker exec smtp-relay postconf | grep tls_key
```

4. Включите debug логирование:
```bash
docker exec smtp-relay postconf -e "smtpd_tls_loglevel=4"
docker restart smtp-relay
docker logs smtp-relay -f
```

## Связанные Команды

```bash
./manage.sh fix-ssl-symlinks  # Автоматическое исправление
./manage.sh tls-check         # Проверка STARTTLS
./manage.sh tls-info          # Информация о сертификате
./manage.sh status            # Общий статус (включая TLS)
./manage.sh health            # Полная проверка здоровья
./manage.sh diagnose          # Расширенная диагностика
```

---

**Версия:** 1.0
**Дата:** 2025-10-22
**Статус:** Проверено ✅
