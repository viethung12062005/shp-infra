# bootstrap

Tạo tài nguyên thường trực. **SA chạy bằng tay một lần** (tài khoản có quyền Owner trên subscription), sau đó hầu như không đổi.

```bash
az login
cd bootstrap
cat > bootstrap.tfvars <<'T'        # file *.tfvars đã được gitignore
subscription_id     = "<subscription id>"
github_owner        = "<tài khoản GitHub>"
budget_alert_emails = ["<email của bạn>"]
monthly_budget_usd  = <số tiền do PM chốt>
budget_start_date   = "2026-11-01T00:00:00Z"
T
terraform init
terraform plan  -var-file=bootstrap.tfvars -out=tfplan
terraform apply tfplan
```

Sau khi apply:
1. Đặt các output vào GitHub variables (xem `../README.md`): `tfstate_storage_account`, `acr_name`, `github_identity_client_ids`.
2. Chuyển state của chính bootstrap vào storage account vừa tạo (tuỳ chọn): thêm khối `backend "azurerm" {}` rồi `terraform init -migrate-state`.
3. Cấu hình GitHub Environments theo runbook `docs/04-devops/github-setup.md` (repo ứng dụng): `infra-uat`, `infra-uat-destroy`, `infra-prod`, `infra-prod-destroy`.

Lưu ý: identity dựng môi trường có `Contributor` + `Role Based Access Control Administrator` ở phạm vi subscription (cần để tạo tài nguyên và gán quyền).
Khi tách prod sang subscription riêng (NFR-D4), thu hẹp phạm vi này.

## Môi trường bị chặn `Microsoft.Authorization/*/Write` (sandbox)

Một số subscription (ví dụ sandbox `FSO-SandboxOps`) cho phép tạo tài nguyên nhưng **cấm mọi thao tác ghi phân quyền**
và **không cấp `dataActions`**. Kiểm tra bằng:

```bash
az role definition list --name <role> -o json                     # xem notActions / dataActions
az rest --url "https://management.azure.com/subscriptions/<sub>/providers/Microsoft.Authorization/permissions?api-version=2022-04-01"
```

Ở môi trường đó, đặt trong `bootstrap.tfvars`:

```hcl
create_role_assignments = false   # không tạo role assignment
manage_state_container  = false   # không tạo container qua Entra (thiếu dataActions)
acr_sku                 = "Basic" # tuỳ ngân sách
```

`terraform apply` khi đó tạo 19 tài nguyên: resource group, storage account (versioning, soft delete 30 ngày, tắt shared
key), ACR (tắt admin), 6 managed identity + federated credential cho GitHub OIDC, và ngân sách tháng.

Hai việc còn lại cần tài khoản **Owner** trên subscription (một lần):

```bash
# 1) Phân quyền: lấy đúng lệnh từ output
terraform output -json required_role_assignments

# 2) Container chứa state: dùng tài khoản có "Storage Blob Data Contributor" trên storage account
az storage container create --account-name <tfstate_storage_account> --name tfstate --auth-mode login
```

Sau đó đặt GitHub variables theo `../README.md`; identity GitHub chỉ dùng được sau bước 1.
