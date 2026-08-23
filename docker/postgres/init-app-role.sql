-- Bootstrap executed once per fresh cluster by the postgres image
-- (POSTGRES_USER=app_owner starts as the cluster superuser).
--
-- CIS PostgreSQL Benchmark: the superuser account must not be used for
-- routine database operations. PostgreSQL 17 refuses to demote the bootstrap
-- superuser, so we leave it idle (like a stock `postgres` account) and move
-- all operational duties to `migrator`. Runtime connects as unprivileged
-- `app`; every tenant table is RLS-enabled AND RLS-forced.
--
-- Roles after this script:
--   app_owner  idle bootstrap superuser - owns nothing user-visible
--   migrator   NOSUPERUSER NOBYPASSRLS CREATEDB CREATEROLE - runs migrations,
--              seeds and grants; owns the application databases
--   dbadmin    break-glass LOGIN SUPERUSER (rotate before real deployment)
--   app        unprivileged runtime role

CREATE ROLE dbadmin LOGIN SUPERUSER NOINHERIT PASSWORD 'dbadmin-change-me';
CREATE ROLE migrator LOGIN NOSUPERUSER NOBYPASSRLS NOINHERIT CREATEDB CREATEROLE PASSWORD 'migrator';

ALTER DATABASE foodtruck_ops_development OWNER TO migrator;

CREATE ROLE app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS
  CONNECTION LIMIT 50 ADMIN migrator PASSWORD 'app';
GRANT CONNECT ON DATABASE foodtruck_ops_development TO app;

-- Runtime DoS guardrails (CIS: bound resource consumption). The migrator
-- keeps no persistent statement timeout because schema loads are long.
ALTER ROLE app SET statement_timeout TO '30s';
ALTER ROLE app SET idle_in_transaction_session_timeout TO '60s';
GRANT app TO migrator WITH ADMIN OPTION;
