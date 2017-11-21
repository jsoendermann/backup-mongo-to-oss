#!/bin/bash

set -e

./create-crontab.sh

echo "Launching cron..."
cron
echo "Done launching cron"

touch /var/log/cron.log
tail -f /var/log/cron.log
