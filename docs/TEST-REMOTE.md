# 🧪 Тестирование SMTP Relay с Удаленного Сервера

## 📋 Описание

Скрипт `test-remote.sh` предназначен для тестирования SMTP relay с удаленного сервера. Он проверяет:

- ✅ Доступность порта
- ✅ SMTP EHLO соединение
- ✅ STARTTLS шифрование
- ✅ SASL аутентификацию
- ✅ Отправку тестового письма

---

## 🚀 Быстрый Старт

### На Сервере SMTP Relay

```bash
# Скопируйте скрипт на удаленный сервер
scp test-remote.sh user@remote-server:/tmp/
```

### На Удаленном Сервере

```bash
# Запустите тест
/tmp/test-remote.sh keemor.su 6025 keemor821@gmail.com nsH7BJJFzw1l
```

---

## 💻 Использование

### Вариант 1: С Параметрами из .env

Если `.env` файл доступен:

```bash
./test-remote.sh
```

### Вариант 2: С Параметрами Командной Строки

```bash
./test-remote.sh HOST PORT USERNAME PASSWORD
```

**Пример:**
```bash
./test-remote.sh keemor.su 6025 keemor821@gmail.com nsH7BJJFzw1l
```

---

## 📊 Что Проверяется

### Тест 1: Доступность Порта
Проверяет TCP подключение к SMTP серверу.

### Тест 2: SMTP EHLO
Проверяет базовое SMTP соединение и возможности сервера.

### Тест 3: STARTTLS
Проверяет TLS шифрование (требуется OpenSSL).

### Тест 4: Аутентификация
Проверяет SASL AUTH LOGIN с вашими credentials.

### Тест 5: Python Тест
Отправляет реальное тестовое письмо (требуется Python3).

---

## ✅ Ожидаемый Результат

```
========================================
✅ ВСЕ ТЕСТЫ ПРОЙДЕНЫ!
========================================

SMTP Relay полностью функционален и доступен с удаленного сервера.

Настройки для вашего приложения:
  SMTP Host:     keemor.su
  SMTP Port:     6025
  SMTP User:     keemor821@gmail.com
  SMTP Password: (используйте ваш пароль)
  Use STARTTLS:  true
  Sender (FROM): *@keemor.su
```

---

## 🔧 Требования

### Минимальные (для базовых тестов)
- `bash`
- `nc` (netcat)

### Рекомендуемые (для полных тестов)
- `openssl` - для STARTTLS теста
- `python3` - для теста отправки письма

### Установка Зависимостей

**Ubuntu/Debian:**
```bash
apt-get update
apt-get install -y netcat-openbsd openssl python3
```

**CentOS/RHEL:**
```bash
yum install -y nc openssl python3
```

**Alpine:**
```bash
apk add bash netcat-openbsd openssl python3
```

---

## 🐛 Troubleshooting

### Ошибка: "Порт недоступен"

**Причина:** Firewall блокирует исходящие подключения.

**Решение:**
```bash
# Проверьте firewall
iptables -L OUTPUT -n | grep 6025

# Разрешите исходящие на порт 6025
iptables -A OUTPUT -p tcp --dport 6025 -j ACCEPT
```

---

### Ошибка: "STARTTLS соединение не установлено"

**Причина:** OpenSSL не установлен или проблема с TLS.

**Решение:**
```bash
# Установите OpenSSL
apt-get install openssl

# Или пропустите STARTTLS тест - аутентификация все равно работает
```

---

### Ошибка: "Аутентификация не удалась (код 535)"

**Причина:** Неправильные credentials.

**Решение:**
1. Проверьте username и password
2. Убедитесь что SASL пользователь создан на сервере:
   ```bash
   ./manage.sh users
   ```

---

### Ошибка: "Sender address rejected"

**Причина:** Sender должен быть с доменом `@keemor.su`.

**Решение:**
Скрипт автоматически использует правильный sender. Проверьте что в логах используется `*@keemor.su`.

---

## 📝 Примеры Использования

### Тест из Docker Контейнера

```bash
docker run -it --rm ubuntu:22.04 bash -c "
  apt-get update && apt-get install -y curl nc openssl python3 && \
  curl -o test.sh https://your-server/test-remote.sh && \
  chmod +x test.sh && \
  ./test.sh keemor.su 6025 keemor821@gmail.com nsH7BJJFzw1l
"
```

---

### Автоматическая Проверка из CI/CD

```yaml
# GitLab CI
test_smtp:
  script:
    - apt-get update && apt-get install -y netcat openssl python3
    - ./test-remote.sh $SMTP_HOST $SMTP_PORT $SMTP_USER $SMTP_PASS
```

```yaml
# GitHub Actions
- name: Test SMTP
  run: |
    sudo apt-get install -y netcat openssl python3
    ./test-remote.sh ${{ secrets.SMTP_HOST }} ${{ secrets.SMTP_PORT }} ${{ secrets.SMTP_USER }} ${{ secrets.SMTP_PASS }}
```

---

## 🔐 Безопасность

**⚠️ ВАЖНО:** Скрипт содержит пароль в командной строке!

### Безопасное Использование

**Вариант 1:** Используйте `.env` файл
```bash
# Создайте .env на удаленном сервере
cat > .env << EOF
RELAY_MYDOMAIN=keemor.su
SMTP_PORT=6025
SASL_USERNAME=keemor821@gmail.com
SASL_PASSWORD=nsH7BJJFzw1l
EOF

chmod 600 .env
./test-remote.sh
```

**Вариант 2:** Используйте переменные окружения
```bash
export SMTP_HOST=keemor.su
export SMTP_PORT=6025
export SMTP_USER=keemor821@gmail.com
export SMTP_PASS=nsH7BJJFzw1l

./test-remote.sh $SMTP_HOST $SMTP_PORT $SMTP_USER $SMTP_PASS

# Очистите историю
history -c
```

---

## 📞 Поддержка

Если тесты не проходят:

1. **Проверьте логи на SMTP сервере:**
   ```bash
   ./manage.sh logs
   ```

2. **Проверьте статус сервиса:**
   ```bash
   ./manage.sh status
   ```

3. **Запустите диагностику:**
   ```bash
   ./manage.sh diagnose
   ```

---

## 📄 Лицензия

MIT License

---

**Версия:** 2.1.0
**Дата:** 2024-10-22
**Автор:** Claude Code
