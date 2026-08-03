---
name: deploy
description: Autonomous production deploy-and-verify for the blog — land on mistress, verify the push, cap deploy, health-check the live site, and roll back on failure. Use when the user asks to deploy, ship, or release to production.
---

# Autonomous deploy-and-verify

Production runs the **`mistress`** branch (Capistrano `set :branch, :mistress`) on the DigitalOcean box (`168.144.167.177`), Phusion Passenger. Capistrano ships the **pushed** commit, not local HEAD. Public site: `https://mikeyclarke.co.nz` (blog at `/blog`).

Run this as a strict pipeline. **Create one task per phase up front** (TaskCreate) and only mark a phase `completed` when its checks pass — this is what stops a step being silently skipped. If any phase fails, follow the failure protocol for that phase and **report exactly which phase and command broke**. Do not declare success unless every phase is green.

Before deploying, ask the caller (or infer from the diff) whether the change is **public-facing** and, if so, a URL path + a substring that proves it's serving — that becomes the phase-3 assertion. Backend/admin-only changes (admin routes are auth-gated, so they can't be curled anonymously) verify with liveness + the shipped SHA only.

## Phase 1 — Pre-flight (nothing shipped yet)

1. Tests green: `bundle exec rspec --exclude-pattern "spec/system/**/*"` (run full `bundle exec rspec` if views/JS changed). 0 failures required.
2. Land the work on `mistress`: `git checkout mistress && git merge --ff-only <feature-branch>` (rebase first if it won't fast-forward). Confirm intended commits: `git log --oneline origin/mistress..mistress`.
3. Push and **verify the push landed**:
   ```bash
   git push origin mistress
   test "$(git rev-parse mistress)" = "$(git rev-parse origin/mistress)" && echo PUSH_OK
   ```
   The two SHAs must match. This is the check that catches "deployed but never pushed."

**Failure protocol:** abort. Nothing has shipped, so no rollback — just report which step failed.

## Phase 2 — Deploy

```bash
bundle exec cap production deploy
```
Use `bundle exec cap` (the bare `cap` is a zsh wrapper unavailable in non-interactive shells). Deploying autonomously is fine — SSH server commands are not (hand those off).

From the output, capture the `deploy:log_revision` line — it prints the deployed SHA + release id. Reaching that line means `assets:precompile` and `migrate` passed (they abort the deploy otherwise). Confirm the printed SHA equals `git rev-parse mistress`.

**Failure protocol:** run `bundle exec cap production deploy:rollback`, then report the failing cap task.

## Phase 3 — Verify the live site is serving

```bash
bin/prod_healthcheck.sh                                   # liveness: /blog returns 200
bin/prod_healthcheck.sh "https://mikeyclarke.co.nz/<path>" "<expected substring>"   # public-facing change
```
The script exits non-zero on a non-200 or a missing substring.

**Failure protocol:** the new release is live but not serving correctly — run `bundle exec cap production deploy:rollback`, re-run `bin/prod_healthcheck.sh` to confirm the previous release is healthy again, then report that phase 3 failed and the site was rolled back.

## Phase 4 — Complete

Only when phases 1–3 are all green:

1. Delete the now-merged feature branch (it's redundant once its commits are on `mistress` and shipped):
   ```bash
   git branch -d <feature-branch>
   git push origin --delete <feature-branch>   # if it was ever pushed
   ```
   `git branch -d` refuses unless the branch is fully merged, so it's safe. A `remote ref does not exist` error from the push is fine — usually only `mistress` was pushed, not the feature branch.
2. Mark the deploy task `completed` and report the shipped SHA, release id, and health-check result.

If a rollback happened, the deploy is **not** complete — report the rollback instead, and do **not** delete the branch.
