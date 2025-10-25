#!/usr/bin/env bash
set -euo pipefail

# Environment variables expected:
# PGPASSWORD - Postgres password
# PGUSER - Postgres user (default: gps)
# PGHOST - Postgres host (default: postgres)
# BACKUP_RETAIN - number of backups to keep locally (default: 7)
# BACKUP_COMPRESS - compress backups with gzip (default: true)
# 
# Object Storage Upload (optional - S3-compatible):
# S3_ENABLED - set to "true" to enable upload
# S3_BUCKET - bucket name
# S3_ENDPOINT - endpoint URL (for R2: https://<account-id>.r2.cloudflarestorage.com)
# S3_REGION - region (default: auto)
# S3_PREFIX - optional prefix/folder in bucket (e.g., postgres/)
# AWS_ACCESS_KEY_ID - access key
# AWS_SECRET_ACCESS_KEY - secret key

PGUSER=${PGUSER:-gps}
PGHOST=${PGHOST:-postgres}
PGPASSWORD=${PGPASSWORD:-}
BACKUP_RETAIN=${BACKUP_RETAIN:-7}
BACKUP_COMPRESS=${BACKUP_COMPRESS:-true}

S3_ENABLED=${S3_ENABLED:-false}
S3_BUCKET=${S3_BUCKET:-}
S3_ENDPOINT=${S3_ENDPOINT:-}
S3_REGION=${S3_REGION:-auto}
S3_PREFIX=${S3_PREFIX:-}

if [ -z "${PGPASSWORD}" ]; then
  echo "PGPASSWORD is not set. Exiting." >&2
  exit 2
fi

export PGPASSWORD

# Validate S3 configuration if enabled
if [ "${S3_ENABLED}" = "true" ]; then
  if [ -z "${S3_BUCKET}" ] || [ -z "${S3_ENDPOINT}" ] || [ -z "${AWS_ACCESS_KEY_ID}" ] || [ -z "${AWS_SECRET_ACCESS_KEY}" ]; then
    echo "[S3] ERROR: S3_ENABLED is true but required S3 credentials are missing." >&2
    exit 2
  fi
  echo "[S3] Upload enabled to bucket: ${S3_BUCKET}"
fi

mkdir -p /backups

# Helper to upload to S3-compatible storage (e.g., R2)
upload_to_s3() {
  local file=$1
  local filename=$(basename "${file}")
  local s3_key="${S3_PREFIX}${ENV:-dev}/${filename}"

  echo "[S3] Uploading ${filename} to ${S3_BUCKET}/${s3_key}..."
  
  if aws s3 cp "${file}" "s3://${S3_BUCKET}/${s3_key}" \
    --endpoint-url "${S3_ENDPOINT}" \
    --region "${S3_REGION}"; then
    echo "[S3] Upload successful: ${s3_key}"
    # Get file size for logging
    local filesize=$(du -h "${file}" | cut -f1)
    echo "[S3] Uploaded size: ${filesize}"

    # Also upload a 'latest' copy (keep compression suffix if present)
    local latest_name
    if [[ "${filename}" == *.gz ]]; then
      # e.g. backup_20250101_000000.sql.gz -> backup_latest.sql.gz
      latest_name="backup_latest.sql.gz"
    else
      latest_name="backup_latest.sql"
    fi
    local s3_key_latest="${S3_PREFIX}${ENV:-dev}/${latest_name}"

    echo "[S3] Uploading latest copy as ${latest_name} to ${S3_BUCKET}/${s3_key_latest}..."
    if aws s3 cp "${file}" "s3://${S3_BUCKET}/${s3_key_latest}" \
      --endpoint-url "${S3_ENDPOINT}" \
      --region "${S3_REGION}"; then
      echo "[S3] Latest upload successful: ${s3_key_latest}"
    else
      echo "[S3] WARNING: Latest upload failed for ${latest_name}" >&2
      # Don't fail the whole operation because the primary (timestamped) upload succeeded
    fi

    return 0
  else
    echo "[S3] Upload failed for ${filename}" >&2
    return 1
  fi
}

# Helper to perform a single backup
perform_backup() {
  timestamp=$(date +%Y%m%d_%H%M%S)
  local temp_file="/backups/backup_${timestamp}.sql"
  local final_file="${temp_file}"
  
  echo "[Backup] Starting backup at ${timestamp}..."

  # Run pg_dumpall
  if pg_dumpall -h "${PGHOST}" -U "${PGUSER}" > "${temp_file}"; then
    echo "[Backup] Database dump completed"
    
    # Get uncompressed size
    local raw_size=$(du -h "${temp_file}" | cut -f1)
    echo "[Backup] Uncompressed size: ${raw_size}"
  else
    echo "[Backup] pg_dumpall failed. Removing incomplete file if exists." >&2
    rm -f "${temp_file}"
    return 1
  fi

  # Compress if enabled
  if [ "${BACKUP_COMPRESS}" = "true" ]; then
    echo "[Backup] Compressing backup..."
    if gzip -9 "${temp_file}"; then
      final_file="${temp_file}.gz"
      local compressed_size=$(du -h "${final_file}" | cut -f1)
      echo "[Backup] Compressed size: ${compressed_size}"
      echo "[Backup] Completed: ${final_file}"
    else
      echo "[Backup] Compression failed, keeping uncompressed backup" >&2
      final_file="${temp_file}"
    fi
  else
    echo "[Backup] Completed: ${final_file}"
  fi

  # Upload to S3 if enabled
  if [ "${S3_ENABLED}" = "true" ]; then
    if ! upload_to_s3 "${final_file}"; then
      echo "[Backup] WARNING: Backup created but S3 upload failed" >&2
      # Don't exit - local backup still exists
    fi
  else
    echo "[Backup] S3 upload not enabled, skipping upload"
  fi

  # Remove old local backups, keep the most recent $BACKUP_RETAIN
  if [ "${BACKUP_RETAIN}" -gt 0 ]; then
    # Handle both .sql and .sql.gz files
    local pattern="/backups/backup_*.sql*"
    files_to_delete=$(ls -1t ${pattern} 2>/dev/null | tail -n +$((${BACKUP_RETAIN} + 1)) || true)
    if [ -n "${files_to_delete}" ]; then
      echo "[Backup] Removing old local backups:"
      echo "${files_to_delete}" | xargs -r rm -f --
    else
      echo "[Backup] No old local backups to remove"
    fi
  fi

  return 0
}

# Run a single backup and exit
perform_backup
exit $?