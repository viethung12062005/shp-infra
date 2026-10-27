# shp-infra

Hạ tầng Azure bằng Terraform cho Smart Hospital Platform. Quyết định: ADR-0004, ADR-0009, **ADR-0011** (repo ứng dụng).

**Chỉ có 2 môi trường cloud, cả hai ephemeral**: `uat` (thử tích hợp, đo hiệu năng) và `prod` (chỉ dựng khi demo). Dev chạy trên máy cá nhân, không cần repo này.

```
bootstrap/        tài nguyên thường trực: state, ACR, identity GitHub OIDC, ngân sách   (chạy tay MỘT lần)
modules/          network · monitoring · keyvault · aks · environment (ghép các module trên)
envs/uat, prod    hai stack; khác nhau về kích cỡ (sizing) và mức bảo vệ (purge protection, SKU AKS)
.github/workflows ci · env-provision · env-destroy · cost-guard
```

## Quy trình
1. **Một lần** (SA, bằng tay): chạy `bootstrap/` (xem `bootstrap/README.md`), cấu hình GitHub variables và Environments.
2. **Dựng môi trường:** Actions → `env-provision` → chọn `uat`/`prod` → xem kế hoạch → **duyệt ở Environment `infra-<env>`** → apply.
3. **Hủy môi trường:** Actions → `env-destroy` → gõ `destroy-<env>` → **duyệt ở Environment `infra-<env>-destroy`**.
4. Mọi thay đổi code hạ tầng đi qua PR; `ci` chỉ kiểm tĩnh (fmt, validate, tflint, Trivy), **không apply**.

## Bảo mật (mặc định)
- Không có secret trong repo: Azure OIDC federated credential, quyền tối thiểu theo từng identity; state trong Storage Account tắt shared key, bật versioning.
- AKS: Entra ID RBAC (tắt tài khoản cục bộ), Workload Identity, Azure CNI Overlay + Cilium, Key Vault CSI, trải 3 availability zone, **API server chỉ cho dải IP khai báo** (`authorized_ip_ranges`, bắt buộc, cấm `0.0.0.0/0`).
- Key Vault: RBAC, không public, private endpoint; prod bật purge protection. Tên có hậu tố ngẫu nhiên để dựng lại được.
- Bootstrap bằng `az aks command invoke` (không mở API server cho runner).

## GitHub variables cần có (không phải secret)
`AZURE_TENANT_ID` · `AZURE_SUBSCRIPTION_ID` · `TFSTATE_STORAGE_ACCOUNT` · `ACR_NAME` · `ADMIN_IP_RANGES` (JSON, ví dụ `["203.0.113.5/32"]`) ·
`AZURE_CLIENT_ID_CI_PLAN` · `AZURE_CLIENT_ID_INFRA_UAT` · `AZURE_CLIENT_ID_INFRA_UAT_DESTROY` · `AZURE_CLIENT_ID_INFRA_PROD` · `AZURE_CLIENT_ID_INFRA_PROD_DESTROY`
(các giá trị client id lấy từ output `github_identity_client_ids` của bootstrap).

## Đã có / còn thiếu
| Đã có (đã `fmt` + `validate` + tflint + Trivy sạch) | Còn lại (backlog) |
|---|---|
| bootstrap, network, monitoring, Key Vault, AKS (3 node pool), 2 stack, 4 workflow | IAC-09..14 module dữ liệu (PostgreSQL, Cosmos DB for MongoDB, Redis, Storage, Service Bus, AI Search), IAC-15 workload identity theo service, IAC-16 Entra app, IAC-18/19 Defender + Azure OpenAI |
| | OBS-01: nối Managed Prometheus (cần data collection rule), Grafana |
| | ENV-01: bước cài Argo CD + GitOps + seed trong `env-provision` (cần repo GitOps) |

> **Chưa `apply` lên Azure** (theo quy tắc dự án) và chưa chạy workflow trên GitHub thật. Plugin `azurerm` của tflint chưa chạy được ở nơi viết code; CI sẽ chạy.
> Chi phí: AKS tính tiền theo giờ khi môi trường tồn tại; `cost-guard` cảnh báo môi trường quá TTL. Ước tính chi tiết: task PRD-05.
