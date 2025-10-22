# Quick Start Guide

Get your SMTP relay running in under 5 minutes!

## Prerequisites

- Docker and Docker Compose installed
- Domain name pointing to your server (for STARTTLS)
- Ports 80, 443, and 6025 available

## 30-Second Setup

```bash
# 1. Navigate to directory
cd /root/rl/optimized

# 2. Make scripts executable
chmod +x deploy.sh manage.sh

# 3. Deploy (interactive)
./deploy.sh
```

That's it! Follow the prompts.

## What the Script Does

1. **Asks deployment mode:**
   - Full Stack (nginx-proxy + SMTP)
   - SMTP Only (use existing nginx-proxy)

2. **Asks STARTTLS preference:**
   - Yes: Secure with Let's Encrypt
   - No: Plain SMTP

3. **Collects configuration:**
   - Domain name
   - Upstream SMTP settings
   - Email for certificates

4. **Deploys automatically:**
   - Creates containers
   - Obtains SSL certificate (if STARTTLS)
   - Creates SASL user
   - Verifies deployment

## After Deployment

### Test Your Relay

```bash
./manage.sh test your-email@example.com
```

### Check Status

```bash
./manage.sh status
```

### View Logs

```bash
./manage.sh logs -f
```

## Example: Full Stack with Gmail

```bash
./deploy.sh

# When prompted:
# Mode: 1 (Full Stack)
# STARTTLS: 1 (Yes)
# Domain: relay.example.com
# Upstream: [smtp.gmail.com]:587
# Login: your-email@gmail.com
# Password: your-app-password
```

## Example: SMTP Only without STARTTLS

```bash
./deploy.sh

# When prompted:
# Mode: 2 (SMTP Only)
# STARTTLS: 2 (No)
# Domain: relay.example.com
# (continue with upstream settings)
```

## Configuration File Method

If you prefer to pre-configure:

```bash
# 1. Copy example
cp .env.example .env

# 2. Edit configuration
nano .env

# 3. Deploy
./deploy.sh
```

The script will detect existing `.env` and use it (or ask to overwrite).

## Next Steps

- [Read full README](../README.md)
- [Configure email clients](CLIENT_CONFIG.md)
- [Troubleshooting](TROUBLESHOOTING.md)

## Quick Reference

| Command | Description |
|---------|-------------|
| `./deploy.sh` | Deploy SMTP relay |
| `./manage.sh status` | Check status |
| `./manage.sh logs` | View logs |
| `./manage.sh test <email>` | Send test email |
| `./manage.sh users` | List users |
| `./manage.sh add-user` | Add new user |
| `./manage.sh help` | Full command list |

## Common Scenarios

### Scenario 1: Production SMTP with Gmail

```bash
./deploy.sh
# Full Stack, with STARTTLS
# Upstream: [smtp.gmail.com]:587
```

### Scenario 2: Internal Testing

```bash
./deploy.sh
# SMTP Only, without STARTTLS
# Use for local/internal testing
```

### Scenario 3: Add to Existing Infrastructure

```bash
# Prerequisites: nginx-proxy already running
./deploy.sh
# SMTP Only, with STARTTLS
# Integrates with existing proxy
```

## Verification Checklist

After deployment, verify:

- [ ] Container is running: `docker ps | grep smtp-relay`
- [ ] Port accessible: `nc -zv localhost 6025`
- [ ] STARTTLS works: `./manage.sh tls-check` (if enabled)
- [ ] Can send email: `./manage.sh test your-email@example.com`
- [ ] User exists: `./manage.sh users`

## Getting Help

If something doesn't work:

```bash
# Run diagnostics
./manage.sh diagnose

# Check health
./manage.sh health

# View detailed logs
./manage.sh logs -f
```

Still stuck? Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

---

**Total time to working SMTP relay: ~3 minutes**
