#!/usr/bin/env bash
# Pousse le code du poste de developpement vers la machine du laboratoire.
# Le poste fait foi pour le code, la machine possede ce qui lui est propre :
# terraform.tfvars, le coffre, l'etat Terraform, les images et l'inventaire
# genere. Tout cela est exclu, sous peine d'ecraser des donnees vivantes.

set -euo pipefail

CIBLE="${1:-srvairbus}"
SOURCE="$(cd "$(dirname "$0")" && pwd)/"

# Pas de --delete ici : un transfert de routine ne doit pas pouvoir supprimer
# quoi que ce soit sur la machine. Pour un nettoyage des fichiers devenus
# obsolètes, ajouter --delete-after apres avoir verifie avec -n.
exec rsync -avz \
  --exclude '.git/' \
  --exclude '.terraform/' \
  --exclude '.terraform.lock.hcl' \
  --exclude 'terraform.tfstate*' \
  --exclude 'terraform.tfvars' \
  --exclude 'plan.tfplan' \
  --exclude 'ansible/inventaire/hosts.yml' \
  --exclude 'ansible/inventaire/group_vars/coffre.yml' \
  --exclude '*.qcow2' \
  --exclude '*.iso' \
  --exclude 'rapport/' \
  --exclude 'Docs/' \
  --exclude '.DS_Store' \
  "$SOURCE" "${CIBLE}:~/airbuslabo/"
