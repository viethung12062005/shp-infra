# shp-infra

Azure infrastructure in Terraform for the Smart Hospital Platform. Decisions: ADR-0004, ADR-0009, **ADR-0011** (application repo).

**There are only 2 cloud environments, both ephemeral**: `uat` (integration testing, performance measurement) and `prod` (provisioned only for the demo). Dev runs on personal machines and does not need this repo.

```
bootstrap/        always-on resources: state, ACR, GitHub OIDC identities, budget   (run by hand ONCE)
modules/          network · monitoring · keyvault · aks · environment (composes the modules below)
                  data: postgres · mongodb · redis · servicebus · storage · search · private-endpoint
                  identity and monitoring: workload-identity · observability (Managed Prometheus + Grafana)
envs/uat, prod    two stacks; they differ in sizing and protection level (purge protection, AKS SKU)
.github/workflows ci · env-provision · env-destroy · cost-guard
```

## Process
1. **Once** (SA, by hand): run `bootstrap/` (see `bootstrap/README.md`), configure the GitHub variables and Environments.
2. **Provision an environment:** Actions → `env-provision` → choose `uat`/`prod` → plan → apply → install Argo CD and apply `shp-gitops/bootstrap/root-<env>.yaml` (ENV-01). From here Argo CD builds everything inside the cluster from `shp-gitops`.
3. **Destroy an environment:** Actions → `env-destroy` → type `destroy-<env>`.

**Who may run them:** only the repo owner. The current GitHub plan does not allow Environment reviewers on a private repo, so each workflow checks `github.triggering_actor` itself and stops at once if it is not the repo owner. To see the plan before apply: run `ci` on a PR, or read the Summary of the `plan` job.
4. Every infrastructure code change goes through a PR; `ci` only runs static checks (fmt, validate, tflint, Trivy) and **never applies**.

## Security (defaults)
- No secrets in the repo: Azure OIDC federated credentials, least privilege per identity; state in a Storage Account with shared keys off and versioning on.
- AKS: Entra ID RBAC (local accounts off), Workload Identity, Azure CNI Overlay + Cilium, Key Vault CSI, spread over 3 availability zones, **API server reachable only from the declared IP ranges** (`authorized_ip_ranges`, required, `0.0.0.0/0` forbidden).
- Key Vault: RBAC, not public, private endpoint; purge protection on in prod. The name has a random suffix so the environment can be rebuilt.
- Bootstrap through `az aks command invoke` (the API server is not opened to the runner).

## Data services, messaging and monitoring

Source design: ADR-0008, ADR-0014 and `detailed-design/05, 06, 13` (application repo). The `environment` module provisions all of them together with the AKS cluster.

| Module | Azure service | Used by | Security |
|---|---|---|---|
| `postgres` | PostgreSQL Flexible Server, database `scheduling` | scheduling | Inside the VNet, no public address, Entra ID sign-in only (passwords off), `btree_gist` extension |
| `mongodb` | Cosmos DB for MongoDB vCore | clinical, document, ai, notification, ml | Private endpoint, public access off, one Entra user per service with `readWrite` on its own database only |
| `redis` | Azure Managed Redis | gateway (rate limiting), scheduling (slot cache) | Private endpoint, access keys off, Entra ID only |
| `servicebus` | Service Bus, topic `shp-events`, 7 filtered subscriptions, DLQ after 5 deliveries | everyone (publish), consumers (receive) | SAS keys off, Entra ID, TLS 1.2; Premium has a private endpoint |
| `storage` | Two storage accounts: documents (`documents`, `quarantine`, `kb`, `mlops`) and WORM audit | document, ai, ml, audit | Shared keys off, private endpoint, versioning and 14-day soft delete; immutable audit (prod 10 years, locked) |
| `search` | Azure AI Search | ai | API keys off, private endpoint |
| `workload-identity` | One managed identity + federated credential per service | everyone | Pods sign in with the ServiceAccount token, no passwords |
| `observability` | Managed Prometheus (AKS metrics, 4 infrastructure alerts) and Managed Grafana | SA, DevOps | Grafana allows Entra ID sign-in only and issues no API keys |

**After provisioning (remaining manual work — it is data plane, so Terraform cannot do it):**
1. PostgreSQL: use `workload_identity_client_ids` (stack output) to create the Entra role for `scheduling` in the database (`pgaadauth_create_principal`), then grant least privilege. The scheduling migration job does this step.
2. Fill `workloadIdentity.clientId` and `serviceAccount.name: <service>` into each service's values in `shp-gitops` (the ServiceAccount name equals the service name, namespace `shp-apps`).
3. Service Bus: the format of the `type` property used in the filters must match how the event library writes CloudEvents (see `13-events.md`); check with a test event before enabling consumers.
4. Mongo: the root administrator account (`shpadmin`) exists only in the state and no service uses it. After provisioning, turn off `NativeAuth` in prod once Entra sign-in is confirmed to work.

**Cost while an environment is up (per hour, estimated from public list prices):** Service Bus Premium is the largest item (about 0.9 USD/hour), followed by Cosmos DB MongoDB vCore M10 and AI Search Basic. A test environment lives at most 8 hours (cost-guard), so this is significant but bounded. To make it cheaper while the queue does not need a private endpoint yet: set `messaging_sku = "Standard"` (the namespace opens a public endpoint, Entra ID only; events carry patient ids, so **do not use it for real data**).

## GitHub variables required (not secrets)
`AZURE_TENANT_ID` · `AZURE_SUBSCRIPTION_ID` · `TFSTATE_STORAGE_ACCOUNT` · `ACR_NAME` · `ADMIN_IP_RANGES` (JSON, for example `["203.0.113.5/32"]`) ·
`AZURE_CLIENT_ID_CI_PLAN` · `AZURE_CLIENT_ID_INFRA_UAT` · `AZURE_CLIENT_ID_INFRA_UAT_DESTROY` · `AZURE_CLIENT_ID_INFRA_PROD` · `AZURE_CLIENT_ID_INFRA_PROD_DESTROY`
(the client id values come from the bootstrap output `github_identity_client_ids`).

`AZURE_CLIENT_ID_CHART_PUSH` (the identity that pushes the Helm chart) is set in the **shp-platform-templates** repo; `AZURE_CLIENT_ID_ACR_PUSH` is set in the application repo.

**Azure trusts the `main` branch only:**
- Identities bound to a `ref` (`ci-plan`: this repo; `acr-push`: the application repo) only get a token from `refs/heads/main`. Another branch, a PR or a fork has a different subject, so Azure refuses it.
- Identities bound to an Environment (`infra-<env>`, `infra-<env>-destroy`, `release-chart`) rely on the *deployment branch policy*: the Environment only allows the `main` branch (`release-chart` only allows `chart-v*` tags). A job on another branch is rejected by GitHub before it can request a token. Verified on the current plan with a test branch.
- Not used by CI on pull requests: a PR only runs static checks and never signs in to Azure.

For the ENV-01 step (Argo CD reading private repos): a **read-only** GitHub App (`Contents: Read`, `Metadata: Read`) installed on `shp-gitops` and `shp-platform-templates`.
Variables `ARGOCD_REPO_APP_ID`, `ARGOCD_REPO_APP_INSTALLATION_ID`; secret `ARGOCD_REPO_APP_PRIVATE_KEY`.
The identity `AZURE_CLIENT_ID_INFRA_<ENV>` additionally needs permission to run `az aks command invoke` and administer the cluster (for example the *Azure Kubernetes Service RBAC Cluster Admin* role on that environment's cluster).

## Done / still missing
| Done (`fmt` + `validate` + tflint + Trivy clean) | Remaining (backlog) |
|---|---|
| bootstrap, network, monitoring, Key Vault, AKS (3 node pools), 2 stacks, 4 workflows | IAC-09..14 data modules (PostgreSQL, Cosmos DB for MongoDB, Redis, Storage, Service Bus, AI Search), IAC-15 workload identity per service, IAC-16 Entra app, IAC-18/19 Defender + Azure OpenAI |
| | OBS-01: connect Managed Prometheus (needs a data collection rule), Grafana |
| ENV-01: `env-provision` installs Argo CD and hands the cluster to GitOps (not yet tried on real Azure) | Rest of ENV-01: load synthetic data, smoke test after provisioning |

> **Not yet `apply`-ed to Azure** (per the project rule) and the workflows have not run on real GitHub. The tflint `azurerm` plugin could not run where the code was written; CI runs it.
> Cost: AKS is billed per hour while the environment exists; `cost-guard` warns about environments past their TTL. Detailed estimate: task PRD-05.
