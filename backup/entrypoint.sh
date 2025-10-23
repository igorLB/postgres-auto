#!/usr/bin/env bash
set -euo pipefail

# Environment variables expected:
# PGPASSWORD - Postgres password
# PGUSER - Postgres user (default: gps)
# PGHOST - Postgres host (default: postgres)
# BACKUP_RETAIN - number of backups to keep (default: 7)

PGUSER=${PGUSER:-gps}
PGHOST=${PGHOST:-postgres}
PGPASSWORD=${PGPASSWORD:-}
BACKUP_RETAIN=${BACKUP_RETAIN:-7}

if [ -z "${PGPASSWORD}" ]; then
  echo "PGPASSWORD is not set. Exiting." >&2
  exit 2
fi

export PGPASSWORD

mkdir -p /backups

# Helper to perform a single backup
perform_backup() {
  timestamp=$(date +%Y%m%d_%H%M%S)
  outfile="/backups/backup_${timestamp}.sql"
  echo "[Backup] Starting backup at ${timestamp}..."

  # Run pg_dumpall and capture exit code
  if pg_dumpall -h "${PGHOST}" -U "${PGUSER}" > "${outfile}"; then
    echo "[Backup] Completed: ${outfile}"
  else
    echo "[Backup] pg_dumpall failed. Removing incomplete file if exists." >&2
    rm -f "${outfile}"
    return 1
  fi

  # Remove old backups, keep the most recent $BACKUP_RETAIN
  if [ "${BACKUP_RETAIN}" -gt 0 ]; then
    files_to_delete=$(ls -1t /backups/backup_*.sql 2>/dev/null | tail -n +$((${BACKUP_RETAIN} + 1)) || true)
    if [ -n "${files_to_delete}" ]; then
      echo "[Backup] Removing old backups:";
      echo "${files_to_delete}" | xargs -r rm -f --
    else
      echo "[Backup] No old backups to remove"
    fi
  fi

  return 0
}

# Run a single backup and exit (this container is designed to be one-shot so cron or orchestration can schedule it)
perform_backup
exit $?
