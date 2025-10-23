-- Set the default timezone for the cluster and template databases
-- This file is executed by the official Postgres image during first initialization

-- Set the timezone for the current session (postgres template/init run)
SET TIME ZONE 'America/Sao_Paulo';

-- Persist the timezone in the postgres configuration by altering the template databases
-- so that newly created databases inherit the timezone setting.
ALTER DATABASE postgres SET TIMEZONE TO 'America/Sao_Paulo';
ALTER DATABASE template1 SET TIMEZONE TO 'America/Sao_Paulo';

-- Optionally set for public or any additional initial DBs created by init scripts
-- If you need to set timezone for a specific DB you can run:
-- ALTER DATABASE your_db_name SET TIMEZONE TO 'America/Sao_Paulo';
