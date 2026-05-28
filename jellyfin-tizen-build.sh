#!/bin/bash
set -e

# Debugging: Print environment variables
echo "Environment Variables:"
echo "JELLYFIN_TIZEN_RELEASE: $JELLYFIN_TIZEN_RELEASE"
echo "JELLYFIN_WEB_RELEASE: $JELLYFIN_WEB_RELEASE"

# Ensure required environment variables are set
if [ -z "$JELLYFIN_TIZEN_RELEASE" ] || [ -z "$JELLYFIN_WEB_RELEASE" ]; then
  echo "Error: Missing required environment variables JELLYFIN_TIZEN_RELEASE or JELLYFIN_WEB_RELEASE."
  exit 1
fi

# Step 1: Clone or update Jellyfin Web repository
echo "Cloning Jellyfin Web repository..."
if [ ! -d "jellyfin-web" ]; then
  git clone -b "$JELLYFIN_WEB_RELEASE" https://github.com/jellyfin/jellyfin-web.git
else
  cd jellyfin-web
  git fetch origin
  git checkout "$JELLYFIN_WEB_RELEASE"
  git pull --ff-only 2>/dev/null || true
  cd ..
fi

# Step 2: Build Jellyfin Web
echo "Building Jellyfin Web..."
cd jellyfin-web
npm ci --no-audit
USE_SYSTEM_FONTS=1 npm run build:production
cd ..

# Verify Jellyfin Web build output
if [ ! -d "jellyfin-web/dist" ]; then
  echo "Error: Jellyfin Web build failed. 'jellyfin-web/dist' directory not found."
  exit 1
fi

# Step 3: Clone or update Jellyfin Tizen repository
echo "Cloning Jellyfin Tizen repository..."
if [ ! -d "jellyfin-tizen" ]; then
  git clone -b "$JELLYFIN_TIZEN_RELEASE" https://github.com/jellyfin/jellyfin-tizen.git
else
  cd jellyfin-tizen
  git fetch origin
  git checkout "$JELLYFIN_TIZEN_RELEASE"
  git pull --ff-only 2>/dev/null || true
  cd ..
fi

# Step 4: Prepare Jellyfin Tizen interface
echo "Preparing Jellyfin Tizen interface..."
cd jellyfin-tizen
JELLYFIN_WEB_DIR=../jellyfin-web/dist npm ci --no-audit

# Verify Jellyfin Tizen interface preparation
if [ ! -d "www" ]; then
  echo "Error: Jellyfin Tizen interface preparation failed. 'www' directory not found."
  exit 1
fi

# Step 5: Build WGT package
echo "Building WGT package..."
tizen build-web -e ".*" -e gulpfile.babel.js -e README.md -e "node_modules/*" -e "package*.json" -e "yarn.lock"
tizen package -t wgt -o . -- .buildResult

# Verify WGT package creation
if [ ! -f "Jellyfin.wgt" ]; then
  echo "Error: Jellyfin.wgt package not created."
  exit 1
fi

echo "Build completed successfully. Jellyfin.wgt is ready."
