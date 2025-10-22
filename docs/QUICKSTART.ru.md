# Быстрый Старт - SMTP Relay

Запустите ваш SMTP relay менее чем за 5 минут!

## За 3 Минуты до Работающего SMTP Сервера

### Шаг 1: Подготовка

```bash
# Перейдите в директорию проекта
cd /root/rl

# Сделайте скрипты исполняемыми (если еще не сделано)
chmod +x deploy.sh manage.sh
```

### Шаг 2: Запуск Развертывания

```bash
./deploy.sh
```

### Шаг 3: Следуйте Подсказкам

Скрипт спросит:

1. **Режим развертывания:**
   - `1` - Полный Стек (nginx-proxy + SMTP) - для нового сервера
   - `2` - Только SMTP - если nginx-proxy уже установлен

2. **STARTTLS:**
   - `1` - Да (рекомендуется для продакшена)
   - `2` - Нет (для тестирования)

3. **Конфигурация:**
   - Домен (например: relay.example.com)
   - Upstream SMTP настройки (Gmail, SendGrid, и т.д.)
   - Email для Let's Encrypt

### Шаг 4: Готово!

После завершения проверьте:

```bash
./manage.sh status
./manage.sh test your-email@example.com
```

## Примеры Конфигураций

### Пример 1: Gmail

```bash
./deploy.sh

# Когда спросят:
# Режим: 1 (Полный Стек)
# STARTTLS: 1 (Да)
# Домен: relay.example.com
# Upstream хост: [smtp.gmail.com]:587
# Логин: your-email@gmail.com
# Пароль: your-app-password (не пароль аккаунта!)
```

### Пример 2: Yandex

```bash
# Upstream хост: [smtp.yandex.ru]:587
# Логин: your-email@yandex.ru
# Пароль: your-password
# TLS: yes
```

### Пример 3: Mail.ru

```bash
# Upstream хост: [smtp.mail.ru]:587
# Логин: your-email@mail.ru
# Пароль: your-password
# TLS: yes
```

## Варианты Развертывания

### Вариант 1: Полный Стек + STARTTLS (Рекомендуется для Продакшена)

**Что получите:**
- ✅ nginx-proxy для reverse proxy
- ✅ Автоматические SSL сертификаты
- ✅ SMTP relay с шифрованием

**Требования:**
- Доменное имя
- DNS настроен
- Порты 80, 443, 6025 открыты

```bash
./deploy.sh
# Выберите: 1, затем 1
```

### Вариант 2: Полный Стек без STARTTLS (Для Разработки)

**Что получите:**
- ✅ nginx-proxy
- ✅ SMTP relay без SSL
- Быстрая настройка

```bash
./deploy.sh
# Выберите: 1, затем 2
```

### Вариант 3: Только SMTP + STARTTLS (Добавить к Существующей Инфраструктуре)

**Требования:**
- nginx-proxy уже работает
- acme-companion уже работает

```bash
./deploy.sh
# Выберите: 2, затем 1
```

### Вариант 4: Только SMTP без STARTTLS (Быстрое Тестирование)

**Самый быстрый вариант:**
- Минимальная конфигурация
- Без SSL
- Готово за 2 минуты

```bash
./deploy.sh
# Выберите: 2, затем 2
```

## Команды Управления

### Основные Команды

```bash
./manage.sh status              # Проверить статус
./manage.sh logs                # Просмотр логов
./manage.sh logs -f             # Следить за логами
./manage.sh restart             # Перезапустить
```

### Пользователи

```bash
./manage.sh users               # Список пользователей
./manage.sh add-user            # Добавить пользователя
./manage.sh del-user            # Удалить пользователя
```

### Тестирование

```bash
./manage.sh test user@example.com    # Отправить тест
./manage.sh tls-check                # Проверить STARTTLS
./manage.sh health                   # Проверка здоровья
```

### Помощь

```bash
./manage.sh help                # Все команды
```

## Настройка Email Клиента

После развертывания настройте ваш email клиент:

```
Сервер:          relay.example.com (или IP сервера)
Порт:            6025
Безопасность:    STARTTLS (если включено)
Имя пользователя: (из SASL_USERNAME в .env)
Пароль:          (из SASL_PASSWORD в .env)
```

## Проверка После Развертывания

### 1. Проверка Контейнера

```bash
docker ps | grep smtp-relay
# Должен показать работающий контейнер
```

### 2. Проверка Порта

```bash
nc -zv localhost 6025
# Должно показать: Connection to localhost 6025 port [tcp/*] succeeded!
```

### 3. Проверка STARTTLS (если включено)

```bash
./manage.sh tls-check
# Должно показать: ✓ STARTTLS работает
```

### 4. Отправка Тестового Письма

```bash
./manage.sh test your-email@example.com
# Проверьте почту - должно прийти письмо
```

## Устранение Проблем

### Проблема: Сертификат не получен

```bash
# Проверить DNS
dig +short relay.example.com

# Проверить логи
docker logs nginx-proxy-acme

# Принудительное обновление
./manage.sh cert-renew
```

### Проблема: Не могу подключиться

```bash
# Проверить статус
./manage.sh status

# Проверить логи
./manage.sh logs

# Запустить диагностику
./manage.sh diagnose
```

### Проблема: Письма не отправляются

```bash
# Проверить очередь
./manage.sh queue

# Проверить статистику
./manage.sh stats

# Очистить очередь
./manage.sh flush
```

## Следующие Шаги

1. **Прочитайте полную документацию:**
   ```bash
   cat README.md
   ```

2. **Настройте мониторинг:**
   ```bash
   ./manage.sh health   # Регулярно проверяйте
   ```

3. **Настройте резервное копирование:**
   ```bash
   ./manage.sh backup   # Делайте регулярно
   ```

4. **Добавьте пользователей:**
   ```bash
   ./manage.sh add-user
   ```

## Полезные Ссылки

- **Полная документация:** [README.md](README.md)
- **Сравнение вариантов:** [docs/COMPARISON.md](docs/COMPARISON.md)
- **Решение проблем:** [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

## Получение Помощи

### Быстрая помощь:

```bash
./manage.sh help
```

### Если что-то не работает:

```bash
# Полная диагностика
./manage.sh health
./manage.sh diagnose

# Проверить логи
./manage.sh logs -f
```

---

**Время до работающего SMTP relay: ~3 минуты** ⚡

**Нужна помощь?** Запустите `./manage.sh help`
