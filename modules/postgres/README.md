# Module postgres

PostgreSQL Flexible Server for scheduling (ADR-0014): reachable only inside the VNet, **Entra ID sign-in only** (`password_auth_enabled = false`).
The service signs in with the Workload Identity token of the managed identity `id-<prefix>-scheduling`
(design: `smart-hospital-platform/docs/03-architecture/detailed-design/02-db-scheduling.md` §5).

## After apply: create the principal for the service

Terraform creates the server, the database and the Entra admin, but it **cannot** create the PostgreSQL role for the managed identity (that needs SQL run with
the Entra admin's token). Do it once per environment, from a machine inside the VNet (or a jump host), with the account that is `entra_admin`:

```bash
ENV=uat   # or prod
cd envs/$ENV
PGHOST=$(terraform output -raw postgres_fqdn)
APP=$(terraform output -json workload_identity_names | jq -r .scheduling)
export PGPASSWORD=$(az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv)
ADMIN=$(az ad signed-in-user show --query userPrincipalName -o tsv)

# Create the role for the managed identity (role name = identity name)
psql "host=$PGHOST dbname=postgres user=$ADMIN sslmode=require" \
  -c "select * from pgaadauth_create_principal('$APP', false, false);"

# Permissions on the scheduling database. Flyway runs inside the service, so the role must create tables in schema public (02-db-scheduling §5).
psql "host=$PGHOST dbname=scheduling user=$ADMIN sslmode=require" <<SQL
GRANT CONNECT, TEMPORARY ON DATABASE scheduling TO "$APP";
GRANT USAGE, CREATE ON SCHEMA public TO "$APP";
SQL
```

Check: the scheduling pod starts, Flyway prints `Successfully applied`, `/health/ready` returns 200.

Security:
- The admin token lives about 1 hour and stays only in an environment variable of the shell session; never write it to a file or the command history.
- Do not turn password auth back on "to be quick"; do not create a user with a password.
- When migration moves to its own Job (`scheduling_migrator`), revoke `CREATE` on the schema from the service role.
