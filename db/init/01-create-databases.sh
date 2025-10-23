#!/usr/bin/env bash
set -eu

# This script runs during the Postgres image initialization phase.
# It expects the environment variable APP_DB_PASSWORD to be set (injected via .env or env_file).

if [ -z "${APP_DB_PASSWORD:-}" ]; then
  echo "APP_DB_PASSWORD is not set. Exiting." >&2
  exit 2
fi

# Create database and user. Using psql with here-doc to run as the default postgres user.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-SQL
  CREATE DATABASE gpsvoices;
  CREATE USER gps WITH ENCRYPTED PASSWORD '${APP_DB_PASSWORD}';
  GRANT ALL PRIVILEGES ON DATABASE gpsvoices TO gps;
SQL
