# Deployment Options Comparison

Quick reference to choose the right deployment mode for your needs.

## Deployment Modes

### Mode 1: Full Stack
Complete infrastructure with nginx-proxy, acme-companion, and smtp-relay.

### Mode 2: SMTP Only
Minimal deployment that integrates with existing nginx-proxy.

---

## Feature Comparison

| Feature | Full Stack | SMTP Only |
|---------|------------|-----------|
| **nginx-proxy** | ✅ Included | ❌ Must exist |
| **acme-companion** | ✅ Included | ❌ Must exist |
| **smtp-relay** | ✅ Included | ✅ Included |
| **Auto SSL** | ✅ Yes | ✅ Yes (via existing) |
| **Reverse Proxy** | ✅ Yes | ⚠️ Uses existing |
| **Containers** | 4 containers | 2 containers |
| **Disk Usage** | ~500MB | ~200MB |
| **Setup Time** | 3-5 minutes | 2-3 minutes |
| **Maintenance** | Higher | Lower |

---

## STARTTLS Options

### With STARTTLS (Recommended)

| Aspect | Details |
|--------|---------|
| **Security** | ✅ Encrypted SMTP |
| **Certificates** | ✅ Let's Encrypt (automatic) |
| **Requirements** | Domain + DNS + Ports 80/443 |
| **Renewal** | ✅ Automatic |
| **Production Ready** | ✅ Yes |
| **Setup Complexity** | Medium |

### Without STARTTLS

| Aspect | Details |
|--------|---------|
| **Security** | ⚠️ Plain SMTP (no encryption) |
| **Certificates** | ❌ Not needed |
| **Requirements** | Just port 6025 |
| **Renewal** | N/A |
| **Production Ready** | ⚠️ Testing only |
| **Setup Complexity** | Low |

---

## Use Case Matrix

### Full Stack + STARTTLS
**Best for:**
- ✅ Fresh servers
- ✅ Production environments
- ✅ Public-facing SMTP
- ✅ Need reverse proxy for other services
- ✅ Want complete automation

**Requirements:**
- Valid domain name
- DNS configured
- Ports 80, 443, 6025 open
- ~500MB disk space

**Setup:**
```bash
./deploy.sh
# Select: 1 (Full Stack)
# Select: 1 (STARTTLS Yes)
```

**Example Use Cases:**
- Production email relay for applications
- Multi-service server setup
- SaaS application email backend
- Web hosting with multiple sites

---

### Full Stack + No STARTTLS
**Best for:**
- ✅ Testing full stack
- ✅ Internal networks
- ✅ Behind SSL terminator
- ✅ Quick testing

**Requirements:**
- Port 6025 open
- ~500MB disk space

**Setup:**
```bash
./deploy.sh
# Select: 1 (Full Stack)
# Select: 2 (STARTTLS No)
```

**Example Use Cases:**
- Development environment
- Internal corporate network
- Learning/testing Docker stack
- Behind Cloudflare/proxy

---

### SMTP Only + STARTTLS
**Best for:**
- ✅ Existing nginx-proxy setup
- ✅ Minimal footprint
- ✅ Add SMTP to infrastructure
- ✅ Production environments

**Requirements:**
- nginx-proxy running
- acme-companion running
- Network "proxy" exists
- Valid domain name
- DNS configured
- Port 6025 open

**Setup:**
```bash
./deploy.sh
# Select: 2 (SMTP Only)
# Select: 1 (STARTTLS Yes)
```

**Example Use Cases:**
- Adding SMTP to existing web server
- Microservices architecture
- Docker Swarm/cluster setup
- Multiple services on one server

---

### SMTP Only + No STARTTLS
**Best for:**
- ✅ Minimal testing setup
- ✅ Internal-only relay
- ✅ Quickest deployment
- ✅ Resource-constrained

**Requirements:**
- nginx-proxy running (for network only)
- Port 6025 open
- ~200MB disk space

**Setup:**
```bash
./deploy.sh
# Select: 2 (SMTP Only)
# Select: 2 (STARTTLS No)
```

**Example Use Cases:**
- Quick testing
- Internal corporate relay
- Development environment
- Temporary relay

---

## Decision Tree

```
Start
│
├─ Do you have nginx-proxy running?
│  │
│  ├─ No
│  │  │
│  │  ├─ Need production SSL?
│  │  │  │
│  │  │  ├─ Yes → Full Stack + STARTTLS
│  │  │  └─ No  → Full Stack + No STARTTLS
│  │
│  └─ Yes
│     │
│     ├─ Need production SSL?
│     │  │
│     │  ├─ Yes → SMTP Only + STARTTLS
│     │  └─ No  → SMTP Only + No STARTTLS
```

---

## Performance Comparison

### Resource Usage

| Mode | RAM | Disk | CPU |
|------|-----|------|-----|
| Full Stack + STARTTLS | ~400MB | ~500MB | Low |
| Full Stack + No STARTTLS | ~350MB | ~500MB | Low |
| SMTP Only + STARTTLS | ~150MB | ~200MB | Very Low |
| SMTP Only + No STARTTLS | ~120MB | ~200MB | Very Low |

### Startup Time

| Mode | Initial | Subsequent |
|------|---------|------------|
| Full Stack + STARTTLS | 2-3 min | 30 sec |
| Full Stack + No STARTTLS | 30 sec | 15 sec |
| SMTP Only + STARTTLS | 1-2 min | 20 sec |
| SMTP Only + No STARTTLS | 15 sec | 10 sec |

---

## Migration Paths

### From "No STARTTLS" to "STARTTLS"

```bash
# 1. Update .env
nano .env
# Set: ENABLE_STARTTLS=yes
# Set: RELAY_MYDOMAIN=your-domain.com
# Set: LETSENCRYPT_EMAIL=your-email@example.com

# 2. Ensure DNS is configured
dig +short your-domain.com  # Should show your server IP

# 3. Restart
./manage.sh restart

# 4. Wait for certificate
# (2-3 minutes)

# 5. Verify
./manage.sh tls-check
```

### From "SMTP Only" to "Full Stack"

```bash
# 1. Backup current setup
./manage.sh backup

# 2. Stop current
./manage.sh stop

# 3. Stop nginx-proxy (if you want to replace it)
docker stop nginx-proxy nginx-proxy-acme

# 4. Deploy full stack
./deploy.sh
# Select: 1 (Full Stack)
# Use same .env configuration
```

### From "Full Stack" to "SMTP Only"

```bash
# Not recommended - you lose nginx-proxy for other services
# If you really need to:

# 1. Backup
./manage.sh backup

# 2. Stop SMTP containers only
docker stop smtp-relay smtp-relay-web

# 3. Keep nginx-proxy and acme-companion running

# 4. Redeploy SMTP only
./deploy.sh
# Select: 2 (SMTP Only)
```

---

## Cost Analysis

### Cloud Provider Costs (Monthly Estimates)

#### Full Stack + STARTTLS
- **AWS EC2 (t3.micro):** ~$10-15/month
- **DigitalOcean Droplet:** ~$6-12/month
- **Linode Nanode:** ~$5-10/month
- **Minimum Specs:** 1GB RAM, 1 vCPU

#### SMTP Only + STARTTLS
- **AWS EC2 (t3.micro):** ~$10-15/month
- **DigitalOcean Droplet:** ~$6/month
- **Linode Nanode:** ~$5/month
- **Minimum Specs:** 512MB RAM, 1 vCPU

*Note: Costs are approximate and vary by region*

---

## Security Comparison

| Aspect | With STARTTLS | Without STARTTLS |
|--------|---------------|-------------------|
| **Client-to-Relay** | ✅ Encrypted | ❌ Plain text |
| **Certificates** | ✅ Let's Encrypt | N/A |
| **SASL Auth** | ✅ Protected | ⚠️ Exposed |
| **MitM Resistance** | ✅ Yes | ❌ No |
| **Compliance** | ✅ GDPR-friendly | ⚠️ Risk |
| **Password Sniffing** | ✅ Protected | ❌ Vulnerable |

**Recommendation:** Always use STARTTLS for production!

---

## Compatibility Matrix

### Email Providers

| Provider | Full Stack | SMTP Only | STARTTLS | No TLS |
|----------|------------|-----------|----------|--------|
| **Gmail** | ✅ | ✅ | ✅ | ✅ |
| **SendGrid** | ✅ | ✅ | ✅ | ✅ |
| **Mailgun** | ✅ | ✅ | ✅ | ✅ |
| **Amazon SES** | ✅ | ✅ | ✅ | ✅ |
| **Office 365** | ✅ | ✅ | ✅ | ✅ |
| **Custom SMTP** | ✅ | ✅ | ✅ | ✅ |

All modes support all major email providers!

---

## Scaling Considerations

### Single Server (All Modes)
- **Capacity:** 100-1000 emails/hour
- **Users:** 1-50 concurrent
- **Cost:** $5-15/month

### Load Balanced (Full Stack Recommended)
- **Setup:** Multiple smtp-relay containers
- **Capacity:** 10,000+ emails/hour
- **Users:** 100+ concurrent
- **Cost:** $50-200/month

### High Availability (Full Stack + Docker Swarm)
- **Setup:** Replicated services
- **Capacity:** 50,000+ emails/hour
- **Users:** 500+ concurrent
- **Cost:** $200-500/month

---

## Quick Selection Guide

**Choose Full Stack if:**
- You're starting fresh
- You need reverse proxy for other services
- You want everything in one deployment
- You have time for initial setup

**Choose SMTP Only if:**
- You already have nginx-proxy
- You want minimal footprint
- You're adding to existing infrastructure
- You need quick deployment

**Enable STARTTLS if:**
- This is production
- You handle sensitive data
- You need encryption
- You have a domain name

**Disable STARTTLS if:**
- This is testing/development
- You're on internal network only
- You're behind another SSL terminator
- You don't have a domain

---

## Recommended Configurations

### Recommended: Production SaaS

```
Mode: Full Stack
STARTTLS: Yes
Port: 6025
Upstream: SendGrid/Mailgun
Monitoring: Yes
Backups: Daily
```

### Recommended: Corporate Internal

```
Mode: SMTP Only
STARTTLS: Yes
Port: 25 or 587
Upstream: Office 365
Monitoring: Yes
Backups: Weekly
```

### Recommended: Development

```
Mode: SMTP Only
STARTTLS: No
Port: 6025
Upstream: Mailhog/Mailtrap
Monitoring: No
Backups: Optional
```

### Recommended: Testing

```
Mode: Full Stack
STARTTLS: No (or staging certs)
Port: 6025
Upstream: Any
Monitoring: No
Backups: No
```

---

## Summary Table

| Scenario | Mode | STARTTLS | Best For |
|----------|------|----------|----------|
| Production web app | Full Stack | Yes | New server, need proxy |
| Add to existing | SMTP Only | Yes | Have nginx-proxy |
| Internal corporate | SMTP Only | Yes | Existing infrastructure |
| Development | Either | No | Testing |
| Learning Docker | Full Stack | Yes | Education |
| Quick test | SMTP Only | No | Fastest setup |
| SaaS backend | Full Stack | Yes | Professional app |
| Multi-tenant | Full Stack | Yes | Multiple services |

---

**Still unsure? Run the deployment script - it will guide you!**

```bash
./deploy.sh
```
