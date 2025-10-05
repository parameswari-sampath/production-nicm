# SmartMCQ Production Deployment Guide

Complete deployment guide for SmartMCQ application on a dedicated VPS server.

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Server Requirements](#server-requirements)
- [Pre-Deployment Checklist](#pre-deployment-checklist)
- [Deployment Steps](#deployment-steps)
- [Post-Deployment](#post-deployment)
- [SSL/HTTPS Setup](#sslhttps-setup)
- [Monitoring & Maintenance](#monitoring--maintenance)
- [Troubleshooting](#troubleshooting)

---

## 🏗️ Architecture Overview

```
Internet
    ↓
smart-mcq.com (Port 80/443)
    ↓
Nginx Reverse Proxy
    ↓
    ├─→ Frontend (Next.js) :3000
    └─→ Backend (Go) :8080
            ↓
        PostgreSQL :5432
```

### Services

- **Nginx**: Reverse proxy handling all incoming traffic
- **Frontend**: Next.js application (port 3000, internal)
- **Backend**: Go API server (port 8080, internal)
- **PostgreSQL**: Database (port 5432)

---

## ⚙️ Prerequisites

### Required Software

1. **Docker** (version 20.10 or higher)
2. **Docker Compose** (version 2.0 or higher)
3. **Git** (for cloning repository)

### Domain Setup

- Domain: `smart-mcq.com`
- DNS A record pointing to your VPS IP address
- Wait for DNS propagation (can take up to 48 hours)

---

## 💻 Server Requirements

### Minimum Specifications

- **CPU**: 2 cores
- **RAM**: 4GB
- **Storage**: 20GB SSD
- **OS**: Ubuntu 20.04/22.04 LTS (recommended) or any Linux distribution

### Recommended Specifications

- **CPU**: 4 cores
- **RAM**: 8GB
- **Storage**: 50GB SSD

---

## ✅ Pre-Deployment Checklist

### 1. Install Docker

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add current user to docker group
sudo usermod -aG docker $USER

# Logout and login again, then verify
docker --version
```

### 2. Install Docker Compose

```bash
# Docker Compose is included in Docker Desktop
# For Linux servers, verify it's available
docker compose version

# If not available, install it manually
sudo apt install docker-compose-plugin
```

### 3. Configure Firewall

```bash
# Allow HTTP and HTTPS traffic
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp  # SSH (if not already allowed)
sudo ufw enable
sudo ufw status
```

### 4. Verify DNS

```bash
# Check if domain points to your server
dig smart-mcq.com +short
# Should return your server's IP address

# Or use nslookup
nslookup smart-mcq.com
```

---

## 🚀 Deployment Steps

### Step 1: Clone/Upload Project Files

```bash
# Create project directory
mkdir -p /opt/smartmcq
cd /opt/smartmcq

# Upload your project files here
# Or clone from git repository
# git clone <repository-url> .
```

### Step 2: Configure Environment Variables

```bash
# Edit production environment file
nano .env.production
```

**IMPORTANT**: Update these values:

```env
# Change the default admin credentials
NEXT_PUBLIC_ADMIN_USERNAME=your_admin_username
NEXT_PUBLIC_ADMIN_PASSWORD=your_secure_password

# Generate a secure JWT secret (min 32 characters)
JWT_SECRET_KEY=your-super-secret-key-change-this-to-random-string-min-32-chars

# Update database password for production
POSTGRES_PASSWORD=your_secure_database_password
DATABASE_URL=postgresql://postgres:your_secure_database_password@db:5432/smartmcq?sslmode=disable
```

To generate a secure JWT secret:
```bash
openssl rand -base64 32
```

### Step 3: Make Deployment Script Executable

```bash
chmod +x deploy.sh
```

### Step 4: Run Deployment Script

```bash
./deploy.sh
```

This script will:
1. ✅ Check Docker installation
2. 🛑 Stop all running containers
3. 🗑️ Remove all existing containers
4. 🗑️ Remove all Docker images
5. 🗑️ Clean up volumes and networks
6. 🏗️ Build fresh images
7. 🚀 Start all services

### Step 5: Verify Deployment

```bash
# Check running containers
docker ps

# Expected output:
# - nginx-proxy (port 80, 443)
# - nextjs-frontend (internal)
# - golang-backend (internal)
# - postgres-db (port 5432)

# Check logs
docker compose logs -f

# Check specific service logs
docker compose logs -f frontend
docker compose logs -f backend
docker compose logs -f db
```

---

## 🔒 SSL/HTTPS Setup (Recommended)

### Option 1: Using Certbot (Let's Encrypt)

```bash
# Install Certbot
sudo apt install certbot

# Stop nginx temporarily
docker compose stop nginx

# Generate SSL certificate
sudo certbot certonly --standalone -d smart-mcq.com

# Certificates will be saved to:
# /etc/letsencrypt/live/smart-mcq.com/fullchain.pem
# /etc/letsencrypt/live/smart-mcq.com/privkey.pem
```

#### Update docker-compose.yml:

```yaml
  nginx:
    build:
      context: ./nginx
      dockerfile: Dockerfile
    container_name: nginx-proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /etc/letsencrypt:/etc/nginx/ssl:ro  # Add this line
    networks:
      - app-network
    depends_on:
      - frontend
      - backend
    restart: unless-stopped
```

#### Update nginx/nginx.conf:

Uncomment the SSL configuration lines in `nginx/nginx.conf`:

```nginx
# Uncomment the HTTPS server block and SSL settings
server {
    listen 443 ssl http2;
    ssl_certificate /etc/nginx/ssl/live/smart-mcq.com/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/live/smart-mcq.com/privkey.pem;
    # ... rest of configuration
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name smart-mcq.com;
    return 301 https://$server_name$request_uri;
}
```

#### Restart nginx:

```bash
docker compose restart nginx
```

#### Auto-renewal:

```bash
# Test renewal
sudo certbot renew --dry-run

# Certbot will automatically renew certificates
# Add a cron job to restart nginx after renewal
sudo crontab -e

# Add this line:
0 0 * * * certbot renew --quiet && docker compose -f /opt/smartmcq/docker-compose.yml restart nginx
```

---

## 📊 Monitoring & Maintenance

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f frontend
docker compose logs -f backend
docker compose logs -f db
docker compose logs -f nginx

# Last 100 lines
docker compose logs --tail=100
```

### Check Resource Usage

```bash
# Container stats
docker stats

# Disk usage
docker system df
```

### Backup Database

```bash
# Create backup
docker exec postgres-db pg_dump -U postgres smartmcq > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore from backup
docker exec -i postgres-db psql -U postgres smartmcq < backup_20240101_120000.sql
```

### Update Application

```bash
# Pull latest changes
git pull

# Rebuild and restart
docker compose up -d --build

# Or use the deployment script
./deploy.sh
```

### Stop Services

```bash
# Stop all services
docker compose down

# Stop and remove volumes (CAUTION: This deletes database data)
docker compose down -v
```

### Restart Services

```bash
# Restart all services
docker compose restart

# Restart specific service
docker compose restart frontend
```

---

## 🔧 Troubleshooting

### Problem: Containers won't start

```bash
# Check logs
docker compose logs

# Check if ports are in use
sudo netstat -tulpn | grep :80
sudo netstat -tulpn | grep :443

# Kill processes using the ports
sudo kill -9 <PID>
```

### Problem: Database connection fails

```bash
# Check database logs
docker compose logs db

# Connect to database manually
docker exec -it postgres-db psql -U postgres -d smartmcq

# Test connection from backend
docker exec -it golang-backend sh
# Then try connecting to db:5432
```

### Problem: 502 Bad Gateway

```bash
# Check if backend is running
docker ps | grep backend

# Check backend logs
docker compose logs backend

# Restart backend
docker compose restart backend
```

### Problem: Domain not accessible

```bash
# Check DNS
dig smart-mcq.com +short

# Check nginx logs
docker compose logs nginx

# Verify nginx config
docker exec nginx-proxy nginx -t

# Check if port 80 is open
sudo netstat -tulpn | grep :80
```

### Problem: Out of disk space

```bash
# Check disk usage
df -h

# Clean up Docker resources
docker system prune -a --volumes

# Remove old images
docker image prune -a
```

### Complete Clean Restart

```bash
# Use the deployment script
./deploy.sh

# Or manually:
docker compose down -v
docker system prune -af --volumes
docker compose up -d --build
```

---

## 📝 Important Notes

### Security Best Practices

1. **Change default passwords** in `.env.production`
2. **Use strong JWT secret** (min 32 characters, random)
3. **Enable HTTPS** with SSL certificates
4. **Configure firewall** properly
5. **Regular backups** of database
6. **Keep Docker updated**: `sudo apt update && sudo apt upgrade`
7. **Monitor logs** regularly for suspicious activity
8. **Restrict database access** to internal network only

### Environment Variables

The following environment variables are critical:

- `JWT_SECRET_KEY`: Must be changed before production
- `NEXT_PUBLIC_ADMIN_USERNAME`: Change from default
- `NEXT_PUBLIC_ADMIN_PASSWORD`: Change from default
- `POSTGRES_PASSWORD`: Use a strong password

### Database Persistence

Database data is stored in Docker volume `postgres-data`. This persists across container restarts but will be deleted if you run `docker compose down -v`.

### Backup Strategy

Set up automated backups:

```bash
# Create backup script
nano /opt/smartmcq/backup.sh
```

```bash
#!/bin/bash
BACKUP_DIR="/opt/smartmcq/backups"
mkdir -p $BACKUP_DIR
DATE=$(date +%Y%m%d_%H%M%S)
docker exec postgres-db pg_dump -U postgres smartmcq > $BACKUP_DIR/backup_$DATE.sql
# Keep only last 7 days of backups
find $BACKUP_DIR -name "backup_*.sql" -mtime +7 -delete
```

```bash
# Make executable
chmod +x /opt/smartmcq/backup.sh

# Add to crontab (daily at 2 AM)
crontab -e
# Add: 0 2 * * * /opt/smartmcq/backup.sh
```

---

## 📞 Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review Docker logs: `docker compose logs`
3. Check container status: `docker ps`

---

## 📄 File Structure

```
production/
├── docker-compose.yml          # Main orchestration file
├── .env.production            # Production environment variables
├── deploy.sh                  # Deployment script
├── README.md                  # This file
├── nginx/
│   ├── Dockerfile            # Nginx container build file
│   └── nginx.conf           # Nginx configuration
├── final-simple-hardcoded-v2/  # Go backend
│   ├── Dockerfile
│   └── ... (backend files)
└── final-simple-hardcided-fe/  # Next.js frontend
    ├── Dockerfile
    └── ... (frontend files)
```

---

## 🎉 Success!

If everything is working correctly, you should be able to access your application at:

- **Production URL**: http://smart-mcq.com (or https:// after SSL setup)

The deployment script has configured everything for production use with:
- ✅ Nginx reverse proxy
- ✅ Next.js frontend
- ✅ Go backend API
- ✅ PostgreSQL database
- ✅ Docker networking
- ✅ Automatic container restart
- ✅ Health checks

**Next steps**: Configure SSL/HTTPS for secure production deployment!
