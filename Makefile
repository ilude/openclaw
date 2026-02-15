.PHONY: deploy update backup shell build test-infra

DEPLOY_HOST := $(shell grep '^DEPLOY_HOST=' .env | cut -d= -f2)
ANSIBLE_CMD = docker compose -f infra/ansible/docker-compose.yml run --rm ansible

# Full deploy: create directories, copy files, pull images, start services
deploy:
	$(ANSIBLE_CMD) ansible-playbook playbooks/deploy.yml -e "deploy_host=$(DEPLOY_HOST)"

# Quick update: pull latest images and restart
update:
	$(ANSIBLE_CMD) ansible-playbook playbooks/update.yml -e "deploy_host=$(DEPLOY_HOST)"

# Backup current server config
backup:
	$(ANSIBLE_CMD) ansible-playbook playbooks/backup.yml -e "deploy_host=$(DEPLOY_HOST)"

# Interactive shell in Ansible container
shell:
	docker compose -f infra/ansible/docker-compose.yml run --rm --entrypoint /bin/bash ansible

# Build Ansible container
build:
	docker compose -f infra/ansible/docker-compose.yml build

# Validate playbook syntax
test-infra:
	@echo "Checking Ansible syntax..."
	$(ANSIBLE_CMD) ansible-playbook --syntax-check playbooks/deploy.yml -e "deploy_host=test"
	$(ANSIBLE_CMD) ansible-playbook --syntax-check playbooks/update.yml -e "deploy_host=test"
	$(ANSIBLE_CMD) ansible-playbook --syntax-check playbooks/backup.yml -e "deploy_host=test"
	@echo "All playbooks OK"
