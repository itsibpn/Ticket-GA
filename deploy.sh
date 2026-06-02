#!/bin/bash

# deploy.sh - Automated Production Deployment Script for GA Ticket App on Ubuntu Server
# Usage: sudo ./deploy.sh

# Exit immediately if a command exits with a non-zero status
set -e

echo "=========================================================="
echo "    GA Ticket App - Automated Deploy & DB Integrator      "
echo "=========================================================="

PROJECT_DIR="/var/www/ga-ticket-app"

# Ensure we are running inside the correct root directory
if [ -d "$PROJECT_DIR" ]; then
    cd "$PROJECT_DIR"
else
    echo "[ERROR] Direktori $PROJECT_DIR tidak ditemukan!"
    exit 1
fi

# 1. Check if PostgreSQL database is configured, if not trigger setup_postgres.sh
ENV_PATH="./backend/.env"
if [ ! -f "$ENV_PATH" ]; then
    echo "[SYSTEM] File backend/.env tidak ditemukan."
    echo "[SYSTEM] Menjalankan setup database PostgreSQL terintegrasi..."
    chmod +x ./setup_postgres.sh
    sudo ./setup_postgres.sh
else
    echo "[SYSTEM] Konfigurasi backend/.env terdeteksi. Melewati inisialisasi DB."
fi

# 2. Pull latest code updates from main branch
echo "1. Menarik pembaruan kode terbaru..."
# Ignore git error if directory is not initialized as a git repo yet
git pull origin main || echo "[WARNING] Git pull diabaikan. Melanjutkan pengerjaan lokal..."

# 3. Configure and install backend packages
echo "2. Konfigurasi Backend & Instalasi Dependensi..."
cd backend
npm install --production

# Create logs directory if it doesn't exist
mkdir -p ../logs

# 4. Configure and compile frontend
echo "3. Kompilasi Frontend & Build Aset Statis..."
cd ../frontend
npm install
npm run build

# 5. Handle PM2 Daemon process management
echo "4. Memperbarui Proses PM2 Daemon..."
cd ..
# Check if PM2 process is running, restart if yes, start if no
if pm2 show ga-ticket-backend > /dev/null 2>&1; then
    echo "[PM2] Proses terdeteksi berjalan. Me-reload server backend..."
    pm2 reload pm2.json
else
    echo "[PM2] Memulai proses PM2 baru..."
    pm2 start pm2.json
fi

# Save PM2 process list to restore on server reboot
pm2 save

# 6. Reload Nginx configuration to pick up reverse proxy changes
echo "5. Memuat ulang (Reloading) Nginx Server Block..."
sudo systemctl reload nginx || sudo systemctl restart nginx

echo "=========================================================="
echo "      DEPLOYMENT & INTEGRASI DATABASE BERHASIL AKTIF!     "
echo "=========================================================="
