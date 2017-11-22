#!/bin/bash

set -e

echo "Installing crontab..."

REQUIRED_ENV_VARS=(
    CRON_SCHEDULE
    MONGO_HOST
    MONGO_USERNAME
    MONGO_PASSWORD
    MONGO_DB
    OSS_ACCESS_KEY_ID
    OSS_ACCESS_KEY_SECRET
    OSS_REGION
    OSS_BUCKET_NAME
)

# Make sure all required env vars are there
for var in "${REQUIRED_ENV_VARS[@]}" ; do
    if [[ -z "${!var}" ]] ; then
        echo "$var is not set"
        exit -1
    fi
done

# Set default values for non-required vars
export MONGO_PORT=${MONGO_PORT:-27017}
export MONGO_AUTH_DB=${MONGO_AUTH_DB:-admin}
export FILENAME_PREFIX=${FILENAME_PREFIX:-backup}

# Write crontab
echo -e "\
$(env)\n\
$CRON_SCHEDULE /scripts/backup.sh >> /var/log/cron.log 2>&1\
" | crontab -

echo "Done installing crontab"

# Start cron
cron

# We have to touch this file to make sure it exists when we run tail
touch /var/log/cron.log

# This is to prevent our container from exiting
tail -f /var/log/cron.log
