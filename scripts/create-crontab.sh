#!/bin/bash

set -e

echo "Installing crontab..."

REQUIRED_ENV_VARS=(
    MONGO_HOST
    MONGO_USERNAME
    MONGO_PASSWORD
    MONGO_DB
    OSS_ACCESS_KEY_ID
    OSS_ACCESS_KEY_SECRET
    OSS_REGION
    OSS_BUCKET_NAME
)

# Making sure all required env vars are there
for var in "${REQUIRED_ENV_VARS[@]}" ; do
    if [[ -z "${!var}" ]] ; then
        echo "$var is not set"
        exit -1
    fi
done

export MONGO_PORT=${MONGO_PORT:-27017}
export MONGO_AUTH_DB=${MONGO_AUTH_DB:-admin}
export FILENAME_PREFIX=${FILENAME_PREFIX:-backup}
# CRON_SCHEDULE=${CRON_SCHEDULE:-10 4 * * 1,4}
export CRON_SCHEDULE=${CRON_SCHEDULE:-*/1 * * * *}

echo -e "\
$(env)\n\
$CRON_SCHEDULE /scripts/backup.sh >> /var/log/cron.log 2>&1\
" | crontab -

echo "Done installing crontab"
