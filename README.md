# Laboratoire virtualisé, stage Airbus

Automatisation complète de la partie 1 du cahier des charges : construction de
l'infrastructure avec Terraform, puis configuration des machines avec Ansible.

| Répertoire | Contenu |
|---|---|
| `Docs/` | Cahier des charges, en PDF, LaTeX et Markdown |
| `infrastructure/` | Terraform : machines virtuelles, réseaux, disques |
| `ansible/` | Ansible : configuration des serveurs et des pare-feux |

## Mise en route

```bash
cd infrastructure && make init && make appliquer   # crée les machines
cd ../ansible     && make configurer               # installe et configure
```

Chaque répertoire a son propre `README.md` avec les prérequis détaillés.

## Répartition des rôles

| Couche | Outil | Ce qu'elle fait | Rejouable |
|---|---|---|---|
| Socle | Terraform | machines, réseaux, disques | oui |
| Amorçage | cloud-init | compte, clé SSH, adressage, agent | une fois |
| Configuration | Ansible | services métiers, supervision, pare-feux | oui |
