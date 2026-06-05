# Ansible Lab — Tri-Model Review (Claude · Codex · Gemini)

> Multi-perspective review of this project: Codex (infra/security/portability),
> Gemini (developer experience/learning design), synthesized by Claude.
> **No code was changed for this review — findings and roadmap only.**
>
> Context: this is a Docker-Compose lab that spins up SSH-reachable "hosts" for
> practicing/testing Ansible code. It is used across **three platforms**:
> Ubuntu 26.04 (amd64), Windows (amd64), and a MacBook Pro M4 Pro (arm64).
> It must work identically on all three.

## TL;DR

The lab is a **clean, working foundation** but it currently teaches a few habits
you'd want to unlearn for real Ansible work, and it has **two concrete
cross-platform footguns** (CRLF line endings + hardcoded subnet) that will bite
when hopping between the Ubuntu box, the Windows machine, and the M4 Pro. The
single biggest opportunity: it's a *sandbox* today — wiring in `simple-webapp/`
as a capstone plus a `roles/playbooks` layout turns it into an *amazing learning
lab*.

All three models independently agree on the top moves. Where Codex (infra) and
Gemini (DX) diverge, Claude adjudicates below.

---

## Where all three models agree (do these)

| Theme | Finding | Files |
|---|---|---|
| **Project structure** | Flat `ansible/` dir with one inventory teaches nothing about real layout. Move to `inventories/`, `playbooks/`, `roles/`, `group_vars/`, `host_vars/`. | `ansible/` |
| **DX / Makefile** | A `Makefile` (`up`, `down`, `ping`, `shell`, `reset`, `lint`, `test`) is the highest-leverage quality-of-life win. | (new) |
| **Capstone** | `simple-webapp/` is dead weight until a playbook deploys Flask to a host backed by `mysqldb1`. This is the lab's missing "aha". | `simple-webapp/app.py` |
| **Linting feedback loop** | Ship `ansible-lint` + `yamllint` + `.pre-commit-config.yaml` so learners get best-practice nudges. | (new) |
| **Healthchecks** | `docker compose up -d` returns before SSH/MySQL are ready. Add SSH + MySQL healthchecks. | `docker-compose.yml:1` |
| **Modernize the demo** | `simple-webapp` uses Python-2-era packages and contradicts your own MySQL-8 note. | `simple-webapp/README.md:18,37` |
| **Vagrant on Apple Silicon = pain** | VirtualBox is rough on M4. If you ever want real VMs, **Multipass** is the arm64-friendly choice. | — |

---

## Cross-platform portability (the hard constraint: Ubuntu amd64 / Windows amd64 / M4 arm64)

1. **🔴 CRLF line endings will break the lab on Windows.** `start-mysql.sh`
   checked out with CRLF → `exec format error` / bad interpreter inside the
   container. **Add a `.gitattributes`** forcing LF on `*.sh`, `Dockerfile*`,
   `*.yml`, `ansible/*`. This is the #1 thing standing between you and "works
   identically on all three."

2. **🔴 Do NOT pin `platform: linux/amd64`.** `ubuntu:22.04` is multi-arch, and
   `mysql-server-8.0` exists in Ubuntu's arm64 repos — so on the M4 it should run
   **natively**. Forcing amd64 would drag everything through QEMU emulation:
   slow, and MySQL under emulation is genuinely flaky. Keep it arch-neutral; only
   add an `amd64` override file if you ever hit an x86-only binary.

3. **🟡 Hardcoded `172.25.0.0/24` subnet** (`docker-compose.yml:69`) can collide
   with corporate VPNs, WSL2, or Docker Desktop's own networks. For a lab that
   travels across three machines, prefer **Docker DNS names** in the inventory
   (`mysqldb1 ansible_host=mysqldb1`) and keep the static-IP version as an
   optional override for the "networking lesson."

4. **🟡 Windows bind-mount hygiene:** document "clone inside the WSL2 filesystem,
   not `/mnt/c/...`" — otherwise the `./ansible` mount (`docker-compose.yml:12`)
   is slow and permission-weird.

5. **🟢 Robustness nit:** `Dockerfile.master:34` and `Dockerfile.mysql:29` build
   files with `echo "...\n..."`. This *only* works because Ubuntu's `/bin/sh` is
   `dash` (whose `echo` interprets `\n`). It's brittle and would silently produce
   single-line garbage under bash. Use `printf` instead. Not urgent, but a latent
   portability trap.

---

## Where the models disagree — adjudication

### 1. Root + password SSH: keep it or kill it?

- **Codex:** replace root/password with an `ansible` user + SSH keys + `become`
  (`inventory:12-14`, all three Dockerfiles).
- **Gemini:** fine to keep it simple.
- **Verdict:** **Keep password auth as the default** — for a *practice* lab, low
  friction is a feature, and it lets you teach `ansible_become` later. But
  (a) **label it loudly** as "intentionally insecure, lab-only" in the README,
  and (b) add an SSH-key path as a **Phase 2 exercise** so learners see the
  real-world pattern. The one thing to fix now regardless: `ssh-keygen -A` at
  *build* time (`Dockerfile:27`, `Dockerfile.master:38`) bakes shared host keys
  into every container — move it to container startup.

### 2. Terraform / AWS — worth it?

- **Codex:** yes, as a cleanly-separated optional "cloud mode" — same
  roles/playbooks run against EC2 via dynamic inventory, with strict cost
  guardrails. **LocalStack** for practicing the *Terraform/AWS API* workflow;
  **real EC2** when the point is "Ansible against real machines."
- **Gemini:** didn't cover (wasn't its lane).
- **Verdict:** **Strongly endorse Codex's split**, with emphasis on cost-safety
  since this repo gets cloned everywhere:
  - Separate `terraform/aws/` from Docker mode; never trigger cloud from `make up`.
  - `inventories/docker/` and `inventories/cloud/aws_ec2.yml` — **same roles run
    against both**. That parity is the whole payoff.
  - Guardrails: restrict SG ingress to your public IP, mandatory
    `Project=ansible-playground` tags, a `ttl_hours`, AWS budget alarm, and
    `terraform destroy` documented in bold.
  - Cross-platform bonus: Terraform + AWS CLI are identical on all three OSes, so
    cloud mode is actually *more* portable than the Docker mode.

---

## The capstone (the single highest-value addition)

Wire `simple-webapp/` into a real end-to-end deploy — this is what makes it
"amazing" rather than "a sandbox":

- `playbooks/db.yml` → targets `[db]`: `mysql_db` creates `employee_db`,
  `mysql_user` creates `db_user` (the `community.mysql` collection;
  `python3-mysqldb` is already in `Dockerfile.mysql`).
- `playbooks/web.yml` → targets `[hosts]`: deploy `app.py`, install deps, run it
  as a service.
- `playbooks/site.yml` → orchestrates DB-before-app ordering.

**Modernization caveat:** don't just "use python3" — `app.py:3` imports the
unmaintained `flaskext.mysql`, and it opens the DB connection at *import time*
(`app.py:18`), so the app crashes if MySQL isn't up yet. For a 2026 capstone,
swap to `PyMySQL`/`Flask-SQLAlchemy` and lazy-connect. The startup-ordering
problem is itself a great teaching moment (retries, handlers, `wait_for`).

---

## Suggested target layout (Codex)

```text
ansible/
  ansible.cfg
  inventories/
    docker/
      hosts.yml
      group_vars/
      host_vars/
    cloud/
      aws_ec2.yml
  playbooks/
    site.yml
    web.yml
    db.yml
  roles/
    common/
    mysql/
    simple_webapp/
  collections/
    requirements.yml
  requirements.yml
molecule/
  default/
compose.yml
compose.override.yml
compose.static-ip.yml
Makefile
.pre-commit-config.yaml
.github/workflows/ci.yml
```

---

## Learning curriculum (Gemini)

A progressive `exercises/` ladder turns the sandbox into a course:

1. **Ad-hoc phase** — `df -h` / `uptime` across all nodes. *Concept: ad-hoc
   commands, inventory patterns.*
2. **First playbook** — create a `deployer` user on `hosts` + `db`. *Concept:
   `user` module, `state: present`.*
3. **Configuration drift** — ensure `vim`/`htop` installed everywhere; MySQL
   running on `db`. *Concept: `apt`/`service` modules, idempotency.*
4. **Variables & templates** — Jinja2 `/etc/motd` "Welcome to
   {{ inventory_hostname }}". *Concept: variables, `template` module, facts.*
5. **Secrets** — encrypt MySQL root password with `ansible-vault`. *Concept:
   vault, `--ask-vault-pass`.*
6. **Roles & modularity** — refactor into `common`/`web`/`database` roles.
   *Concept: `ansible-galaxy init`, `site.yml` orchestration.*

Plus DX niceties: a `bin/check_lab` health script, a VS Code `.devcontainer/`
targeting the master node, and an ASCII topology diagram in the README:

```text
[ Control Node (172.25.0.10) ]
           | (SSH)
  ---------------------------------
  |          |          |         |
[db1]      [db2]      [host1]   [host2]
(.11)      (.12)      (.13)     (.14)
```

---

## Alternatives & tradeoffs (cross-platform learner)

- **Docker Compose (current):** most accessible, fastest onboarding. Limitation
  (no real `systemd`) is itself a teaching moment for `service` vs `command`.
  **Recommended default.**
- **Multipass (Canonical):** fast, native on Mac/Win/Linux, real VMs — best
  arm64-friendly VM option. Harder to package as one shareable file.
- **Vagrant + VirtualBox:** full systemd realism, but heavy and painful on M4.
- **GitHub Codespaces:** zero local setup, but needs internet and Docker-in-Docker
  networking is fiddly for multi-node.

---

## Prioritized roadmap (action checklist)

### Phase 1 — Quick wins (hours, high impact)
- [ ] `.gitattributes` enforcing LF *(unblocks Windows)*
- [ ] `Makefile` with `up/down/ping/shell/reset/lint`
- [ ] SSH + MySQL healthchecks in `docker-compose.yml`
- [ ] ASCII topology diagram + per-OS setup notes (WSL2, M4 native arm64) +
      "intentionally insecure" banner in `README.md`
- [ ] Pin the Ansible version (`Dockerfile.master:19` — unbounded
      `pip3 install ansible`)
- [ ] Move `ssh-keygen -A` to startup; switch `echo`→`printf` in Dockerfiles

### Phase 2 — Make it a real lab
- [ ] Restructure to `inventories/ playbooks/ roles/ group_vars/`
- [ ] Convert inventory to YAML + Docker DNS names (drop hardcoded IPs by default)
- [ ] `ansible-lint` + `yamllint` + `pre-commit`
- [ ] Optional `ansible` user + SSH-key exercise

### Phase 3 — Teaching curriculum
- [ ] Progressive `exercises/` ladder (ad-hoc → users → packages/services →
      Jinja2 `motd` → vault → roles)
- [ ] **The capstone deploy** (wire up `simple-webapp/`)

### Phase 4 — Portability hardening
- [ ] GitHub Actions CI matrix (`linux/amd64` + `linux/arm64`) to *prove* the lab
      builds on both architectures
- [ ] Add multi-distro targets (Rocky/Alma/Debian) to practice `ansible_os_family`
      branching

### Phase 5 — Cloud mode (optional, bigger bet)
- [ ] `terraform/aws/` + `aws_ec2.yml` dynamic inventory, same roles, hard cost
      guardrails
- [ ] LocalStack only for TF-workflow practice, not as the SSH-host replacement

---

## What to do first

If you want one PR: **Phase 1 in a single commit** (`.gitattributes` + `Makefile`
+ healthchecks + README diagram/notes). A couple hours, directly fixes the
cross-platform pain, and makes the lab feel polished immediately. The capstone
(Phase 3) is the most *fun* and most *impressive*, but Phase 1 is the foundation.

---

## Detailed findings reference (Codex)

**Highest-risk correctness issues**

1. **SSH model is intentionally weak, but too baked in.** `Dockerfile:20`,
   `Dockerfile.master:23`, `Dockerfile.mysql:20` set `root:ansible`, enable root
   login + password auth, disable PAM. Acceptable only if clearly framed as
   intentionally insecure; prefer an `ansible` user with passwordless sudo + key
   auth.
2. **Inventory hardcodes password auth.** `inventory:12` sets `ansible_user=root`
   / `ansible_password=ansible`, forcing `sshpass` and normalizing root SSH.
3. **Host key checking disabled in three places** — `Dockerfile.master:32`,
   `ansible.cfg:3`, `inventory:15`. One controlled place is enough.
4. **SSH host keys generated at build time** (`Dockerfile:27`,
   `Dockerfile.master:38`) → every container shares host keys. Generate at
   startup.
5. **MySQL startup is fragile.** `start-mysql.sh:5` uses `service mysql start`
   then foregrounds `sshd`; if MySQL dies the container still looks "healthy."
   Use a small supervisor or split MySQL into an official `mysql:8` container.
6. **MySQL config is partial/crude** (`Dockerfile.mysql:29` appends a second
   `[mysqld]` block). Prefer a dedicated `/etc/mysql/mysql.conf.d/lab.cnf`.
7. **No healthchecks** (`docker-compose.yml:1`).
8. **The simple app is outdated/brittle** (`simple-webapp/app.py:18` connects at
   import; `simple-webapp/README.md:18,37` Python-2 packages + old GRANT syntax).

**Terraform/AWS** — add as optional cloud mode, cleanly separated from Docker
mode; provision EC2 with the same logical groups (`master`/`db`/`hosts`/`web`)
so the same roles run against both inventories. Cost safety mandatory (TTL tags,
IP-restricted ingress, explicit `make cloud-up`, prominent `terraform destroy`,
budget alarms). LocalStack for TF/API practice only. Vagrant for VM realism
(systemd/firewalld/SELinux/reboots) — but check provider compat on Apple Silicon.

---

*Raw advisor artifacts are saved under `.omc/artifacts/ask/` (codex-*.md,
gemini-*.md) if you want the unabridged versions.*
