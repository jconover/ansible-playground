# Ansible Lab — convenience targets.
# Run `make` or `make help` to list everything.

COMPOSE      := docker compose
MASTER       := ansible-master
ANSIBLE_DIR  := /root/ansible

.DEFAULT_GOAL := help

.PHONY: help build up down restart reset ps logs ping shell inventory lint health

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

build: ## Build (or rebuild) all images
	$(COMPOSE) build

up: ## Start the lab in the background (builds if needed)
	$(COMPOSE) up -d --build

down: ## Stop and remove the containers
	$(COMPOSE) down

restart: down up ## Restart the whole lab

reset: ## Tear everything down (volumes + local images) and rebuild from scratch
	$(COMPOSE) down -v --rmi local
	$(COMPOSE) up -d --build

ps: ## Show container status (incl. health)
	$(COMPOSE) ps

logs: ## Tail logs from all containers (Ctrl-C to exit)
	$(COMPOSE) logs -f

ping: ## Ansible ping every node from the control node
	docker exec $(MASTER) ansible all -i $(ANSIBLE_DIR)/inventory -m ping

shell: ## Open an interactive shell on the control node
	docker exec -it $(MASTER) bash

inventory: ## Print the parsed inventory graph (sanity check)
	docker exec $(MASTER) ansible-inventory -i $(ANSIBLE_DIR)/inventory --graph

lint: ## Lint YAML/Ansible content if linters are available on the control node
	@docker exec $(MASTER) sh -c 'command -v ansible-lint >/dev/null 2>&1 \
		&& ansible-lint $(ANSIBLE_DIR) \
		|| echo "ansible-lint not installed on the control node (added in Phase 2)."'
	@docker exec $(MASTER) ansible-inventory -i $(ANSIBLE_DIR)/inventory --graph >/dev/null \
		&& echo "inventory: OK"

health: ## Show the health status reported by each container
	@$(COMPOSE) ps --format 'table {{.Name}}\t{{.Status}}'
