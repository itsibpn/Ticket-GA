#!/bin/bash

# deploy.sh - Automated Production Deployment Script for GA Ticket App on Ubuntu Server
# Usage: sudo ./deploy.sh

# Exit immediately if a command exits with a non-zero status
set -e

echo "=========================================================="
echo "    GA Ticket App - Automated Deploy & DB Integrator      "
echo "=========================================================="

# Detect project directory dynamically based on script location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$SCRIPT_DIR"

cd "$PROJECT_DIR"
echo "[SYSTEM] Direktori Proyek Terdeteksi: $PROJECT_DIR"

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

# Securely copy compiled static frontend assets to /var/www/ga-ticket-app/frontend/dist for Nginx web server access
echo "[SYSTEM] Menyalin aset produksi statis ke /var/www/ga-ticket-app/frontend/dist..."
sudo mkdir -p /var/www/ga-ticket-app/frontend/dist
sudo cp -r dist/* /var/www/ga-ticket-app/frontend/dist/
sudo chown -R www-data:www-data /var/www/ga-ticket-app/frontend/dist
sudo chmod -R 755 /var/www/ga-ticket-app

# 5. Handle PM2 Daemon process management
echo "4. Memperbarui Proses PM2 Daemon..."

# Check if PM2 is installed globally, install if missing
if ! command -v pm2 &> /dev/null; then
    echo "[SYSTEM] PM2 tidak ditemukan. Memulai instalasi otomatis secara global..."
    sudo npm install -g pm2
    echo "[SYSTEM] PM2 berhasil diinstal!"
fi

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

# 6. Configure and Activate Nginx Server Block
echo "5. Mengonfigurasi & Mengaktifkan Nginx Server Block..."
# Copy nginx.conf to sites-available
sudo cp nginx.conf /etc/nginx/sites-available/ga-ticket-app

# Create symbolic link to sites-enabled
sudo ln -sf /etc/nginx/sites-available/ga-ticket-app /etc/nginx/sites-enabled/

# Remove default symlink if it exists to avoid conflicts on Port 80
if [ -f /etc/nginx/sites-enabled/default ]; then
    echo "[SYSTEM] Menonaktifkan konfigurasi Nginx default..."
    sudo rm -f /etc/nginx/sites-enabled/default
fi

# Test Nginx configuration
echo "[SYSTEM] Menguji konfigurasi Nginx..."
if sudo nginx -t; then
    echo "[SYSTEM] Konfigurasi Nginx valid. Memuat ulang Nginx..."
    sudo systemctl restart nginx
else
    echo "[ERROR] Konfigurasi Nginx tidak valid! Silakan periksa log."
    exit 1
fi

echo "=========================================================="
echo "      DEPLOYMENT & INTEGRASI DATABASE BERHASIL AKTIF!     "
echo "=========================================================="

