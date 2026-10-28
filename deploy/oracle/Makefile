# Atalhos. Terraform e executado por voce; nada aqui roda apply sozinho.
TF ?= terraform
CFG ?= ./config.yaml
IP = $(shell cd infra && $(TF) output -raw public_ip)

init plan apply destroy:
	cd infra && $(TF) $@

fmt validate:
	cd infra && $(TF) $@

push-config:
	./push-config.sh ubuntu@$(IP) $(CFG)

ssh:
	ssh ubuntu@$(IP)

logs:
	ssh ubuntu@$(IP) 'sudo journalctl -u zombizoid -f'

bootstrap-log:
	ssh ubuntu@$(IP) 'sudo tail -f /var/log/zombizoid-bootstrap.log'

.PHONY: init plan apply destroy fmt validate push-config ssh logs bootstrap-log
