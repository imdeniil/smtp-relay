# Troubleshooting Guide

Common issues and solutions for SMTP Relay deployment.

## Table of Contents

1. [Deployment Issues](#deployment-issues)
2. [Certificate Issues](#certificate-issues)
3. [Connection Issues](#connection-issues)
4. [Authentication Issues](#authentication-issues)
5. [Mail Delivery Issues](#mail-delivery-issues)
6. [Performance Issues](#performance-issues)

---

## Deployment Issues

### Issue: nginx-proxy not found (SMTP Only mode)

**Error:**
```
nginx-proxy container not found
Please install nginx-proxy first or choose Full Stack mode
```

**Solution:**

Option 1: Deploy Full Stack instead
```bash
./deploy.sh
# Select option 1 (Full Stack)
```

Option 2: Install nginx-proxy first
```bash
docker network create proxy

docker run -d \
  --name nginx-proxy \
  --network proxy \
  -p 80:80 -p 443:443 \
  -v /var/run/docker.sock:/tmp/docker.sock:ro \
  nginxproxy/nginx-proxy

docker run -d \
  --name nginx-proxy-acme \
  --network proxy \
  --volumes-from nginx-proxy \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  nginxproxy/acme-companion

# Now deploy SMTP
./deploy.sh
```

### Issue: Port already in use

**Error:**
```
Error starting userland proxy: listen tcp4 0.0.0.0:6025: bind: address already in use
```

**Solution:**

Find what's using the port:
```bash
sudo lsof -i :6025
# or
sudo netstat -tulpn | grep 6025
```

Option 1: Stop the conflicting service
```bash
docker stop <container-using-port>
```

Option 2: Change port in .env
```bash
nano .env
# Change SMTP_PORT=6025 to SMTP_PORT=2525 (or any free port)
./manage.sh restart
```

### Issue: Volume already exists error

**Error:**
```
volume "certs" already exists but is external: true
```

**Solution:**

Check volume name used by nginx-proxy:
```bash
docker volume ls | grep cert
docker inspect nginx-proxy | grep -A 10 Mounts | grep certs
```

Update in `configs/docker-compose.smtp-only.yml`:
```yaml
volumes:
  certs:
    external: true
    name: actual_volume_name_here  # Use the actual name
```

---

## Certificate Issues

### Issue: Certificate not obtained

**Symptoms:**
- STARTTLS fails
- Certificate file not found
- acme-companion logs show errors

**Diagnosis:**
```bash
# Check if certificate exists
docker exec smtp-relay ls -la /etc/nginx/certs/

# Check acme-companion logs
docker logs nginx-proxy-acme | tail -50

# Check DNS
dig +short $RELAY_MYDOMAIN
```

**Solutions:**

1. **DNS not pointing to server**
```bash
# Get your server IP
curl ifconfig.me

# Check DNS
dig +short relay.example.com

# If mismatch, update DNS A record
```

2. **Port 80 not accessible**
```bash
# Check firewall
sudo ufw status
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Check if nginx-proxy is listening
docker logs nginx-proxy | grep "80"
```

3. **Rate limit reached (Let's Encrypt)**
```bash
# Use staging server for testing
# Edit configs/docker-compose.*.yml:

acme-companion:
  environment:
    ACME_CA_URI: https://acme-staging-v02.api.letsencrypt.org/directory

# Redeploy
docker compose -f configs/docker-compose.full.yml up -d acme-companion
```

4. **Force certificate renewal**
```bash
./manage.sh cert-renew
```

### Issue: STARTTLS connection fails

**Error:**
```
STARTTLS test failed
```

**Diagnosis:**
```bash
# Check STARTTLS manually
openssl s_client -connect localhost:6025 -starttls smtp

# Check certificate validity
./manage.sh tls-info

# Check Postfix TLS config
docker exec smtp-relay postconf | grep tls
```

**Solutions:**

1. **Certificate not mounted correctly**
```bash
# Verify certificate is accessible
docker exec smtp-relay ls -la /etc/nginx/certs/

# Check volume mount
docker inspect smtp-relay | grep -A 20 Mounts
```

2. **Certificate path mismatch**
```bash
# Check actual certificate name
docker exec nginx-proxy ls /etc/nginx/certs/

# Update .env to match
RELAY_MYDOMAIN=exact.domain.name
```

3. **TLS disabled in config**
```bash
# Check .env
grep ENABLE_STARTTLS .env

# Should be:
ENABLE_STARTTLS=yes

# Restart
./manage.sh restart
```

---

## Connection Issues

### Issue: Cannot connect to SMTP port

**Error:**
```
Connection refused on port 6025
```

**Diagnosis:**
```bash
# Check if container is running
docker ps | grep smtp-relay

# Check port binding
docker port smtp-relay

# Try connection
nc -zv localhost 6025
telnet localhost 6025
```

**Solutions:**

1. **Container not running**
```bash
./manage.sh start
./manage.sh status
```

2. **Wrong port**
```bash
# Check configured port
grep SMTP_PORT .env

# Check actual binding
docker port smtp-relay
```

3. **Firewall blocking**
```bash
# Allow port
sudo ufw allow 6025/tcp

# Check iptables
sudo iptables -L -n | grep 6025
```

4. **Listening on wrong interface**
```bash
# Check bindings
netstat -tulpn | grep 6025

# Should show 0.0.0.0:6025 not 127.0.0.1:6025
```

### Issue: Connection timeout from external clients

**Symptoms:**
- Works from localhost
- Fails from other machines

**Solutions:**

1. **Firewall issues**
```bash
# Server firewall
sudo ufw allow 6025/tcp

# Cloud provider security group
# Add inbound rule for port 6025 in AWS/Azure/GCP console
```

2. **Docker networking**
```bash
# Ensure proper port mapping
docker inspect smtp-relay | grep HostPort

# Should show proper port binding
```

---

## Authentication Issues

### Issue: Authentication failed

**Error:**
```
535 5.7.8 Error: authentication failed
```

**Diagnosis:**
```bash
# List SASL users
./manage.sh users

# Check SASL configuration
docker exec smtp-relay cat /data/sasl_passwd

# Test authentication manually
docker exec -it smtp-relay /bin/sh
# Inside container:
testsaslauthd -u username -p password
```

**Solutions:**

1. **User doesn't exist**
```bash
./manage.sh add-user
```

2. **Wrong password**
```bash
./manage.sh reset-password
```

3. **Wrong domain**
```bash
# SASL username format: username@domain
# Make sure @domain matches RELAY_MYDOMAIN

./manage.sh users  # Check existing format
```

4. **SASL not enabled**
```bash
# Check config
docker exec smtp-relay postconf | grep sasl

# Should show:
# smtpd_sasl_auth_enable = yes
```

### Issue: No authentication mechanisms available

**Error:**
```
250-AUTH
(no mechanisms listed)
```

**Solution:**
```bash
# Restart container
./manage.sh restart

# Check SASL libraries
docker exec smtp-relay ls -la /usr/lib/sasl2/

# Recreate SASL users
./manage.sh del-user
./manage.sh add-user
```

---

## Mail Delivery Issues

### Issue: Emails stuck in queue

**Symptoms:**
```bash
./manage.sh queue
# Shows many deferred messages
```

**Diagnosis:**
```bash
# Check queue
./manage.sh queue

# View detailed errors
docker exec smtp-relay postcat -q <queue-id>

# Check logs
./manage.sh logs | grep -i defer
```

**Solutions:**

1. **Upstream authentication failure**
```bash
# Check upstream credentials in .env
grep RELAY_ .env

# Test upstream connection
docker exec smtp-relay telnet smtp.gmail.com 587
```

2. **Network issues**
```bash
# Check if container can reach internet
docker exec smtp-relay ping -c 3 8.8.8.8

# Check DNS resolution
docker exec smtp-relay nslookup smtp.gmail.com
```

3. **Upstream requires TLS**
```bash
# Update .env
RELAY_USE_TLS=yes

./manage.sh restart
```

4. **Flush queue after fixing**
```bash
./manage.sh flush
```

### Issue: Messages rejected by upstream

**Error in logs:**
```
554 5.7.1 Relay access denied
```

**Solutions:**

1. **Check upstream credentials**
```bash
# Verify in .env
RELAY_LOGIN=correct-username
RELAY_PASSWORD=correct-password

# For Gmail, use App Password, not account password
```

2. **Upstream IP restrictions**
```
# Some providers restrict by IP
# Check provider's SMTP settings
# May need to whitelist server IP
```

3. **SPF/DKIM issues**
```bash
# Configure SPF record in DNS:
# TXT record: "v=spf1 ip4:YOUR_SERVER_IP ~all"
```

### Issue: Mail loops

**Error:**
```
554 5.4.6 Too many hops
```

**Solution:**
```bash
# Check relay configuration
docker exec smtp-relay postconf | grep relay

# Ensure relayhost points to external server
# Not back to itself
```

---

## Performance Issues

### Issue: Slow mail delivery

**Diagnosis:**
```bash
# Check queue size
./manage.sh queue

# Check stats
./manage.sh stats

# Monitor logs
./manage.sh logs -f
```

**Solutions:**

1. **Increase concurrent connections**
```bash
# Add to .env
POSTCONF_default_process_limit=100
POSTCONF_smtp_destination_concurrency_limit=20

./manage.sh restart
```

2. **Flush queue more frequently**
```bash
# Manual
./manage.sh flush

# Cron job (every 5 min)
*/5 * * * * docker exec smtp-relay postqueue -f
```

### Issue: High memory usage

**Solution:**
```bash
# Limit Postfix resources
# Add to .env
POSTCONF_default_process_limit=50

# Or use Docker limits
docker update --memory="512m" smtp-relay
```

---

## Advanced Diagnostics

### Full System Check

```bash
# Complete health check
./manage.sh health

# Detailed diagnostics
./manage.sh diagnose

# Check all logs
docker logs smtp-relay | less
```

### Manual SMTP Test

```bash
# Connect to SMTP
telnet localhost 6025

# Commands to type:
EHLO test.com
AUTH PLAIN <base64-encoded-credentials>
MAIL FROM:<sender@example.com>
RCPT TO:<recipient@example.com>
DATA
Subject: Test
Test message
.
QUIT
```

### Generate Base64 credentials

```bash
# Format: \0username\0password
printf '\0username@example.com\0password' | base64
```

### Check Postfix Configuration

```bash
# View all Postfix config
docker exec smtp-relay postconf

# Check specific setting
docker exec smtp-relay postconf | grep relay

# Test configuration
docker exec smtp-relay postfix check
```

### Rebuild from Scratch

```bash
# Complete cleanup
./manage.sh clean

# Redeploy
./deploy.sh
```

---

## Getting More Help

### Enable Debug Logging

```bash
# Increase log verbosity
docker exec smtp-relay postconf -e "smtpd_tls_loglevel=4"
docker exec smtp-relay postconf -e "debug_peer_list=all"
./manage.sh restart
```

### Collect Diagnostic Info

```bash
# Create diagnostic bundle
cat > diagnostic-info.txt << EOF
=== System Info ===
$(uname -a)

=== Docker Version ===
$(docker --version)

=== Container Status ===
$(docker ps -a | grep smtp)

=== Environment ===
$(cat .env | grep -v PASSWORD)

=== Logs ===
$(docker logs smtp-relay --tail=100)

=== Config ===
$(docker exec smtp-relay postconf -n)

=== Queue ===
$(./manage.sh queue)
EOF

cat diagnostic-info.txt
```

### Common Log Locations

```bash
# Container logs
docker logs smtp-relay

# Mail log inside container
docker exec smtp-relay cat /var/log/mail.log

# nginx-proxy logs
docker logs nginx-proxy

# acme-companion logs
docker logs nginx-proxy-acme
```

---

## Prevention

### Regular Maintenance

```bash
# Weekly checks
./manage.sh health
./manage.sh stats

# Monthly
./manage.sh backup

# Monitor queue size
watch -n 300 './manage.sh queue'
```

### Monitoring Setup

```bash
# Add healthcheck alerts
# Use external monitoring like:
# - UptimeRobot (free)
# - Pingdom
# - Prometheus + Alertmanager
```

---

**Still having issues?**

1. Check logs: `./manage.sh logs -f`
2. Run diagnostics: `./manage.sh diagnose`
3. Review configuration: `cat .env`
4. Search logs for specific errors
