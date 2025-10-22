# 🛠️ Ручное Тестирование SMTP Relay

## Быстрые Команды для Проверки

### 1. Проверка Порта (TCP)

```bash
# Способ 1: bash
timeout 5 bash -c "echo > /dev/tcp/keemor.su/6025" && echo "✓ Порт доступен" || echo "✗ Порт недоступен"
```

```bash
# Способ 2: telnet
telnet keemor.su 6025
# Должен показать: 220 keemor.su ESMTP Postfix
# Нажмите Ctrl+] затем 'quit' для выхода
```

```bash
# Способ 3: nc
nc -zv keemor.su 6025
```

---

### 2. Проверка DNS

```bash
# Разрешение имени
dig +short keemor.su

# Или
nslookup keemor.su

# Или
host keemor.su
```

---

### 3. Базовый SMTP Тест

```bash
# С netcat
(echo "EHLO localhost"; sleep 2; echo "QUIT") | nc keemor.su 6025
```

**Ожидаемый ответ:**
```
220 keemor.su ESMTP Postfix
250-keemor.su
250-PIPELINING
250-SIZE 10240000
250-STARTTLS
250-AUTH PLAIN LOGIN CRAM-MD5
250 8BITMIME
221 Bye
```

---

### 4. Тест с Аутентификацией (Python)

Создайте файл `test.py`:

```python
import smtplib

server = smtplib.SMTP("keemor.su", 6025, timeout=10)
server.set_debuglevel(1)  # Показывать debug вывод

try:
    server.starttls()
    print("\n✓ STARTTLS успешен")
except Exception as e:
    print(f"\n⚠ STARTTLS пропущен: {e}")

server.login("keemor821@gmail.com", "nsH7BJJFzw1l")
print("\n✓ Аутентификация успешна")

from email.mime.text import MIMEText
msg = MIMEText("Test")
msg['Subject'] = "Test"
msg['From'] = "keemor821@keemor.su"
msg['To'] = "keemor821@gmail.com"

server.send_message(msg)
print("\n✓ Письмо отправлено")

server.quit()
```

Запуск:
```bash
python3 test.py
```

---

### 5. Однострочный Python Тест

```bash
python3 << 'EOF'
import smtplib
from email.mime.text import MIMEText

s = smtplib.SMTP("keemor.su", 6025, timeout=10)
try:
    s.starttls()
except:
    pass
s.login("keemor821@gmail.com", "nsH7BJJFzw1l")

m = MIMEText("Test")
m['Subject'] = "Test"
m['From'] = "keemor821@keemor.su"
m['To'] = "keemor821@gmail.com"

s.send_message(m)
s.quit()
print("✓ OK")
EOF
```

---

### 6. Проверка с Curl (SMTP)

```bash
# Отправка через curl (если поддерживается)
curl smtp://keemor.su:6025 \
  --mail-from keemor821@keemor.su \
  --mail-rcpt keemor821@gmail.com \
  --user keemor821@gmail.com:nsH7BJJFzw1l \
  -T - << EOF
From: keemor821@keemor.su
To: keemor821@gmail.com
Subject: Test from curl

Test message
EOF
```

---

### 7. Проверка Сертификата (если STARTTLS)

```bash
# С openssl
openssl s_client -connect keemor.su:6025 -starttls smtp -showcerts
```

**Ожидаемый вывод:**
- `250 STARTTLS` - сервер поддерживает STARTTLS
- Информация о сертификате
- `Verify return code: 0` (или другой код для самоподписанных)

---

## 🐛 Troubleshooting

### Проблема: "nc: command not found"

**Решение:**
```bash
# Ubuntu/Debian
apt-get install netcat-openbsd

# CentOS/RHEL
yum install nc

# Alpine
apk add netcat-openbsd
```

---

### Проблема: "Connection refused"

**Причины:**
1. Firewall блокирует порт
2. SMTP сервер не запущен
3. Неправильный host/port

**Проверка:**
```bash
# На SMTP сервере
docker ps | grep smtp-relay
./manage.sh status

# Проверка firewall
iptables -L -n | grep 6025
```

---

### Проблема: "DNS resolution failed"

**Решение:**
```bash
# Проверьте /etc/resolv.conf
cat /etc/resolv.conf

# Попробуйте другой DNS
echo "nameserver 8.8.8.8" >> /etc/resolv.conf

# Или используйте IP напрямую
ping <IP-адрес-сервера>
```

---

### Проблема: "Authentication failed"

**Проверка:**
```bash
# На SMTP сервере проверьте пользователей
docker exec smtp-relay /opt/listpasswd.sh

# Должен показать:
# keemor821@gmail.com: userPassword
```

**Создайте пользователя если нужно:**
```bash
./manage.sh add-user
```

---

## 📋 Полезные Команды на SMTP Сервере

```bash
# Статус
./manage.sh status

# Логи
./manage.sh logs

# Список пользователей
./manage.sh users

# Тест отправки
./manage.sh test keemor821@gmail.com

# Диагностика
./manage.sh diagnose
```

---

## 🔍 Debug Команды

### Просмотр всех подключений

```bash
# На SMTP сервере
docker logs smtp-relay --tail 50

# Только SMTP соединения
docker logs smtp-relay 2>&1 | grep "connect from"

# Только ошибки аутентификации
docker logs smtp-relay 2>&1 | grep -i "auth.*fail"
```

---

### Проверка Postfix конфигурации

```bash
docker exec smtp-relay postconf | grep -E "smtp|sasl"
```

---

## ✅ Контрольный Список

- [ ] Порт 6025 доступен
- [ ] DNS разрешается (keemor.su)
- [ ] SMTP отвечает на EHLO
- [ ] STARTTLS поддерживается
- [ ] Аутентификация работает
- [ ] Письма отправляются
- [ ] Sender = *@keemor.su (правильный домен)

---

**Версия:** 2.1.0
**Дата:** 2024-10-22
