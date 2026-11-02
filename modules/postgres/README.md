# Module postgres

PostgreSQL Flexible Server cho scheduling (ADR-0014): chỉ truy cập trong VNet, **chỉ đăng nhập bằng Entra ID** (`password_auth_enabled = false`).
Service đăng nhập bằng token Workload Identity của managed identity `id-<prefix>-scheduling`
(thiết kế: `smart-hospital-platform/docs/03-architecture/detailed-design/02-db-scheduling.md` §5).

## Sau khi apply: tạo principal cho service

Terraform tạo server, database và Entra admin, nhưng **không** tạo được role trong PostgreSQL cho managed identity (cần chạy SQL bằng
token của Entra admin). Làm một lần cho mỗi môi trường, từ máy trong VNet (hoặc jump host), bằng tài khoản là `entra_admin`:

```bash
ENV=uat   # hoặc prod
cd envs/$ENV
PGHOST=$(terraform output -raw postgres_fqdn)
APP=$(terraform output -json workload_identity_names | jq -r .scheduling)
export PGPASSWORD=$(az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv)
ADMIN=$(az ad signed-in-user show --query userPrincipalName -o tsv)

# Tạo role cho managed identity (tên role = tên identity)
psql "host=$PGHOST dbname=postgres user=$ADMIN sslmode=require" \
  -c "select * from pgaadauth_create_principal('$APP', false, false);"

# Quyền trên database scheduling. Flyway chạy trong service nên role cần tạo bảng trong schema public (02-db-scheduling §5).
psql "host=$PGHOST dbname=scheduling user=$ADMIN sslmode=require" <<SQL
GRANT CONNECT, TEMPORARY ON DATABASE scheduling TO "$APP";
GRANT USAGE, CREATE ON SCHEMA public TO "$APP";
SQL
```

Kiểm tra: pod scheduling khởi động, Flyway in `Successfully applied`, `/health/ready` trả 200.

Bảo mật:
- Token của admin chỉ sống khoảng 1 giờ, chỉ để trong biến môi trường của phiên shell; không ghi vào file hay lịch sử lệnh.
- Không bật lại password auth để "cho nhanh"; không tạo user có mật khẩu.
- Khi tách migration ra Job riêng (`scheduling_migrator`), thu hồi quyền `CREATE` trên schema của role service.
