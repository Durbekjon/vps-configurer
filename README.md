# VPS Configurer

A simple bash script to set up a production-ready VPS with PostgreSQL, Node.js, Nginx, and security configurations.

## 🚀 Quick Start

1. **Clone and run:**
   ```bash
   git clone https://github.com/Durbekjon/vps-configurer
   cd vps-configurer
   chmod +x setup.sh
   ./setup.sh
   ```

2. **Or customize with .env:**
   ```bash
   cp env.example .env
   # Edit .env with your settings
   ./setup.sh
   ```

## 📦 What it installs

- **PostgreSQL 17** - Database server
- **Node.js 22** - JavaScript runtime
- **Nginx** - Web server
- **PM2** - Process manager
- **UFW** - Firewall
- **ZSH + Oh-My-Zsh** - Enhanced shell

## 🔐 Security Features

- Auto-generated secure database passwords
- Firewall configuration (ports 22, 80, 443, 4000)
- Credentials saved to `~/.db_credentials` (600 permissions)
- Comprehensive logging to `/var/log/vps-setup.log`

## 📋 Configuration

Create a `.env` file to customize:

```bash
DB_USER=admin
DB_NAME=eventify
# DB_PASSWORD=auto-generated if not set
```

## 📁 Output Files

- `~/.db_credentials` - Database connection details
- `/var/log/vps-setup.log` - Setup logs

## ⚠️ Requirements

- Ubuntu/Debian system
- Root/sudo access
- Internet connection

## 🛠️ Manual Steps After Setup

1. Configure your application to use the database credentials
2. Set up SSL certificates for Nginx
3. Configure your domain and Nginx virtual hosts
4. Deploy your application with PM2

---

**Note:** This script modifies system configurations. Review the code before running on production systems.
