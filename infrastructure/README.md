# Laboratoire virtualisé, partie 1

Déploiement automatisé des six machines de la partie 1 du cahier des charges, avec Terraform.
Cible : virtualisation locale KVM et libvirt, sans cloud public.

Ce code couvre les exigences **INF-01** à **INF-09** : les deux pare-feux, une machine par service, Ubuntu Server 22.04 LTS, la supervision, le plan VLAN, le durcissement, la synchronisation de l'heure, le versionnement et l'automatisation.

---

## 1. Ce qu'il faut sur la machine hôte

| Élément | Pourquoi | Vérification |
|---|---|---|
| Processeur **x86_64** avec VT-x ou AMD-V | Les images FortiOS et PAN-OS n'existent qu'en x86_64 | `grep -cE 'vmx\|svm' /proc/cpuinfo` |
| **32 Go de mémoire** au minimum | Le laboratoire complet en demande 26 | `free -g` |
| Linux avec **KVM, libvirt et QEMU** | Le fournisseur Terraform pilote libvirt | `virsh version` |
| **Terraform 1.5** ou plus | | `terraform version` |
| Un pool de stockage libvirt nommé `default` | Reçoit les disques | `virsh pool-list` |

Installation sur Ubuntu ou Debian :

```bash
sudo apt install qemu-kvm libvirt-daemon-system virtinst
sudo usermod -aG libvirt,kvm "$USER"     # se reconnecter ensuite
virsh --connect qemu:///system list      # doit répondre sans erreur
```

> **Ce Mac ne peut pas exécuter le laboratoire**
> Le poste actuel est en Apple Silicon (arm64) avec 16 Go de mémoire, et libvirt n'y est pas disponible. Les images des pare-feux ne tourneraient qu'en émulation, à une vitesse inutilisable. Sur ce poste, seules les commandes `make verifier` et `make init` ont du sens : elles valident le code. Le déploiement se fera sur la machine Intel fournie par l'entreprise.

---

## 2. Mise en route

```bash
cd infrastructure
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars          # y coller votre clé SSH publique

make init                         # télécharge le fournisseur libvirt
make verifier                     # format et validation
make plan                         # montre ce qui sera créé
make appliquer                    # crée l'infrastructure
```

Pour tout supprimer : `make detruire`.

La première exécution télécharge l'image Ubuntu (environ 700 Mo) puis crée les machines. Comptez une vingtaine de minutes, cloud-init installant ensuite les paquets en tâche de fond.

---

## 3. Organisation du code

```
infrastructure/
├── providers.tf              fournisseur libvirt et versions
├── variables.tf              paramètres du déploiement
├── inventaire.tf             plan VLAN, adressage et machines
├── main.tf                   assemblage des modules
├── outputs.tf                adresses, accès et vérification du dimensionnement
├── terraform.tfvars          valeurs locales, non versionné
└── modules/
    ├── reseau/               un réseau virtuel par VLAN
    ├── serveur/              machine Ubuntu avec cloud-init
    │   └── templates/        user-data et network-config
    └── parefeu/              machine à image constructeur
```

**`inventaire.tf` est la source de vérité.** Il reprend les tableaux 6, 7 et 8 du cahier des charges. Ajouter un serveur, changer une adresse ou un dimensionnement se fait uniquement là. Les modules ne connaissent pas les machines : on leur passe des valeurs.

---

## 4. Ce qui est déployé

| Machine | Rôle | VLAN | Adresse | vCPU | RAM | Disque |
|---|---|---|---|---|---|---|
| `fw-forti-01` | Pare-feu périmétrique | trunk | 10.10.10.254 | 1 | 2 Go | 40 Go |
| `fw-palo-01` | Pare-feu interne | trunk | 10.10.10.253 | 2 | 8 Go | 60 Go |
| `srv-print-01` | Impression, CUPS | 20 | 10.10.20.11 | 1 | 2 Go | 25 Go |
| `srv-visio-01` | Visioconférence, Jitsi | 20 | 10.10.20.12 | 2 | 4 Go | 25 Go |
| `srv-pointeuse-01` | Pointeuses, PostgreSQL | 20 | 10.10.20.13 | 1 | 2 Go | 30 Go |
| `sup-centreon-01` | Supervision | 10 | 10.10.10.30 | 4 | 8 Go | 60 Go |

La sortie `dimensionnement` compare automatiquement les totaux à ceux annoncés dans le cahier des charges, soit 11 vCPU, 26 Go et 240 Go.

Les sept VLAN du plan sont créés, y compris le VLAN natif 999 sans adressage.

---

## 5. Ce que fait cloud-init, et ce qu'il ne fait pas

Cloud-init **amorce** la machine, rien de plus. Il pose :

- un compte nominatif, sans mot de passe, accessible par clé SSH uniquement
- le compte `root` et l'authentification par mot de passe désactivés
- l'adressage fixe conforme au plan VLAN
- le pare-feu local `ufw` en refus par défaut, ouvert sur le seul port SSH
- les mises à jour de sécurité automatiques et l'heure par chrony
- un fichier d'échange de 2 Go avec `vm.swappiness=10`
- `python3`, nécessaire à Ansible

Il **n'installe aucun service métier**. Cloud-init ne s'exécute qu'une fois : il
ne sait ni se rejouer, ni corriger une dérive. Tout ce qui doit rester vrai dans
le temps appartient à Ansible, dans `../ansible/`.

---

## 6. Après Terraform : Ansible

`terraform apply` écrit `../ansible/inventaire/hosts.yml` avec les adresses
réelles. Il n'y a donc pas d'inventaire à tenir à jour à la main, et les deux
outils ne peuvent pas diverger.

```bash
cd ../ansible
make collections
make configurer
```

Ansible installe et configure les services métiers, la supervision Centreon et
les deux pare-feux. Voir `../ansible/README.md`.

**Les images des pare-feux** restent à récupérer auprès de Fortinet et de Palo
Alto. Renseignez `image_fortios` et `image_panos`, relancez `make appliquer`.
Tant que ces variables sont vides, les serveurs se déploient seuls, la sortie
indique `non déployé` et les pare-feux n'apparaissent pas dans l'inventaire
Ansible.

---

## 7. Portage vers AWS ou Azure

Le code est découpé pour que le passage au cloud ne touche qu'une couche.

| Fichier | Change au portage ? |
|---|---|
| `inventaire.tf` | Non. Le plan VLAN, l'adressage et le dimensionnement sont identiques. |
| `modules/serveur/templates/` | Non. Les mêmes cloud-init fonctionnent sur EC2 et sur Azure. |
| `providers.tf` | Oui, `dmacvicar/libvirt` devient `hashicorp/aws` ou `hashicorp/azurerm`. |
| `modules/*/main.tf` | Oui, les ressources libvirt deviennent des ressources cloud. |
| `main.tf`, `variables.tf`, `outputs.tf` | Marginalement. |

Les interfaces des modules ne mentionnent aucun terme propre à libvirt : elles parlent de `vcpu`, `memoire_mo`, `disque_go`, `ip`, `vlan`. Une implémentation AWS des mêmes modules se branche sans toucher au reste. Les types d'instance correspondants figurent au paragraphe 9.3 du cahier des charges.

---

## 8. Points de contrôle

| Cas | Vérification |
|---|---|
| **TI-01** Déploiement automatisé | `make appliquer` crée tout en une commande, la sortie `serveurs` liste les adresses attendues |
| **TI-02** Reconstruction | `make detruire` puis `make appliquer` redonne une infrastructure identique |
| **TI-05** Remontée dans la supervision | Les machines répondent au ping depuis `sup-centreon-01` |

Sur chaque serveur, `/etc/labo-airbus.yaml` indique le nom, le rôle et l'adresse, et le fichier `/var/lib/cloud/instance/deploiement-termine` confirme que cloud-init est allé au bout.
