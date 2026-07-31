---
name: deploy
description: Safe production deploy sequence for the blog — run tests, land changes on mistress, push, verify the push, then cap deploy and confirm. Use when the user asks to deploy, ship, or release to production.
---

# Deploy the blog to production

Production deploys the **`mistress`** branch via Capistrano (`set :branch, :mistress`) to the DigitalOcean box, Phusion Passenger. Capistrano ships the **pushed** commit, not local HEAD — so pushing before deploying is mandatory.

Work through these in order. Stop and report if any step fails; do not proceed to deploy on a red step.

## 1. Green test suite

```bash
bundle exec rspec --exclude-pattern "spec/system/**/*"
```
Must be 0 failures. (System tests need a browser; run the full `bundle exec rspec` if the change touches views/JS.)

## 2. Land the work on `mistress`

- If on a feature branch: `git checkout mistress && git merge --ff-only <feature-branch>` (rebase the feature onto mistress first if it won't fast-forward).
- Confirm the tree is clean and only the intended commits are included: `git log --oneline origin/mistress..mistress`.

## 3. Push, then verify the push landed

```bash
git push origin mistress
git log origin/mistress -1 --oneline
```
The `origin/mistress` tip **must** equal local `mistress` before deploying. This is the step that catches the classic "deployed but the commit was never pushed" miss — never skip it.

## 4. Deploy

```bash
bundle exec cap production deploy
```
Use `bundle exec cap`, not bare `cap` (the bare command is a zsh wrapper unavailable in non-interactive shells). Deploying autonomously is fine.

## 5. Confirm it shipped

- Read the deploy output's `deploy:log_revision` line — it prints the deployed branch + commit SHA + release id. Confirm the SHA matches what you pushed.
- Note whether `deploy:assets:precompile` and `deploy:migrate` ran (they abort the deploy on failure, so reaching `log_revision` means they passed).

Only after the pushed-SHA check and a clean deploy output should you report the deploy as successful.

## Boundaries

- **Do NOT** run direct SSH commands on the production server (installing packages, arbitrary ops, remote consoles) — those are the user's to run. If a check genuinely needs the server, prepare the exact command and hand it off.
- Verify deploys with local git + the deploy output, not an SSH probe.
