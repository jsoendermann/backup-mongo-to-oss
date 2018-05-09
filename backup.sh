#!/bin/bash

echo "===================> Starting backup at $(date)..."

(
  set -e

  # Files & dirs
  BACKUP_DIR="/tmp-dir"
  DATE=$(date -u "+%F-%H%M%S")
  BACKUP_NAME="${FILENAME_PREFIX}-$DATE"
  ARCHIVE_NAME="$BACKUP_NAME.tar.bz2"
  ARCHIVE_NAME_ENC="$ARCHIVE_NAME.enc"
  ARCHIVE_FILE="$BACKUP_DIR/$ARCHIVE_NAME"
  ARCHIVE_FILE_ENC="$BACKUP_DIR/$ARCHIVE_NAME_ENC"

  echo "===================> Locking db"
  mongo \
    --username "$MONGO_USERNAME" \
    --password "$MONGO_PASSWORD" \
    --authenticationDatabase "$MONGO_AUTH_DB" \
    "${MONGO_HOST}:${MONGO_PORT}" \
    --eval "printjson(db.fsyncLock());"

  echo "===================> Dumping db..."
  mongodump \
    --host "$MONGO_HOST" \
    --port "$MONGO_PORT" \
    --db "$MONGO_DB" \
    --username "$MONGO_USERNAME" \
    --password "$MONGO_PASSWORD" \
    --authenticationDatabase "$MONGO_AUTH_DB" \
    --out "$BACKUP_DIR/$BACKUP_NAME"
  echo "===================> Dump complete"

  echo "===================> Unlocking db"
  mongo \
    --username "$MONGO_USERNAME" \
    --password "$MONGO_PASSWORD" \
    --authenticationDatabase "$MONGO_AUTH_DB" \
    "${MONGO_HOST}:${MONGO_PORT}" \
    --eval "printjson(db.fsyncUnlock());"

  echo "===================> Zipping"
  tar -C "$BACKUP_DIR/" -jcvf "$ARCHIVE_FILE" "$BACKUP_NAME/"

  echo "===================> Encrypting"
  openssl aes-256-cbc -in "$ARCHIVE_FILE" -k "$ENCRYPTION_KEY" -out "$ARCHIVE_FILE_ENC"

  echo "===================> Uploading..."
  RESOURCE="/${OSS_BUCKET_NAME}/${ARCHIVE_NAME}"
  CONTENT_MD5=$(openssl dgst -md5 -binary "${ARCHIVE_FILE_ENC}" | openssl enc -base64)
  CONTENT_TYPE=$(file -ib "${ARCHIVE_FILE_ENC}" |awk -F ";" '{print $1}')
  DATE_VALUE="`TZ=GMT date +'%a, %d %b %Y %H:%M:%S GMT'`"
  STRING_TO_SIGN="PUT\n${CONTENT_MD5}\n${CONTENT_TYPE}\n${DATE_VALUE}\n${RESOURCE}"
  SIGNATURE=$(echo -e -n $STRING_TO_SIGN | openssl dgst -sha1 -binary -hmac $OSS_ACCESS_KEY_SECRET | openssl enc -base64)
  URL="http://${OSS_BUCKET_NAME}.${OSS_REGION}.aliyuncs.com/${ARCHIVE_NAME_ENC}"
  curl -i -q -X PUT -T "${ARCHIVE_FILE_ENC}" \
    -H "Host: ${OSS_BUCKET_NAME}.${OSS_REGION}.aliyuncs.com" \
    -H "Date: ${DATE_VALUE}" \
    -H "Content-Type: ${CONTENT_TYPE}" \
    -H "Content-MD5: ${CONTENT_MD5}" \
    -H "Authorization: OSS ${OSS_ACCESS_KEY_ID}:${SIGNATURE}" \
    ${URL}
  echo "===================> Upload complete"

  if [[ ! -z "$WEBHOOK_URL" ]]; then
    curl -X POST -H "Content-Type: application/json" -d '{"success": true}' "$WEBHOOK_URL" || true
  fi
)
if [[ $? != 0 ]]; then
  (>&2 echo "!!!!!!!!!!!!!!!!!!!> An error occurred while backing up the db!")

  if [[ ! -z "$WEBHOOK_URL" ]]; then
    curl -X POST -H "Content-Type: application/json" -d '{"success": false}' "$WEBHOOK_URL" || true
  fi
fi

echo "===================> Deleting temporary files"
rm -rf "$BACKUP_DIR/*"

echo "===================> Done!"
echo ""