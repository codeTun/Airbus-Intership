# Laboratoire virtualise, partie 1
# Raccourcis pour les commandes courantes. `make` seul affiche l'aide.

SHELL := /bin/bash
PLAN  := plan.tfplan

.DEFAULT_GOAL := aide

.PHONY: aide init fmt valider verifier plan appliquer detruire etat sortie propre

aide: ## Affiche cette aide
	@echo "Laboratoire virtualise, partie 1"
	@echo
	@grep -E '^[a-z-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  make %-12s %s\n", $$1, $$2}'
	@echo

init: ## Telecharge le fournisseur et initialise le repertoire
	terraform init -upgrade

fmt: ## Remet le code au format standard
	terraform fmt -recursive

valider: ## Verifie la syntaxe et la coherence des modules
	terraform validate

verifier: fmt valider ## Format et validation, sans acces a l'hote KVM
	@echo "Code conforme."

plan: ## Montre ce qui sera cree, sans rien changer
	terraform plan -out=$(PLAN)

appliquer: ## Cree l'infrastructure a partir du dernier plan
	@test -f $(PLAN) || { echo "Lancer d'abord : make plan"; exit 1; }
	terraform apply $(PLAN)
	@rm -f $(PLAN)

detruire: ## Supprime toute l'infrastructure du laboratoire
	terraform destroy

sortie: ## Reaffiche les sorties du dernier apply
	terraform output

etat: ## Etat des machines et des reseaux vus par libvirt
	@echo "--- machines ---"    && virsh list --all    2>/dev/null || echo "virsh absent sur cette machine"
	@echo "--- reseaux  ---"    && virsh net-list --all 2>/dev/null || true

propre: ## Efface les fichiers de travail locaux
	rm -rf .terraform $(PLAN) crash.log
