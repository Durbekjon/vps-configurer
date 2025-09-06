#!/bin/bash

set -e  # xato bo'lsa, script to'xtaydi

# ------------------------
# Configuration and Logging
# ------------------------
LOG_FILE="/var/log/vps-setup.log"
DB_PASSWORD=${DB_PASSWORD:-$(openssl rand -base64 32)}
DB_USER=${DB_USER:-admin}
DB_NAME=${DB_NAME:-eventify}

# Create log file and setup logging
sudo touch "$LOG_FILE"
sudo chown $USER:$USER "$LOG_FILE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# ------------------------
# Load environment variables from .env file
# ------------------------
if [ -f ".env" ]; then
    log "Loading environment variables from .env file..."
    export $(grep -v '^#' .env | xargs)
else
    log "No .env file found, using default values..."
fi

log "=== 🚀 Server setup is starting... ==="
log "Database password will be generated and saved to: /home/$USER/.db_credentials"
log "Log file location: $LOG_FILE"
log "Using database user: $DB_USER"
log "Using database name: $DB_NAME"

# ------------------------
# 1. Update system
# ------------------------
log ">>> Updating system packages..."
sudo apt update && sudo apt upgrade -y
log "System packages updated successfully"

# ------------------------
# 2. Install base packages
# ------------------------
log ">>> Installing base tools (zsh, curl, wget, git)..."
sudo apt install -y zsh curl wget git ca-certificates gnupg ufw
log "Base tools installed successfully"

# ------------------------
# 3. Install Oh-My-Zsh + autosuggestions
# ------------------------
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  log ">>> Installing Oh-My-Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  chsh -s $(which zsh)
  log "Oh-My-Zsh installed successfully"
fi

if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
  log ">>> Installing ZSH autosuggestions..."
  git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
  log "ZSH autosuggestions installed successfully"
fi

# Update ~/.zshrc plugins to include zsh-autosuggestions
if grep -q "^plugins=" "$HOME/.zshrc"; then
  # Replace the plugins line with the desired plugins
  sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions)/' "$HOME/.zshrc"
else
  # Add the plugins line if it doesn't exist
  echo "plugins=(git zsh-autosuggestions)" >> "$HOME/.zshrc"
fi

log ">>> ZSH plugins configured successfully!"

# ------------------------
# 4. Install PostgreSQL 17
# ------------------------
log ">>> Setting up PostgreSQL 17..."
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list
sudo apt update
sudo apt install -y postgresql-17 postgresql-client-17
sudo systemctl enable postgresql
log "PostgreSQL 17 installed successfully"
log "PostgreSQL version: $(psql --version)"

# Update listen_addresses in postgresql.conf
PG_CONF="/etc/postgresql/17/main/postgresql.conf"
if [ -f "$PG_CONF" ]; then
  log ">>> Configuring PostgreSQL to listen on all addresses..."
  sudo sed -i "s/^#\?listen_addresses\s*=.*/listen_addresses = '*'/" "$PG_CONF"
  log "PostgreSQL configuration updated"
else
  log "WARNING: $PG_CONF not found. Skipping listen_addresses configuration."
fi

# Switch to the postgres user and create a new superuser and database
log ">>> Creating database user and database..."
sudo -i -u postgres bash <<EOF
psql -c "CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASSWORD' SUPERUSER CREATEDB CREATEROLE;"
createdb $DB_NAME -O $DB_USER
exit
EOF

# Save database credentials securely
echo "# Database credentials - Generated on $(date)" > "$HOME/.db_credentials"
echo "DB_USER=$DB_USER" >> "$HOME/.db_credentials"
echo "DB_PASSWORD=$DB_PASSWORD" >> "$HOME/.db_credentials"
echo "DB_NAME=$DB_NAME" >> "$HOME/.db_credentials"
echo "DB_HOST=localhost" >> "$HOME/.db_credentials"
echo "DB_PORT=5432" >> "$HOME/.db_credentials"
echo "" >> "$HOME/.db_credentials"
echo "# Connection string examples:" >> "$HOME/.db_credentials"
echo "# PostgreSQL: postgresql://$DB_USER:$DB_PASSWORD@localhost:5432/$DB_NAME" >> "$HOME/.db_credentials"
echo "# Node.js: DATABASE_URL=postgresql://$DB_USER:$DB_PASSWORD@localhost:5432/$DB_NAME" >> "$HOME/.db_credentials"
chmod 600 "$HOME/.db_credentials"
log "Database credentials saved to $HOME/.db_credentials"

# Restart PostgreSQL to apply configuration changes
log ">>> Restarting PostgreSQL to apply configuration..."
sudo systemctl restart postgresql
sleep 3
sudo systemctl status postgresql --no-pager
log "PostgreSQL restarted successfully"

# Test database connection
log ">>> Testing database connection..."
if sudo -u postgres psql -c "\l" | grep -q "$DB_NAME"; then
    log "Database '$DB_NAME' created successfully"
else
    log "ERROR: Failed to create database '$DB_NAME'"
    exit 1
fi

if sudo -u postgres psql -c "\du" | grep -q "$DB_USER"; then
    log "Database user '$DB_USER' created successfully"
else
    log "ERROR: Failed to create database user '$DB_USER'"
    exit 1
fi





# ------------------------
# 5. Install Node.js 22 + yarn + pm2
# ------------------------
log ">>> Installing Node.js 22..."
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
log "Node.js installed successfully"
log "Node.js version: $(node -v)"
log "NPM version: $(npm -v)"

log ">>> Installing Yarn and PM2..."
npm install -g yarn pm2
log "Yarn and PM2 installed successfully"

# ------------------------
# 6. Configure firewall (UFW)
# ------------------------
log ">>> Configuring UFW..."
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 4000/tcp
sudo ufw --force enable
log "UFW configured successfully"
sudo ufw status

# ------------------------
# 7. Install Nginx
# ------------------------
log ">>> Installing and starting Nginx..."
sudo apt install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx
log "Nginx installed and started successfully"
sudo systemctl status nginx --no-pager

log "=== ✅ Setup completed successfully! ==="
log "Database credentials saved to: $HOME/.db_credentials"
log "Setup log saved to: $LOG_FILE"
echo ""
echo "🔐 IMPORTANT: Your database credentials have been saved to:"
echo "   $HOME/.db_credentials"
echo "   Please keep this file secure and do not share it!"
echo ""
echo "📋 Setup Summary:"
echo "   - PostgreSQL 17: Running"
echo "   - Node.js $(node -v): Installed"
echo "   - Nginx: Running"
echo "   - UFW Firewall: Enabled"
echo "   - Database: $DB_NAME created with user $DB_USER"
echo ""
