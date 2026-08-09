# Configuration du laboratoire. `make` seul affiche l'aide.

SHELL := /bin/bash
.DEFAULT_GOAL := aide

.PHONY: aide collections verifier syntaxe lint simuler configurer commun services supervision parefeux recette

aide: ## Affiche cette aide
	@echo "Configuration du laboratoire, partie 1"
	@echo
	@grep -E '^[a-z-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  make %-12s %s\n", $$1, $$2}'
	@echo

collections: ## Installe les collections Ansible necessaires
	ansible-galaxy collection install -r requirements.yml -p collections

syntaxe: ## Verifie la syntaxe des playbooks
	ansible-playbook site.yml --syntax-check

lint: ## Analyse la qualite du code Ansible
	yamllint .
	ansible-lint

verifier: syntaxe lint ## Syntaxe et qualite, sans toucher aux machines
	@echo "Code Ansible conforme."

simuler: ## Montre ce qui changerait, sans rien modifier
	ansible-playbook site.yml --check --diff

configurer: ## Configure toutes les machines
	ansible-playbook site.yml

commun: ## Applique le seul durcissement commun
	ansible-playbook site.yml --tags commun

services: ## Configure les seuls services metiers
	ansible-playbook site.yml --limit 'impression:visioconference:pointeuses'

supervision: ## Configure la seule supervision
	ansible-playbook site.yml --limit supervision

parefeux: ## Configure les seuls pare-feux
	ansible-playbook site.yml --limit parefeux

recette: ## Controle l'etat du laboratoire, sans rien modifier
	ansible-playbook playbooks/verification.yml
