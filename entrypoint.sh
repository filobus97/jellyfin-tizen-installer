#!/bin/bash
set -e

# Debugging: Print environment variables
echo "Environment Variables:"
echo "LANG: $LANG"
echo "LANGUAGE: $LANGUAGE"
echo "LC_ALL: $LC_ALL"
echo "TV_IP: $TV_IP"

# # Sanitize environment variables
CERT_PASSWORD=$(echo "$CERT_PASSWORD" | tr -d '\r' | tr -d '\0')

# Ensure required variables are set
if [ -z "$TV_IP" ] || [ -z "$CERT_PASSWORD" ]; then
  echo "Error: Missing required environment variables."
  exit 1
fi

# Populate the profiles.xml file from the template
echo "Populating profiles.xml from template..."
envsubst < /home/developer/tizen-studio-data/profile/profiles-template.xml > /home/developer/tizen-studio-data/profile/profiles.xml

# Debugging: Print the generated profiles.xml
echo "Generated profiles.xml:"
cat /home/developer/tizen-studio-data/profile/profiles.xml

# Set locale variables
export LANG=${LANG}
export LANGUAGE=${LANGUAGE}
export LC_ALL=${LC_ALL}

# Start the sdb server explicitly
echo "Starting sdb server..."
sdb kill-server
sdb start-server

# Connect to the TV with retry logic
connected=false
for i in {1..5}; do
  echo "Attempting to connect to TV at $TV_IP:26101 (Attempt $i)..."
  sdb connect $TV_IP:26101 && connected=true && break
  sleep 1
done
if [ "$connected" = false ]; then
  echo "Error: Failed to connect to TV after 5 attempts. Exiting."
  exit 1
fi

# Wait for the connection to stabilize
sleep 3

# List connected devices and extract the TV name
echo "Checking connected devices..."
sdb_output=$(sdb devices)
echo "$sdb_output"

# Extract the TV name (assuming format: <IP>:<PORT> <status> <name>)
TV_NAME=$(echo "$sdb_output" | grep "$TV_IP" | awk '{print $3}')
if [ -z "$TV_NAME" ]; then
  echo "Error: Failed to detect TV name. Exiting."
  exit 1
fi

echo "Connected to TV: $TV_NAME"

# Grant installation permissions
echo "Granting installation permissions on the TV ($TV_NAME)..."
if ! tizen install-permit -t $TV_NAME; then
  echo "Failed to grant installation permissions. Please check the active certificate profile."
  exit 1
fi

# Build Jellyfin app
echo "Building Jellyfin app..."
if ! /jellyfin-tizen-build.sh; then
  echo "Failed to build Jellyfin app. Exiting."
  exit 1
fi

# Deploy Jellyfin app to TV
echo "Deploying Jellyfin app to TV ($TV_NAME)..."
if ! tizen install -n /home/developer/jellyfin-tizen/Jellyfin.wgt -t $TV_NAME; then
  echo "Failed to deploy Jellyfin app to TV. Exiting."
  exit 1
fi

echo "Jellyfin app deployed successfully to TV ($TV_NAME)."

# Copies the result of the build in a folder that can be mapped to the host
mkdir -p /result
cp -r /home/developer/jellyfin-tizen/* /result

# Start a long-running process
#echo "Container is running. Use 'docker exec -it jellyfin-tizen /bin/bash' to access."
#tail -f /dev/null
