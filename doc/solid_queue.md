# SolidQueue background jobs

The app runs ActiveJob on **SolidQueue** (durable, database-backed), with the
**Mission Control – Jobs** web dashboard for inspection. This is what backs the
Substack Blizzard backfill buttons; it also carries transactional mail.

## What runs on it

- `BackfillAllJob` / `BackfillPostJob` — Substack Blizzard backfill (see
  [substack_blizzard.md](substack_blizzard.md)). Runs on **prod** (Substack
  *reads* are allowed from the datacenter IP).
- `deliver_later` — the landing-page thank-you mail (`LandingMailer`). **Because
  of this, the prod worker must stay running or those emails just queue.**
- A recurring maintenance task, `clear_solid_queue_finished_jobs`, hourly
  (`config/recurring.yml`) — prunes finished job rows.

## Layout

- **Adapter:** `config.active_job.queue_adapter = :solid_queue` in both
  `production.rb` and `development.rb`.
- **Single database:** SolidQueue's tables live in the **primary** DB (we dropped
  the installer's separate `queue` database and its `connects_to`). The tables
  were added by a normal migration (`…_create_solid_queue_tables.rb`), so they're
  in `schema.rb` and migrate like anything else.
- **Config:** `config/queue.yml` (dispatcher + workers, `JOB_CONCURRENCY`) and
  `config/recurring.yml`.
- **Worker binary:** `bin/jobs` (runs the supervisor → dispatcher + worker +
  scheduler).

## The worker process

Passenger can't host the worker, so `bin/jobs` runs as a **user systemd service**
on the prod box.

- **Local dev:** `bin/jobs` is in `Procfile.dev`, so `bin/dev` runs it alongside
  the web/JS/CSS processes. If you run a bare `bin/rails server` instead, jobs
  (and `deliver_later`) will queue but never run.

- **Prod:** `~/.config/systemd/user/blizzard-jobs.service` (user unit, no root):

  ```ini
  [Unit]
  Description=SolidQueue worker (blizzard reposting + mailers)
  After=network.target
  [Service]
  Type=simple
  WorkingDirectory=/home/noob/blog/current
  Environment=RAILS_ENV=production
  ExecStart=/home/noob/.rbenv/bin/rbenv exec bundle exec bin/jobs
  Restart=always
  RestartSec=5
  [Install]
  WantedBy=default.target
  ```

  Lingering keeps it running across logout/reboot (one-time, needs sudo):

  ```bash
  sudo loginctl enable-linger noob
  systemctl --user enable --now blizzard-jobs.service
  ```

- **Deploys** restart it via a Capistrano hook (`solid_queue:restart`, after
  `deploy:published`) so it picks up new code. The hook is `|| true`-tolerant.

## Operating it

All `systemctl --user` commands run as `noob` over SSH (set
`XDG_RUNTIME_DIR=/run/user/$(id -u)` if it complains about the bus):

```bash
systemctl --user status  blizzard-jobs.service   # is it up?
systemctl --user restart blizzard-jobs.service
journalctl --user -u blizzard-jobs.service -f     # live worker log
```

Quick queue health from a console (`RAILS_ENV=production bin/rails runner`):

```ruby
SolidQueue::Process.count                       # live worker/dispatcher/scheduler
SolidQueue::Job.where(finished_at: nil).count   # pending
SolidQueue::FailedExecution.count               # failed
```

## Mission Control dashboard

`https://mikeyclarke.co.nz/admin/jobs` — queues, in-progress / scheduled /
blocked / **failed** jobs (with error + backtrace), **retry / discard**,
pause/resume queues, and worker status.

- **Auth:** the same Comfy admin username/password as the rest of `/admin`. It's
  gated by `MissionControlBaseController` (HTTP basic auth with the Comfy
  credentials); Mission Control's own auth is disabled
  (`config/initializers/mission_control_jobs.rb`). It's mounted **before** Comfy's
  `/admin` catch-all so it isn't intercepted.

## Gotchas

- **Emails not sending / backfill not running →** the worker is down. Check
  `systemctl --user status blizzard-jobs`; start it, and any queued jobs flush.
- **After a schema change / deploy,** the worker restarts automatically; if it's
  ever wedged, `systemctl --user restart blizzard-jobs`.
- Jobs are **durable**: a queued job survives restarts and runs when the worker
  is back — nothing is lost, only delayed.
