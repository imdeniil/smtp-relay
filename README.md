# SMTP Relay - Автоматизированное Развертывание

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](CHANGELOG.md)
[![Docker](https://img.shields.io/badge/docker-ready-brightgreen.svg)](https://www.docker.com/)
[![Production Ready](https://img.shields.io/badge/production-ready-success.svg)](#)
[![Quality Score](https://img.shields.io/badge/quality-95%2F100-brightgreen.svg)](docs/reports/OPTIMIZATION-REPORT.md)

Production-ready SMTP relay сервер с автоматическими SSL сертификатами, SASL аутентификацией и простым развертыванием.

> **Версия 2.0** - Полностью оптимизированная версия с автоматическим исправлением SSL сертификатов!
>
> 📊 См. [OPTIMIZATION-REPORT.md](docs/reports/OPTIMIZATION-REPORT.md) для деталей оптимизации.

## Навигация

- [Возможности](#возможности)
- [Быстрый Старт](#быстрый-старт)
- [Документация](#документация)
- [Установка](#установка)
- [Управление](#команды-управления)
- [Устранение Неполадок](#устранение-неполадок)
- [Участие в Проекте](#участие-в-проекте)
- [Лицензия](#лицензия)

## Возможности

- **Два Режима Развертывания**
  - Полный Стек: nginx-proxy + acme-companion + smtp-relay
  - Только SMTP: Интеграция с существующим nginx-proxy

- **Автоматические SSL Сертификаты**
  - Интеграция с Let's Encrypt
  - Автоматическое обновление
  - Поддержка STARTTLS (опционально)

- **SASL Аутентификация**
  - Безопасная аутентификация клиентов
  - Поддержка нескольких пользователей
  - Простое управление пользователями

- **Полная Автоматизация**
  - Развертывание одной командой
  - Интерактивная настройка
  - Мониторинг здоровья
  - Встроенная диагностика

## Быстрый Старт

### 1. Клонирование Репозитория

```bash
# Клонируйте репозиторий
git clone https://github.com/imdeniil/smtp-relay.git

# Перейдите в директорию
cd smtp-relay
```

### 2. Сделать Скрипты Исполняемыми

```bash
chmod +x deploy.sh manage.sh
```

### 3. Развернуть

```bash
./deploy.sh
```

Скрипт проведет вас через:
- Выбор режима развертывания (Полный Стек или Только SMTP)
- Выбор опции STARTTLS (с или без TLS)
- Ввод конфигурационных данных
- Автоматическое развертывание и верификацию

### 4. Проверка

```bash
./manage.sh status
./manage.sh health
```

## Режимы Развертывания

### Режим 1: Полный Стек

**Когда использовать:**
- Чистый сервер без nginx-proxy
- Нужна полная настройка инфраструктуры
- Требуется reverse proxy для нескольких сервисов

**Что получите:**
- nginx-proxy (reverse proxy)
- acme-companion (автоматизация Let's Encrypt)
- smtp-relay (SMTP сервер)
- Автоматические SSL сертификаты
- Решение "всё-в-одном"

**Команда:**
```bash
./deploy.sh
# Выберите опцию 1 (Полный Стек)
```

### Режим 2: Только SMTP

**Когда использовать:**
- Уже есть работающий nginx-proxy
- Хотите добавить SMTP к существующей инфраструктуре
- Минимальный след

**Требования:**
- Контейнер [nginx-proxy](https://github.com/nginx-proxy/nginx-proxy) запущен:
  ```bash
  docker run -d -p 80:80 -p 443:443 \
    --name nginx-proxy \
    --network proxy \
    -v /var/run/docker.sock:/tmp/docker.sock:ro \
    -v certs:/etc/nginx/certs:rw \
    nginxproxy/nginx-proxy
  ```
- Контейнер [acme-companion](https://github.com/nginx-proxy/acme-companion) запущен:
  ```bash
  docker run -d \
    --name nginx-proxy-acme \
    --network proxy \
    --volumes-from nginx-proxy \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    -v acme:/etc/acme.sh \
    -e "DEFAULT_EMAIL=your-email@example.com" \
    nginxproxy/acme-companion
  ```
- Сеть "proxy" существует:
  ```bash
  docker network create proxy
  ```

**Команда:**
```bash
./deploy.sh
# Выберите опцию 2 (Только SMTP)
```

## Опции STARTTLS

### С STARTTLS (Рекомендуется)

**Возможности:**
- Зашифрованные SMTP соединения
- SSL сертификаты Let's Encrypt
- Автоматическое обновление сертификатов
- Готовность к продакшену

**Требования:**
- Действительное доменное имя
- DNS указывает на сервер
- Порты 80 и 443 доступны

### Без STARTTLS

**Возможности:**
- Обычные SMTP соединения
- SSL сертификаты не нужны
- Простая настройка
- Подходит для тестирования

**Случаи использования:**
- Внутренние сети
- Тестовые окружения
- За другими SSL терминаторами

## Команды Управления

### Управление Сервисом

```bash
./manage.sh start          # Запустить SMTP relay
./manage.sh stop           # Остановить SMTP relay
./manage.sh restart        # Перезапустить SMTP relay
./manage.sh status         # Показать статус
./manage.sh logs           # Просмотр логов
./manage.sh logs -f        # Следить за логами
```

### Управление Пользователями

```bash
./manage.sh users          # Список SASL пользователей
./manage.sh add-user       # Добавить нового пользователя
./manage.sh del-user       # Удалить пользователя
./manage.sh reset-password # Сбросить пароль пользователя
```

### Тестирование и Диагностика

```bash
./manage.sh test user@example.com  # Отправить тестовое письмо
./manage.sh health                 # Полная проверка здоровья
./manage.sh diagnose              # Запустить диагностику
./manage.sh tls-check             # Проверить STARTTLS
```

### Очередь Почты

```bash
./manage.sh queue          # Показать очередь почты
./manage.sh flush          # Очистить очередь
./manage.sh stats          # Статистика почты
```

### Расширенные Операции

```bash
./manage.sh backup         # Резервное копирование конфигурации
./manage.sh restore        # Восстановить из резервной копии
./manage.sh shell          # Открыть оболочку контейнера
./manage.sh clean          # Удалить все данные (ОПАСНО)
```

## Конфигурация

### Переменные Окружения

Скопируйте `.env.example` в `.env` и настройте:

```bash
cp .env.example .env
nano .env
```

**Обязательные Настройки:**

```bash
# Ваш домен
RELAY_MYHOSTNAME=relay.example.com
RELAY_MYDOMAIN=example.com
RELAY_POSTMASTER=postmaster@example.com

# Upstream SMTP (куда пересылать письма)
RELAY_HOST=[smtp.gmail.com]:587
RELAY_LOGIN=your-email@gmail.com
RELAY_PASSWORD=your-password
RELAY_USE_TLS=yes

# Аутентификация клиентов (для ВАШЕГО relay)
SASL_USERNAME=client-user@example.com
SASL_PASSWORD=client-password

# Let's Encrypt
LETSENCRYPT_EMAIL=admin@example.com

# Функции
ENABLE_STARTTLS=yes
SMTP_PORT=6025
```

## Настройка Email Клиентов

После развертывания настройте ваши email клиенты:

```yaml
Сервер:     relay.example.com (или IP сервера)
Порт:       6025
Безопасность: STARTTLS (если включено)
Имя пользователя: <SASL_USERNAME из .env>
Пароль:     <SASL_PASSWORD из .env>
```

## Примеры для Популярных Сервисов

### Gmail

```bash
RELAY_HOST=[smtp.gmail.com]:587
RELAY_LOGIN=your-email@gmail.com
RELAY_PASSWORD=your-app-password  # Создайте на myaccount.google.com
RELAY_USE_TLS=yes
```

### SendGrid

```bash
RELAY_HOST=[smtp.sendgrid.net]:587
RELAY_LOGIN=apikey
RELAY_PASSWORD=SG.xxxxxxxxxxxxx
RELAY_USE_TLS=yes
```

### Mailgun

```bash
RELAY_HOST=[smtp.mailgun.org]:587
RELAY_LOGIN=postmaster@mg.example.com
RELAY_PASSWORD=your-mailgun-password
RELAY_USE_TLS=yes
```

### Amazon SES

```bash
RELAY_HOST=[email-smtp.us-east-1.amazonaws.com]:587
RELAY_LOGIN=your-ses-username
RELAY_PASSWORD=your-ses-password
RELAY_USE_TLS=yes
```

## Структура Директорий

```
smtp-relay/
├── deploy.sh                          # Главный скрипт развертывания
├── manage.sh                          # Инструмент управления
├── .env                              # Ваша конфигурация (создайте из .env.example)
├── .env.example                      # Шаблон конфигурации
├── configs/
│   ├── docker-compose.full.yml       # Развертывание полного стека
│   ├── docker-compose.smtp-only.yml  # Развертывание только SMTP
│   └── nginx-default.conf            # Конфигурация Nginx helper
└── docs/
    ├── README.md                     # Этот файл
    ├── TROUBLESHOOTING.md           # Руководство по решению проблем
    └── COMPARISON.md                 # Сравнение вариантов
```

## Устранение Неполадок

### Проблемы с Сертификатами

**Проблема:** Сертификат не получен

```bash
# Проверить DNS
dig +short relay.example.com

# Проверить логи acme-companion
docker logs nginx-proxy-acme

# Принудительное обновление
./manage.sh cert-renew
```

**Проблема:** STARTTLS не работает (TLS not available)

Если вы видите ошибку `4.7.0 TLS not available due to local problem`, это означает отсутствие символических ссылок для SSL сертификатов.

```bash
# Автоматическое исправление (РЕКОМЕНДУЕТСЯ)
./manage.sh fix-ssl-symlinks

# Проверить сертификат
./manage.sh tls-info

# Проверить STARTTLS
./manage.sh tls-check

# Проверить логи
./manage.sh logs -f
```

**Подробное руководство:** См. [SSL-CERTIFICATES-FIX.md](docs/SSL-CERTIFICATES-FIX.md) для полной информации о проблеме и решении.

### Проблемы с Подключением

**Проблема:** Не могу подключиться к SMTP порту

```bash
# Проверить, открыт ли порт
nc -zv localhost 6025

# Проверить firewall
sudo ufw status
sudo ufw allow 6025/tcp

# Проверить статус контейнера
./manage.sh status
```

### Полная Диагностика

```bash
# Запустить полную проверку здоровья
./manage.sh health

# Запустить диагностику
./manage.sh diagnose

# Проверить все логи
./manage.sh logs -f
```

## Резервное Копирование и Восстановление

### Создать Резервную Копию

```bash
./manage.sh backup
# Создает: backups/smtp-relay-backup-YYYYMMDD-HHMMSS.tar.gz
```

### Восстановить Резервную Копию

```bash
./manage.sh restore backups/smtp-relay-backup-20240101-120000.tar.gz
./manage.sh restart
```

## Рекомендации по Безопасности

1. **Используйте сильные пароли** для SASL аутентификации
2. **Включите STARTTLS** для продакшн окружений
3. **Ограничьте доступ relay** через `RELAY_MYNETWORKS`
4. **Мониторьте логи** регулярно с `./manage.sh stats`
5. **Поддерживайте актуальность** - регулярно обновляйте образы
6. **Делайте резервные копии** конфигурации перед изменениями

## Мониторинг

### Проверка Здоровья Сервиса

```bash
# Быстрый статус
./manage.sh status

# Полная проверка здоровья
./manage.sh health

# Наблюдение за логами
./manage.sh logs -f
```

### Мониторинг Потока Почты

```bash
# Статус очереди
./manage.sh queue

# Недавняя активность
./manage.sh stats

# Специфические логи
docker logs smtp-relay | grep -i "sent"
```

## Удаление

### Удалить Только SMTP

```bash
./manage.sh clean
```

### Удалить Полный Стек

```bash
# Удалить все сервисы
docker compose -f configs/docker-compose.full.yml down -v

# Удалить сеть
docker network rm proxy
```

## Поддержка

### Общие Проблемы

См. `docs/TROUBLESHOOTING.md` для подробных решений.

### Логи

```bash
# Логи SMTP relay
./manage.sh logs

# Логи nginx-proxy
docker logs nginx-proxy

# Логи acme-companion
docker logs nginx-proxy-acme
```

### Режим Отладки

```bash
# Включить подробное логирование
docker exec smtp-relay postconf -e "smtpd_tls_loglevel=4"
./manage.sh restart
```

## Участие в Проекте

Мы приветствуем вклад в проект! См. [CONTRIBUTING.md](CONTRIBUTING.md) для деталей.

### Как помочь

- 🐛 [Сообщить об ошибке](https://github.com/yourusername/smtp-relay/issues/new?template=bug_report.md)
- 💡 [Предложить улучшение](https://github.com/yourusername/smtp-relay/issues/new?template=feature_request.md)
- 📖 Улучшить документацию
- 🔧 Отправить pull request

### Участники

Спасибо всем, кто вносит вклад в этот проект!

## Документация

### Основная документация

- 📖 [README.md](README.md) - Основная документация (этот файл)
- ⚡ [QUICKSTART.ru.md](docs/QUICKSTART.ru.md) - Быстрый старт на русском
- 🔧 [SSL-CERTIFICATES-FIX.md](docs/SSL-CERTIFICATES-FIX.md) - Решение проблем с SSL
- 📊 [OPTIMIZATION-REPORT.md](docs/reports/OPTIMIZATION-REPORT.md) - Отчет об оптимизации
- 📝 [CHANGELOG.md](CHANGELOG.md) - История изменений
- 🤝 [CONTRIBUTING.md](CONTRIBUTING.md) - Руководство по участию

### Английская документация

- 📖 [docs/QUICKSTART.md](docs/QUICKSTART.md) - Quick Start
- 📊 [docs/COMPARISON.md](docs/COMPARISON.md) - Deployment Comparison
- 🔧 [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Troubleshooting Guide

### Дополнительная документация

- 🧪 [docs/MANUAL-TEST.md](docs/MANUAL-TEST.md) - Руководство по ручному тестированию
- 🔬 [docs/TEST-REMOTE.md](docs/TEST-REMOTE.md) - Тестирование удаленного сервера
- 📋 [docs/reports/GITHUB-READY-REPORT.md](docs/reports/GITHUB-READY-REPORT.md) - Отчет о готовности к GitHub
- 📁 [docs/reports/FILE-STRUCTURE-OPTIMIZATION.md](docs/reports/FILE-STRUCTURE-OPTIMIZATION.md) - Отчет об оптимизации структуры файлов

## Лицензия

Этот проект лицензирован под MIT License - см. файл [LICENSE](LICENSE) для деталей.

Copyright (c) 2025 SMTP Relay Project Contributors

## Благодарности

Построено с использованием:
- [nginx-proxy](https://github.com/nginx-proxy/nginx-proxy) - Reverse proxy с автоматической конфигурацией
- [acme-companion](https://github.com/nginx-proxy/acme-companion) - Автоматические SSL сертификаты Let's Encrypt
- [smtp-relay](https://github.com/Turgon37/docker-smtp-relay) - Docker образ для SMTP relay

## Поддержка

- 📧 Email: support@example.com
- 💬 [Discussions](https://github.com/yourusername/smtp-relay/discussions)
- 🐛 [Issues](https://github.com/yourusername/smtp-relay/issues)

---

**Нужна помощь?** Запустите `./manage.sh help` для быстрой справки.

**Быстрый тест:**
```bash
./manage.sh test your-email@example.com
```

**Звезда на GitHub** ⭐ если проект оказался полезным!
