#!/bin/bash

set -e

echo "===================> Starting backup at $(date)... <==================="

# Files & dirs
BACKUP_DIR="/tmp-dir"
DATE=$(date -u "+%F-%H%M%S")
BACKUP_NAME="${FILENAME_PREFIX}-$DATE"
ARCHIVE_NAME="$BACKUP_NAME.tar.bz2"
ARCHIVE_FILE="$BACKUP_DIR/$ARCHIVE_NAME"
echo "Backup dir: $BACKUP_DIR; BACKUP_NAME: $BACKUP_NAME; ARCHIVE_NAME: $ARCHIVE_NAME"

echo "===================> Locking db <==================="
mongo \
  --username "$MONGO_USERNAME" \
  --password "$MONGO_PASSWORD" \
  --authenticationDatabase "$MONGO_AUTH_DB" \
  "${MONGO_HOST}:${MONGO_PORT}" \
  --eval "printjson(db.fsyncLock());"

echo "===================> Dumping db... <==================="
mongodump \
  --host "$MONGO_HOST" \
  --port "$MONGO_PORT" \
  --db "$MONGO_DB" \
  --username "$MONGO_USERNAME" \
  --password "$MONGO_PASSWORD" \
  --authenticationDatabase "$MONGO_AUTH_DB" \
  --out "$BACKUP_DIR/$BACKUP_NAME"
echo "===================> Dump complete <==================="

echo "===================> Unlocking db <==================="
mongo \
  --username "$MONGO_USERNAME" \
  --password "$MONGO_PASSWORD" \
  --authenticationDatabase "$MONGO_AUTH_DB" \
  "${MONGO_HOST}:${MONGO_PORT}" \
  --eval "printjson(db.fsyncUnlock());"

echo "===================> Zipping <==================="
tar -C "$BACKUP_DIR/" -jcvf "$ARCHIVE_FILE" "$BACKUP_NAME/"

echo "===================> Uploading... <==================="
RESOURCE="/${OSS_BUCKET_NAME}/${ARCHIVE_NAME}"
CONTENT_MD5=$(openssl dgst -md5 -binary "${ARCHIVE_FILE}" | openssl enc -base64)
CONTENT_TYPE=$(file -ib "${ARCHIVE_FILE}" |awk -F ";" '{print $1}')
DATE_VALUE="`TZ=GMT date +'%a, %d %b %Y %H:%M:%S GMT'`"
STRING_TO_SIGN="PUT\n${CONTENT_MD5}\n${CONTENT_TYPE}\n${DATE_VALUE}\n${RESOURCE}"
SIGNATURE=$(echo -e -n $STRING_TO_SIGN | openssl dgst -sha1 -binary -hmac $OSS_ACCESS_KEY_SECRET | openssl enc -base64)
URL="http://${OSS_BUCKET_NAME}.${OSS_REGION}.aliyuncs.com/${ARCHIVE_NAME}"
curl -i -q -X PUT -T "${ARCHIVE_FILE}" \
  -H "Host: ${OSS_BUCKET_NAME}.${OSS_REGION}.aliyuncs.com" \
  -H "Date: ${DATE_VALUE}" \
  -H "Content-Type: ${CONTENT_TYPE}" \
  -H "Content-MD5: ${CONTENT_MD5}" \
  -H "Authorization: OSS ${OSS_ACCESS_KEY_ID}:${SIGNATURE}" \
  ${URL}
echo "===================> Upload complete <==================="

echo "===================> Clearing temp files <==================="
rm -rf "$BACKUP_DIR/*"

# TODO webhook

echo "===================> Done! <==================="
