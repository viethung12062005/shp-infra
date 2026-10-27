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
