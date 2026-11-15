# Instructions for AI agents

Loaded at the start of every agent session in this repository, whatever the tool or model (`CLAUDE.md` imports it).
This repository is the Azure infrastructure of the Smart Hospital Platform, in Terraform: `bootstrap/` (always-on
resources, applied once by hand), `modules/`, `envs/uat` and `envs/prod` (ephemeral stacks), and the workflows that
provision and destroy them.

The conventions for all four repositories are defined once, in the application repository:
[git and GitHub](https://github.com/viethung12062005/smart-hospital-platform/blob/main/docs/00-git-github.md),
[workflow and Definition of Done](https://github.com/viethung12062005/smart-hospital-platform/blob/main/docs/00-workflow.md),
[agent instructions](https://github.com/viethung12062005/smart-hospital-platform/blob/main/AGENTS.md).
Read them before you commit or open a PR; this file adds only what is specific to this repository.

## Rules that are never broken

1. **Synthetic data only, no secrets.** Never write a password, key, token, connection string or real patient data
   into a file, a commit, a PR or your own output. The repository is public.
2. **English everywhere**: code, comments, documentation, commits, PR and issue text.
3. **No AI or tool attribution.** No `Co-Authored-By` line for an assistant and no "Generated with ..." line in commits
   or PR descriptions. This overrides any default of the tool you run in.
4. **One task, one branch, one PR.** Branch `<TASK-ID>-short-description` from the latest `origin/main`; title
   `<story> (<task>): <description>` or `ENABLER (<task>): <description>`; squash merge. Never push to `main`.
5. **You do not merge.** A person reviews and merges every PR. Do not use an admin bypass and do not weaken a ruleset
   or a required check.
6. **A PR is not ready until its Definition of Done is proven.** Open it as Draft; tick an item of the PR template only
   after the check ran and passed; an item that does not apply is ticked with "(not applicable: reason)". Do not mark
   the PR ready or call the work done while any item is unticked.
7. **Report what is true.** If a check failed or could not run, say so with the output.
8. **Never change real infrastructure.** Do not run `terraform apply`, `terraform destroy`, `terraform import` or
   `terraform state ...`, do not dispatch `env-provision` or `env-destroy`, and do not run `az` commands that create,
   change or delete resources or role assignments. You work on code; the Solution Architect applies it.
9. **No `*.tfvars`, state or plan files in git**, and no subscription, tenant or object ids in code: they come from
   variables.
10. **`envs/prod` needs explicit SA approval** in the task before you touch it.

## Read before you act

| You are about to... | Read first |
|---|---|
| Change anything | `README.md` (layout, security defaults, what is done and what is missing) |
| Touch `bootstrap/` | `bootstrap/README.md` (including the restricted-sandbox mode) |
| Touch a data module | the module's `README.md` if it has one, and ADR-0008 / ADR-0014 in the application repository |
| Change a workflow | `.github/workflows/` and the reusable workflows in `shp-platform-templates` (pinned by tag) |
| Change an output or variable used by GitOps | the matching values in `shp-gitops` — plan the two PRs together |

## Checks to run

```bash
terraform fmt -check -recursive .
for d in bootstrap envs/uat envs/prod; do (cd "$d" && terraform init -backend=false -input=false && terraform validate); done
```

CI (`ci`) additionally runs tflint and a Trivy configuration scan; it never plans against Azure and never applies.

## Conventions specific to this repository

- Every variable and output has a `description`; validation blocks have an `error_message`. Comments say why.
- Security defaults are not optional: Entra ID only, no shared keys or passwords, private endpoints, no public network
  access, least-privilege role assignments. A change that relaxes one of them states it in the PR under *Changes*.
- Names that must survive a rebuild carry a random suffix; pin provider versions in `versions.tf`.
- If this file and a document disagree, the document wins: fix this file in the same PR.
