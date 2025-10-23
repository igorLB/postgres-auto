Postgres Auto backup


1) Create the external Docker network if it doesn't exist


2) Configure environment in the `.env` file (a template is included). The compose file reads credentials and backup settings from this file.

Important: a template `.env.dist` is provided. Copy it to `.env` and fill in secure passwords. Do NOT commit `.env` to source control. The initialization scripts read `APP_DB_PASSWORD` from `.env` to create the application user securely.

3) Build and start services:

```bash
docker compose up -d --build
```

4) Run a single one-shot backup for testing using the built image:

```bash
# Use the built image entrypoint with argument 'once'
docker compose run --rm backup once
```

Install the crontab line (edit paths as needed):

```bash
# on your VPS
crontab backup/backup.crontab
```


## Why POSTGRES_PASSWORD and APP_DB_PASSWORD?
POSTGRES_PASSWORD
Used by the official Postgres image to set the initial superuser password (the user named by POSTGRES_USER, default postgres). It's what the image uses during non-interactive initial cluster setup so the container has an admin account.
APP_DB_PASSWORD
Used by your init script to create the application database user (the gps user in your repo). It is the password given to the app user the repo creates (so the app can connect to its DB).