# shp-infra

Azure infrastructure in Terraform for the Smart Hospital Platform. Decisions: ADR-0004, ADR-0009, **ADR-0011** (application repo).

**There are only 2 cloud environments, both ephemeral**: `uat` (integration testing, performance measurement) and `prod` (provisioned only for the demo). Dev runs on personal machines and does not need this repo.

```
bootstrap/        always-on resources: state, ACR, GitHub OIDC identities, budget   (run by hand ONCE)
modules/          network · monitoring · keyvault · aks · environment (composes the modules below)
                  data: postgres · mongodb · redis · servicebus · storage · search · private-endpoint · defender-storage
                  workload: ai-workload (Ollama model cache + Key Vault CSI reference)
                  identity and monitoring: workload-identity · observability (Managed Prometheus + Grafana)
envs/uat, prod    two stacks; they differ in sizing and protection level (purge protection, AKS SKU)
.github/workflows ci · env-provision · env-destroy · cost-guard
```

## Process
1. **Once** (SA, by hand): run `bootstrap/` (see `bootstrap/README.md`), configure the GitHub variables and Environments.
2. **Provision an environment:** Actions → `env-provision` → choose `uat`/`prod` → plan → apply → install Argo CD and apply `shp-gitops/bootstrap/root-<env>.yaml` (ENV-01). From here Argo CD builds everything inside the cluster from `shp-gitops`.
3. **Destroy an environment:** Actions → `env-destroy` → type `destroy-<env>`.

**Who may run them:** only the repo owner. The current GitHub plan does not allow Environment reviewers on a private repo, so each workflow checks `github.triggering_actor` itself and stops at once if it is not the repo owner. To see the plan before apply: run `ci` on a PR, or read the Summary of the `plan` job.
4. Every infrastructure code change goes through a PR; `ci` runs static checks (fmt, validate, tflint, Trivy) and a read-only `terraform plan` for `envs/uat`, and **never applies**.

## Security (defaults)
- No secrets in the repo: Azure OIDC federated credentials, least privilege per identity; state in a Storage Account with shared keys off and versioning on.
- AKS: Entra ID RBAC (local accounts off), Workload Identity, Azure CNI Overlay + Cilium, Key Vault CSI, spread over 3 availability zones, **API server reachable only from the declared IP ranges** (`authorized_ip_ranges`, required, `0.0.0.0/0` forbidden).
- Key Vault: RBAC, not public, private endpoint; purge protection on in prod. The name has a random suffix so the environment can be rebuilt.
- Defender for Storage scan results go to a keyless Event Grid topic (Entra ID, TLS 1.2) whose public endpoint is required by Defender; the subscription delivers to the queue with a system-assigned managed identity (no SAS key).
- AI provider keys (`deepseek-api-key`, `gemini-api-key`) are stored only in Key Vault and are mounted by the Secrets Store CSI driver with the ai workload identity (`Key Vault Secrets User`). The repository and Helm values contain the secret names, never the values.
- Bootstrap through `az aks command invoke` (the API server is not opened to the runner).
- Required tags are enforced, not set by convention only: the `environment` module assigns the built-in "Require a tag on resources" and "Require a tag on resource groups" policies (both deny) at the resource group scope for `shp-env`, `created-at` and `ttl-hours`. Set `create_tag_policy = false` in `envs/<env>/*.tfvars` where `Microsoft.Authorization/*/Write` is blocked (sandbox).

## Data services, messaging and monitoring

Source design: ADR-0008, ADR-0014 and `detailed-design/05, 06, 13` (application repo). The `environment` module provisions all of them together with the AKS cluster.

| Module | Azure service | Used by | Security |
|---|---|---|---|
| `postgres` | PostgreSQL Flexible Server, database `scheduling` | scheduling | Inside the VNet, no public address, Entra ID sign-in only (passwords off), `btree_gist` extension |
| `mongodb` | Cosmos DB for MongoDB vCore | clinical, document, ai, notification, ml | Private endpoint, public access off, one Entra user per service with `readWrite` on its own database only |
| `redis` | Azure Managed Redis | gateway (rate limiting), scheduling (slot cache) | Private endpoint, access keys off, Entra ID only |
| `servicebus` | Service Bus, topic `shp-events`, 7 filtered subscriptions, the `malware-scan-results` queue, DLQ after 5 deliveries | everyone (publish), consumers (receive), document (scan results) | SAS keys off, Entra ID, TLS 1.2; Premium has a private endpoint |
| `storage` | Two storage accounts: documents (`documents`, `quarantine`, `kb`, `mlops`) and WORM audit | document, ai, ml, audit | Shared keys off, private endpoint, versioning and 14-day soft delete; immutable audit (prod 10 years, locked) |
| `defender-storage` | Defender for Storage malware scanning; Event Grid custom topic and subscription route `Microsoft.Security.MalwareScanningResult` into the `malware-scan-results` queue | document | Topic keyless (Entra ID), delivery with a system-assigned identity; the topic must allow public access because Defender cannot publish to private-endpoint-only topics, and its events carry no clinical data |
| `search` | Azure AI Search | ai | API keys off, private endpoint |
| `workload-identity` | One managed identity + federated credential per service | everyone | Pods sign in with the ServiceAccount token, no passwords |
| `ai-workload` | AKS `ai` node pool (tainted, scales to zero, 256 GB OS disk, GPU-capable) plus the Ollama model-cache PVC and the ai `SecretProviderClass` | ai, Ollama | The ai identity has `Key Vault Secrets User` only; secret values never enter Terraform state or Helm values |
| `observability` | Managed Prometheus (AKS metrics, 4 infrastructure alerts) and Managed Grafana | SA, DevOps | Grafana allows Entra ID sign-in only and issues no API keys |

**After provisioning (remaining manual work — it is data plane, so Terraform cannot do it):**
1. PostgreSQL: use `workload_identity_client_ids` (stack output) to create the Entra role for `scheduling` in the database (`pgaadauth_create_principal`), then grant least privilege. The scheduling migration job does this step.
2. Fill `workloadIdentity.clientId` and `serviceAccount.name: <service>` into each service's values in `shp-gitops` (the ServiceAccount name equals the service name, namespace `shp-apps`).
3. Service Bus: the format of the `type` property used in the filters must match how the event library writes CloudEvents (see `13-events.md`); check with a test event before enabling consumers.
4. Mongo: the root administrator account (`shpadmin`) exists only in the state and no service uses it. After provisioning, turn off `NativeAuth` in prod once Entra sign-in is confirmed to work.
5. Defender for Storage: the subscription needs the Defender for Storage plan before `enable_malware_scan = true` can apply; set it to `false` where the sandbox blocks the plan. The first scan result appears in the `malware-scan-results` queue after an upload.
6. AI provider keys: set `deepseek-api-key` and `gemini-api-key` in Key Vault from a host inside the VNet (the vault has no public endpoint). Terraform deliberately does not manage secret values. Then run the `ai-workload` module as a second apply (`enable_ai_workload = true`, `kubeconfig_path = <the new cluster>`); it creates the Ollama model-cache PVC and the CSI `SecretProviderClass`. Copy the `ai_service_values` stack output into `shp-gitops/envs/<env>/ai/values.yaml` (SCF-06).

**Cost while an environment is up (per hour, estimated from public list prices):** Service Bus Premium is the largest item (about 0.9 USD/hour), followed by Cosmos DB MongoDB vCore M10 and AI Search Basic. A test environment lives at most 8 hours (cost-guard), so this is significant but bounded. To make it cheaper while the queue does not need a private endpoint yet: set `messaging_sku = "Standard"` (the namespace opens a public endpoint, Entra ID only; events carry patient ids, so **do not use it for real data**).

## GitHub variables required (not secrets)
`AZURE_TENANT_ID` · `AZURE_SUBSCRIPTION_ID` · `TFSTATE_STORAGE_ACCOUNT` · `ACR_NAME` · `ADMIN_IP_RANGES` (JSON, for example `["203.0.113.5/32"]`) ·
`AZURE_CLIENT_ID_CI_PLAN` · `AZURE_CLIENT_ID_INFRA_UAT` · `AZURE_CLIENT_ID_INFRA_UAT_DESTROY` · `AZURE_CLIENT_ID_INFRA_PROD` · `AZURE_CLIENT_ID_INFRA_PROD_DESTROY`
(the client id values come from the bootstrap output `github_identity_client_ids`).

`AZURE_CLIENT_ID_CHART_PUSH` (the identity that pushes the Helm chart) is set in the **shp-platform-templates** repo; `AZURE_CLIENT_ID_ACR_PUSH` is set in the application repo.

**Azure trusts the `main` branch and this repo's own pull requests:**
- Identities bound to a `ref` (`ci-plan`: this repo; `acr-push`: the application repo) only get a token from `refs/heads/main`. `ci-plan` additionally trusts this repo's `pull_request` subject, so the CI plan job can sign in on a PR with read-only access.
- Identities bound to an Environment (`infra-<env>`, `infra-<env>-destroy`, `release-chart`) rely on the *deployment branch policy*: the Environment only allows the `main` branch (`release-chart` only allows `chart-v*` tags). A job on another branch is rejected by GitHub before it can request a token. Verified on the current plan with a test branch.
- CI on pull requests signs in to Azure only with the read-only `ci-plan` identity to run `terraform plan` for `envs/uat`; it never applies. Fork PRs are skipped (GitHub withholds variables and refuses OIDC tokens for them).

For the ENV-01 step (Argo CD reading private repos): a **read-only** GitHub App (`Contents: Read`, `Metadata: Read`) installed on `shp-gitops` and `shp-platform-templates`.
Variables `ARGOCD_REPO_APP_ID`, `ARGOCD_REPO_APP_INSTALLATION_ID`; secret `ARGOCD_REPO_APP_PRIVATE_KEY`.
The identity `AZURE_CLIENT_ID_INFRA_<ENV>` additionally needs permission to run `az aks command invoke` and administer the cluster (for example the *Azure Kubernetes Service RBAC Cluster Admin* role on that environment's cluster).

## Done / still missing
| Done (`fmt` + `validate` + tflint + Trivy clean) | Remaining (backlog) |
|---|---|
| bootstrap, network, monitoring, Key Vault, AKS (3 node pools), 2 stacks, 4 workflows | IAC-15 workload identity per service, IAC-16 Entra app, Azure OpenAI |
| IAC-09..14 data modules (PostgreSQL, Cosmos DB for MongoDB, Redis, Storage, Service Bus, AI Search); IAC-18 Defender for Storage + Event Grid scan results | |
| IAC-19 ai node pool + Ollama model-cache PVC + Key Vault CSI reference (the PVC/CSI objects are a second, opt-in apply) | |
| | OBS-01: connect Managed Prometheus (needs a data collection rule), Grafana |
| ENV-01: `env-provision` installs Argo CD and hands the cluster to GitOps (not yet tried on real Azure) | Rest of ENV-01: load synthetic data, smoke test after provisioning |

> **Not yet `apply`-ed to Azure** (per the project rule) and the workflows have not run on real GitHub. The tflint `azurerm` plugin could not run where the code was written; CI runs it.
> Cost: AKS is billed per hour while the environment exists; `cost-guard` warns about environments past their TTL. Detailed estimate: task PRD-05.
