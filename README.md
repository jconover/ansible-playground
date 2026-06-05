# Ansible Advanced Lab

Docker-based Ansible lab with 5 nodes: 1 control node (master) and 4 managed hosts (2 MySQL DB hosts + 2 generic hosts).

> ⚠️ **Intentionally insecure — lab use only.** Every node uses `root` login over
> SSH with the hardcoded password `ansible`, password auth enabled, and host-key
> checking disabled. This is deliberate so the lab is frictionless to practice
> against. **Never** expose these containers to an untrusted network or reuse
> this configuration on real hosts.

## Topology

```text
              ┌─────────────────────────────┐
              │  ansible-master (control)   │
              │       172.25.0.10           │
              └──────────────┬──────────────┘
                             │ SSH (root/ansible)
        ┌──────────┬─────────┴─────────┬──────────┐
        ▼          ▼                   ▼          ▼
   ┌─────────┐ ┌─────────┐        ┌─────────┐ ┌─────────┐
   │ mysqldb1│ │ mysqldb2│        │  host1  │ │  host2  │
   │  .11    │ │  .12    │        │  .13    │ │  .14    │
   │ MySQL 8 │ │ MySQL 8 │        │ generic │ │ generic │
   └─────────┘ └─────────┘        └─────────┘ └─────────┘
     [db] group                     [hosts] group
              network: ansible-lab  (172.25.0.0/24)
```

## Lab Nodes

| Container           | Hostname | IP           | Image              | Role          |
|---------------------|----------|--------------|--------------------|---------------|
| `ansible-master`    | master   | 172.25.0.10  | `Dockerfile.master`| Control node  |
| `ansible-mysqldb1`  | mysqldb1 | 172.25.0.11  | `Dockerfile.mysql` | MySQL DB host |
| `ansible-mysqldb2`  | mysqldb2 | 172.25.0.12  | `Dockerfile.mysql` | MySQL DB host |
| `ansible-host1`     | host1    | 172.25.0.13  | `Dockerfile`       | Managed host  |
| `ansible-host2`     | host2    | 172.25.0.14  | `Dockerfile`       | Managed host  |

> A third generic host (`ansible-host3`, 172.25.0.15) is defined but commented out in `docker-compose.yml`. Uncomment it and add `172.25.0.15` to the `[hosts]` group in the inventory to enable it.

**SSH credentials (all nodes):** `root` / `ansible`

## Requirements & Platform Notes

You need **Docker** with the **Compose v2** plugin (`docker compose`, not the old
`docker-compose`). The lab is tested across three platforms:

| Platform | Notes |
|----------|-------|
| **Linux (amd64)** — e.g. Ubuntu | Docker Engine + Compose plugin. Works out of the box. |
| **macOS (Apple Silicon, M-series)** | Docker Desktop. Images run **natively as arm64** — do *not* force `platform: linux/amd64` (that triggers slow QEMU emulation and flaky MySQL). |
| **Windows (amd64)** | Use **Docker Desktop with the WSL2 backend**, and **clone this repo inside the WSL2 filesystem** (e.g. `~/code/...`), *not* under `/mnt/c/...`. The `.gitattributes` file forces LF line endings so the container entrypoints don't break on a Windows checkout. |

> The images are architecture-neutral (`ubuntu:22.04` base), so the same
> `docker compose` commands produce a working lab on amd64 and arm64 alike.

**Prefer real VMs over containers?** [Multipass](https://multipass.run/) is a
good cross-platform alternative when you need full `systemd`/firewalld/reboot
realism (it runs natively on macOS Apple Silicon and Linux). This repo stays on
Docker Compose because it has the fastest onboarding, but a Multipass-based
inventory is a natural future addition.

## Getting Started

The quickest path is the `Makefile` (run `make` to see all targets):

```bash
make up        # build + start the whole lab in the background
make ping      # ansible ping every node from the control node
make shell     # open a shell on the control node
make ps        # show container status + health
make down      # stop and remove the containers
make reset     # nuke volumes/images and rebuild from scratch
```

Or use Docker Compose directly:

### Build and start the lab

```bash
docker compose up -d --build
```

### Check container status

```bash
docker compose ps
```

### Shell into the master node

```bash
docker exec -it ansible-master bash
```

### Stop the lab

```bash
docker compose down
```

### Stop and remove everything (including images)

```bash
docker compose down --rmi all
```

## Using Ansible

All commands below are run from inside the master node, or by prefixing with `docker exec ansible-master`.

### Ping all hosts

```bash
# From inside the master
cd /root/ansible
ansible hosts -m ping

# From your local machine
docker exec ansible-master ansible -i /root/ansible/inventory hosts -m ping
```

### Ping all nodes (including master)

```bash
ansible all -m ping
```

### Run an ad-hoc command on all hosts

```bash
ansible hosts -a "uptime"
ansible hosts -a "cat /etc/os-release"
ansible hosts -m shell -a "df -h"
```

### Run a playbook

```bash
# Create a playbook in the ./ansible/ directory on your host machine
# It will be available at /root/ansible/ inside the master container

ansible-playbook /root/ansible/your-playbook.yml
```

## Project Structure

```
.
├── Dockerfile           # Base image for generic managed hosts (SSH + Python)
├── Dockerfile.master    # Control node image (SSH + Python + pinned Ansible)
├── Dockerfile.mysql     # MySQL host image (SSH + Python + mysql-server)
├── start-ssh.sh         # Entrypoint for master/host nodes: regen host keys, run sshd
├── start-mysql.sh       # mysqldb entrypoint: regen host keys, start mysqld, run sshd
├── docker-compose.yml   # Defines all 5 containers, healthchecks, and the lab network
├── Makefile             # Convenience targets (up/down/ping/shell/reset/lint/...)
├── .gitattributes       # Forces LF line endings (cross-platform safety)
├── README.md
├── REVIEW.md            # Tri-model review + improvement roadmap
├── simple-webapp/       # Demo Flask + MySQL app for Ansible playbook practice
│   ├── app.py
│   └── README.md
└── ansible/
    ├── ansible.cfg      # Ansible configuration
    └── inventory        # Host inventory with groups [master], [db], and [hosts]
```

## Inventory Groups

- `[master]` - the Ansible control node (master, 172.25.0.10)
- `[db]` - the MySQL database hosts (mysqldb1 + mysqldb2, 172.25.0.11–172.25.0.12)
- `[hosts]` - the generic managed hosts (host1 + host2, 172.25.0.13–172.25.0.14)
- `all` - every node in the lab

## MySQL

The `mysqldb1` and `mysqldb2` containers each run MySQL 8.0 (from `Dockerfile.mysql`). The `root` user authenticates via the OS socket (no password needed from within the container).

To create a database user with a password (MySQL 8.0+ syntax):

```sql
CREATE USER 'db_user'@'%' IDENTIFIED BY 'Passw0rd';
GRANT ALL ON *.* TO 'db_user'@'%';
FLUSH PRIVILEGES;
```

> **Note:** The old `GRANT ... IDENTIFIED BY` shorthand was removed in MySQL 8.0. Always create the user first, then grant privileges.

## Tips

- The `./ansible/` directory is mounted into the master at `/root/ansible/`, so any playbooks or roles you create locally are immediately available inside the container.
- Host key checking is disabled for convenience (`ansible.cfg` and SSH config on master).
- To add more hosts, duplicate a host block in `docker-compose.yml` with a new IP and update the inventory file.
