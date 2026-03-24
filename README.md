# Ansible Advanced Lab

Docker-based Ansible lab with 5 nodes: 1 control node (master) and 4 managed hosts.

## Lab Nodes

| Container        | Hostname | IP           | Role          |
|------------------|----------|--------------|---------------|
| `ansible-master` | master   | 172.25.0.10  | Control node  |
| `ansible-host1`  | host1    | 172.25.0.11  | Managed host  |
| `ansible-host2`  | host2    | 172.25.0.12  | Managed host  |
| `ansible-host3`  | host3    | 172.25.0.13  | Managed host  |
| `ansible-host4`  | host4    | 172.25.0.14  | Managed host  |

**SSH credentials (all nodes):** `root` / `ansible`

## Getting Started

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
├── Dockerfile           # Base image for managed hosts (SSH + Python)
├── Dockerfile.master    # Control node image (SSH + Python + Ansible)
├── docker-compose.yml   # Defines all 5 containers and the lab network
├── README.md
└── ansible/
    ├── ansible.cfg      # Ansible configuration
    └── inventory        # Host inventory with groups [master] and [hosts]
```

## Inventory Groups

- `[master]` - the Ansible control node
- `[hosts]` - all 4 managed hosts
- `all` - every node in the lab

## Tips

- The `./ansible/` directory is mounted into the master at `/root/ansible/`, so any playbooks or roles you create locally are immediately available inside the container.
- Host key checking is disabled for convenience (`ansible.cfg` and SSH config on master).
- To add more hosts, duplicate a host block in `docker-compose.yml` with a new IP and update the inventory file.
# ansible-playground
