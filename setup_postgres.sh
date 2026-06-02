#!/bin/bash

# setup_postgres.sh - Automated PostgreSQL DB Setup & Schema Seeding for GA Ticket App on Ubuntu
# Usage: sudo ./setup_postgres.sh

# Exit immediately if a command exits with a non-zero status
set -e

echo "=========================================================="
echo "   GA Ticket App - PostgreSQL DB & Schema Integrator      "
echo "=========================================================="

# 1. Check if psql command is installed, if not try to install it
if ! command -v psql &> /dev/null; then
    echo "[SYSTEM] PostgreSQL tidak ditemukan. Memulai instalasi otomatis..."
    sudo apt-get update
    sudo apt-get install -y postgresql postgresql-contrib
    echo "[SYSTEM] PostgreSQL berhasil diinstal!"
else
    echo "[SYSTEM] PostgreSQL terdeteksi sudah terinstal."
fi

# Ensure PostgreSQL service is active
echo "[SYSTEM] Menyalakan dan mengaktifkan service PostgreSQL..."
sudo systemctl enable postgresql
sudo systemctl start postgresql

# 2. Create database and secure user credentials
echo "[DB] Mengonfigurasi Database dan Akses User GA..."
# Running as default postgres user
sudo -u postgres psql -c "CREATE DATABASE ga_tickets;" || echo "[DB] Database ga_tickets sudah ada."
sudo -u postgres psql -c "CREATE USER ga_user WITH PASSWORD 'ga_secure_password_2026';" || echo "[DB] User ga_user sudah ada."
sudo -u postgres psql -c "ALTER USER ga_user WITH PASSWORD 'ga_secure_password_2026';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ga_tickets TO ga_user;"

# Detect project directory dynamically based on script location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 3. Seed Schema and default BUMN data
echo "[DB] Mengimpor schema.sql & data awal (seeding)..."
SCHEMA_PATH="$SCRIPT_DIR/backend/schema.sql"
if [ -f "$SCHEMA_PATH" ]; then
    # Set search_path and grant permissions on schema
    sudo -u postgres psql -d ga_tickets -f "$SCHEMA_PATH"
    sudo -u postgres psql -d ga_tickets -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ga_user;"
    sudo -u postgres psql -d ga_tickets -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ga_user;"
    echo "[DB] Impor schema dan data awal BERHASIL!"
else
    echo "[WARNING] File backend/schema.sql tidak ditemukan pada $SCHEMA_PATH!"
    echo "[WARNING] Pastikan script ini dijalankan di dalam direktori root project."
fi

# 4. Generate backend production .env file
echo "[SYSTEM] Memperbarui konfigurasi variabel lingkungan backend (.env)..."
ENV_PATH="$SCRIPT_DIR/backend/.env"
mkdir -p "$SCRIPT_DIR/backend"

# Create production .env config
cat <<EOT > "$ENV_PATH"
PORT=5000
NODE_ENV=production
DB_USER=ga_user
DB_PASSWORD=ga_secure_password_2026
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=ga_tickets
JWT_SECRET=bumn_secure_secret_key_2026
TELEGRAM_BOT_TOKEN=7777777:ABC-xyz-bot-token
TELEGRAM_CHAT_ID=-100123456789
EOT

# Set safe file permission
chmod 600 "$ENV_PATH"
echo "[SYSTEM] Konfigurasi file $ENV_PATH berhasil disimpan dan diamankan."

echo "=========================================================="
echo "    INTEGRASI DATABASE SELESAI & BERHASIL DIKONFIGURASI   "
echo "=========================================================="
