# shp-infra

Hạ tầng Azure bằng Terraform cho Smart Hospital Platform. Quyết định: ADR-0004, ADR-0009, **ADR-0011** (repo ứng dụng).

**Chỉ có 2 môi trường cloud, cả hai ephemeral**: `uat` (thử tích hợp, đo hiệu năng) và `prod` (chỉ dựng khi demo). Dev chạy trên máy cá nhân, không cần repo này.

```
bootstrap/        tài nguyên thường trực: state, ACR, identity GitHub OIDC, ngân sách   (chạy tay MỘT lần)
modules/          network · monitoring · keyvault · aks · environment (ghép các module dưới đây)
                  dữ liệu: postgres · mongodb · redis · servicebus · storage · search · private-endpoint
                  danh tính và giám sát: workload-identity · observability (Managed Prometheus + Grafana)
envs/uat, prod    hai stack; khác nhau về kích cỡ (sizing) và mức bảo vệ (purge protection, SKU AKS)
.github/workflows ci · env-provision · env-destroy · cost-guard
```

## Quy trình
1. **Một lần** (SA, bằng tay): chạy `bootstrap/` (xem `bootstrap/README.md`), cấu hình GitHub variables và Environments.
2. **Dựng môi trường:** Actions → `env-provision` → chọn `uat`/`prod` → plan → apply → cài Argo CD và áp dụng `shp-gitops/bootstrap/root-<env>.yaml` (ENV-01). Từ đây Argo CD tự dựng mọi thứ trong cụm từ `shp-gitops`.
3. **Hủy môi trường:** Actions → `env-destroy` → gõ `destroy-<env>`.

**Ai được chạy:** chỉ chủ repo. Gói GitHub hiện tại không cho đặt người duyệt Environment ở repo private, nên mỗi workflow tự kiểm tra `github.triggering_actor` và dừng ngay nếu không phải chủ repo. Muốn xem kế hoạch trước khi apply: chạy `ci` trên PR, hoặc đọc phần Summary của job `plan`.
4. Mọi thay đổi code hạ tầng đi qua PR; `ci` chỉ kiểm tĩnh (fmt, validate, tflint, Trivy), **không apply**.

## Bảo mật (mặc định)
- Không có secret trong repo: Azure OIDC federated credential, quyền tối thiểu theo từng identity; state trong Storage Account tắt shared key, bật versioning.
- AKS: Entra ID RBAC (tắt tài khoản cục bộ), Workload Identity, Azure CNI Overlay + Cilium, Key Vault CSI, trải 3 availability zone, **API server chỉ cho dải IP khai báo** (`authorized_ip_ranges`, bắt buộc, cấm `0.0.0.0/0`).
- Key Vault: RBAC, không public, private endpoint; prod bật purge protection. Tên có hậu tố ngẫu nhiên để dựng lại được.
- Bootstrap bằng `az aks command invoke` (không mở API server cho runner).

## Dịch vụ dữ liệu, hàng đợi và giám sát

Thiết kế gốc: ADR-0008, ADR-0014 và `detailed-design/05, 06, 13` (repo ứng dụng). Module `environment` dựng tất cả cùng cụm AKS.

| Module | Dịch vụ Azure | Ai dùng | Bảo mật |
|---|---|---|---|
| `postgres` | PostgreSQL Flexible Server, database `scheduling` | scheduling | Trong VNet, không địa chỉ công khai, chỉ đăng nhập Entra ID (tắt mật khẩu), mở rộng `btree_gist` |
| `mongodb` | Cosmos DB for MongoDB vCore | clinical, document, ai, notification, ml | Private endpoint, tắt truy cập công khai, mỗi service một người dùng Entra chỉ `readWrite` trên database của mình |
| `redis` | Azure Managed Redis | gateway (giới hạn tốc độ), scheduling (cache slot) | Private endpoint, tắt khóa truy cập, chỉ Entra ID |
| `servicebus` | Service Bus, topic `shp-events`, 7 subscription có bộ lọc, DLQ sau 5 lần giao | tất cả (phát), consumer (nhận) | Tắt SAS key, Entra ID, TLS 1.2; Premium có private endpoint |
| `storage` | Hai storage account: tài liệu (`documents`, `quarantine`, `kb`, `mlops`) và audit WORM | document, ai, ml, audit | Tắt shared key, private endpoint, versioning và xóa mềm 14 ngày; audit bất biến (prod 10 năm, khóa) |
| `search` | Azure AI Search | ai | Tắt khóa API, private endpoint |
| `workload-identity` | Mỗi service một managed identity + federated credential | tất cả | Pod đăng nhập bằng token ServiceAccount, không có mật khẩu |
| `observability` | Managed Prometheus (thu metric AKS, 4 cảnh báo hạ tầng) và Managed Grafana | SA, DevOps | Grafana chỉ đăng nhập Entra ID, không phát API key |

**Sau khi dựng (việc thủ công còn lại, vì là mặt phẳng dữ liệu nên Terraform không làm được):**
1. PostgreSQL: dùng `workload_identity_client_ids` (output của stack) để tạo vai trò Entra cho `scheduling` trong database (`pgaadauth_create_principal`), rồi cấp quyền tối thiểu. Job migration của scheduling làm bước này.
2. Điền `workloadIdentity.clientId` và `serviceAccount.name: <service>` vào values từng service trong `shp-gitops` (tên ServiceAccount trùng tên service, namespace `shp-apps`).
3. Service Bus: định dạng thuộc tính `type` dùng trong bộ lọc phải khớp cách thư viện phát event ghi CloudEvents (xem `13-events.md`); kiểm bằng một event thử trước khi bật consumer.
4. Mongo: tài khoản quản trị gốc (`shpadmin`) chỉ nằm trong state, không service nào dùng. Sau khi dựng, tắt `NativeAuth` ở prod khi đã xác nhận đăng nhập Entra chạy được.

**Chi phí khi dựng môi trường (theo giờ, ước lượng, tính bằng đơn giá công khai):** Service Bus Premium là khoản lớn nhất (khoảng 0,9 USD/giờ), tiếp theo Cosmos DB MongoDB vCore M10 và AI Search Basic. Môi trường thử sống tối đa 8 giờ (cost-guard) nên phần này đáng kể nhưng có giới hạn. Muốn rẻ hơn khi chưa cần private endpoint cho hàng đợi: đặt `messaging_sku = "Standard"` (namespace mở cổng công khai, chỉ Entra ID, event mang mã bệnh nhân nên **không dùng cho dữ liệu thật**).

## GitHub variables cần có (không phải secret)
`AZURE_TENANT_ID` · `AZURE_SUBSCRIPTION_ID` · `TFSTATE_STORAGE_ACCOUNT` · `ACR_NAME` · `ADMIN_IP_RANGES` (JSON, ví dụ `["203.0.113.5/32"]`) ·
`AZURE_CLIENT_ID_CI_PLAN` · `AZURE_CLIENT_ID_INFRA_UAT` · `AZURE_CLIENT_ID_INFRA_UAT_DESTROY` · `AZURE_CLIENT_ID_INFRA_PROD` · `AZURE_CLIENT_ID_INFRA_PROD_DESTROY`
(các giá trị client id lấy từ output `github_identity_client_ids` của bootstrap).

`AZURE_CLIENT_ID_CHART_PUSH` (identity đẩy Helm chart) đặt ở repo **shp-platform-templates**; `AZURE_CLIENT_ID_ACR_PUSH` đặt ở repo ứng dụng.

**Azure chỉ tin nhánh `main`:**
- Identity theo `ref` (`ci-plan`: repo này; `acr-push`: repo ứng dụng) chỉ nhận token từ `refs/heads/main`. Nhánh khác, PR hay fork có subject khác nên Azure từ chối.
- Identity theo Environment (`infra-<env>`, `infra-<env>-destroy`, `release-chart`) dựa vào *deployment branch policy*: Environment chỉ cho nhánh `main` (riêng `release-chart` chỉ cho tag `chart-v*`). Job trên nhánh khác bị GitHub từ chối trước khi xin được token. Đã kiểm chứng trên gói hiện tại bằng một nhánh thử.
- Không dùng cho CI trên pull request: PR chỉ kiểm tĩnh, không đăng nhập Azure.

Cho bước ENV-01 (Argo CD đọc repo private): một GitHub App **chỉ đọc** (`Contents: Read`, `Metadata: Read`) cài trên `shp-gitops` và `shp-platform-templates`.
Variable `ARGOCD_REPO_APP_ID`, `ARGOCD_REPO_APP_INSTALLATION_ID`; secret `ARGOCD_REPO_APP_PRIVATE_KEY`.
Identity `AZURE_CLIENT_ID_INFRA_<ENV>` cần thêm quyền chạy `az aks command invoke` và quản trị cụm (ví dụ vai trò *Azure Kubernetes Service RBAC Cluster Admin* trên cụm của môi trường đó).

## Đã có / còn thiếu
| Đã có (đã `fmt` + `validate` + tflint + Trivy sạch) | Còn lại (backlog) |
|---|---|
| bootstrap, network, monitoring, Key Vault, AKS (3 node pool), 2 stack, 4 workflow | IAC-09..14 module dữ liệu (PostgreSQL, Cosmos DB for MongoDB, Redis, Storage, Service Bus, AI Search), IAC-15 workload identity theo service, IAC-16 Entra app, IAC-18/19 Defender + Azure OpenAI |
| | OBS-01: nối Managed Prometheus (cần data collection rule), Grafana |
| ENV-01: `env-provision` cài Argo CD và giao cụm cho GitOps (chưa chạy thử trên Azure thật) | ENV-01 phần còn lại: nạp dữ liệu tổng hợp, smoke test sau khi dựng |

> **Chưa `apply` lên Azure** (theo quy tắc dự án) và chưa chạy workflow trên GitHub thật. Plugin `azurerm` của tflint chưa chạy được ở nơi viết code; CI sẽ chạy.
> Chi phí: AKS tính tiền theo giờ khi môi trường tồn tại; `cost-guard` cảnh báo môi trường quá TTL. Ước tính chi tiết: task PRD-05.
