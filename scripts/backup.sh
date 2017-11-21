#!/bin/bash

set -e

echo "===================> Starting backup at $(date)... <==================="

env

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
CONTENT_TYPE=`file -ib ${ARCHIVE_FILE} |awk -F ";" '{print $1}'`
DATE_VALUE="`TZ=GMT date +'%a, %d %b %Y %H:%M:%S GMT'`"
STRING_TO_SIGN="PUT\n\n${CONTENT_TYPE}\n${DATE_VALUE}\n${RESOURCE}"
SIGNATURE=`echo -en ${STRING_TO_SIGN} | openssl sha1 -hmac ${OSS_ACCESS_KEY_SECRET} -binary | base64`
URL=http://oss-cn-hongkong.aliyuncs.com/${RESOURCE}
curl -i -q -X PUT -T "${ARCHIVE_FILE}" \
  -H "Host: ${OSS_BUCKET_NAME}.${OSS_REGION}.aliyuncs.com" \
  -H "Date: ${DATE_VALUE}" \
  -H "Content-Type: ${CONTENT_TYPE}" \
  -H "Authorization: OSS ${OSS_ACCESS_KEY_ID}:${SIGNATURE}" \
  ${URL}

# HEADER_DATE=$(date -u "+%a, %d %b %Y %T %z")
# CONTENT_MD5=$(openssl dgst -md5 -binary $BACKUP_DIR/$ARCHIVE_NAME | openssl enc -base64)
# CONTENT_TYPE="application/x-download"
# STRING_TO_SIGN="PUT\n$CONTENT_MD5\n$CONTENT_TYPE\n$HEADER_DATE\n/$S3_BUCKET/$ARCHIVE_NAME"
# SIGNATURE=$(echo -e -n $STRING_TO_SIGN | openssl dgst -sha1 -binary -hmac $AWS_SECRET_KEY | openssl enc -base64)

# echo "Uploading"
# curl -X PUT \
# --header "Host: $S3_BUCKET.s3-$S3_REGION.amazonaws.com" \
# --header "Date: $HEADER_DATE" \
# --header "content-type: $CONTENT_TYPE" \
# --header "Content-MD5: $CONTENT_MD5" \
# --header "Authorization: AWS $AWS_ACCESS_KEY:$SIGNATURE" \
# --upload-file $BACKUP_DIR/$ARCHIVE_NAME \
# https://$S3_BUCKET.s3-$S3_REGION.amazonaws.com/$ARCHIVE_NAME

# echo "Deleting backup dir"
# rm -r $BACKUP_DIR/

echo "===================> Upload complete <==================="

# TODO webhook

echo "===================> Done! <==================="
