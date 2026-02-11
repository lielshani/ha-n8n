#!/bin/bash

# 1. Read config from Home Assistant options
# We use jq to parse the special /data/options.json file provided by HA
SECURE_COOKIE=$(jq --raw-output '.secure_cookie // false' /data/options.json)

# 2. Export them as N8N Environment Variables
export N8N_SECURE_COOKIE="$SECURE_COOKIE"
export N8N_PORT=5678

# 3. Start n8n
echo "Starting n8n..."
exec n8n