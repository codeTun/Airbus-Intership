# Configuration du laboratoire

Ansible installe et configure les machines créées par Terraform. Le découpage
est classique et volontaire :

| Couche | Outil | Rôle | Rejouable |
|---|---|---|---|
| Socle | Terraform | machines, réseaux, disques | oui |
| Amorçage | cloud-init | compte, clé SSH, adressage, agent | une seule fois |
| Configuration | **Ansible** | services, supervision, pare-feux | **oui** |

Cloud-init ne s'exécute qu'au premier démarrage : il ne sait ni se rejouer, ni
rendre compte, ni corriger une dérive. Tout ce qui doit rester vrai dans le
temps appartient donc à Ansible.

---

## Mise en route

```bash
cd ansible
make collections            # collections Ansible nécessaires
cp inventaire/group_vars/coffre.yml.example inventaire/group_vars/coffre.yml
$EDITOR inventaire/group_vars/coffre.yml
ansible-vault encrypt inventaire/group_vars/coffre.yml

make verifier               # syntaxe et qualité, sans toucher aux machines
make simuler                # montre ce qui changerait
make configurer             # applique
make recette                # contrôle l'état obtenu
```

**L'inventaire n'est pas à écrire.** `inventaire/hosts.yml` est généré par
Terraform à chaque `apply`, à partir de `infrastructure/inventaire.tf`. Les
adresses ne peuvent donc pas diverger entre les deux outils.

---

## Les rôles

| Rôle | Machine | Ce qu'il fait |
|---|---|---|
| `commun` | toutes | Durcissement rejouable, heure, journaux vers la supervision |
| `impression` | `srv-print-01` | CUPS, files d'attente, quotas, accès limité au VLAN des postes |
| `visioconference` | `srv-visio-01` | Jitsi Meet installé sans interaction, ports 443 et 10000 |
| `pointeuses` | `srv-pointeuse-01` | PostgreSQL, schéma de collecte, sauvegarde quotidienne, contrôle de l'heure |
| `supervision` | `sup-centreon-01` | Centreon, réception des journaux, **déclaration des machines et des sondes** |
| `parefeu_fortinet` | `fw-forti-01` | Interfaces, règles, traduction d'adresses, journaux |
| `parefeu_paloalto` | `fw-palo-01` | Une zone et une sous-interface par VLAN, matrice de flux, profils |

Le rôle `supervision` est celui qui satisfait réellement **INF-04** : sans la
déclaration des hôtes et des sondes, Centreon serait installé mais ne
surveillerait rien.

---

## Les pare-feux, en deux temps

Les images constructeur n'acceptent pas cloud-init. Il faut donc :

**1. Amorcer**, une seule fois, pour rendre la machine joignable.

- **Palo Alto** dispose d'un mécanisme officiel : un disque virtuel contenant
  `config/init-cfg.txt` et `config/bootstrap.xml`. Il fixe l'adresse
  d'administration, le compte et la licence.
- **FortiGate** accepte une configuration déposée sur une image ISO attachée au
  premier démarrage.

**2. Configurer**, autant de fois qu'on veut, par l'API, ce que font les deux
rôles ci-dessus. Les collections `fortinet.fortios` et
`paloaltonetworks.panos` sont idempotentes : chaque exécution ramène le
pare-feu à l'état décrit dans les fichiers `defaults/main.yml`.

> **Licence d'évaluation Fortinet**
> Elle plafonne la machine à trois interfaces, trois règles et trois routes. Le
> rôle vérifie cette limite avant d'appliquer quoi que ce soit et s'arrête avec
> un message clair si la configuration la dépasse.

Après configuration, chaque pare-feu exporte sa configuration dans
`configurations/`, ce qui satisfait **INF-08** et **INF-10**.

---

## Secrets

Aucun mot de passe en clair dans le dépôt. Les valeurs sensibles vivent dans
`inventaire/group_vars/coffre.yml`, chiffré par `ansible-vault`. Le fichier
chiffré peut être versionné, le mot de passe du coffre ne l'est jamais.

---

## Exécutions partielles

```bash
make commun                        # seulement le durcissement
make services                      # seulement les trois services métiers
make supervision                   # seulement Centreon
make parefeux                      # seulement les pare-feux
ansible-playbook site.yml --tags parefeu    # seulement les règles de pare-feu local
ansible-playbook site.yml --limit srv-print-01
```

Toutes les tâches portent des étiquettes, ce qui évite de tout rejouer pour
corriger un détail.
