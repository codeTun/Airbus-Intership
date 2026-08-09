# Partie 1 : Configuration automatisée avec Ansible

---

## Pourquoi Ansible en plus de Terraform

Terraform crée les machines, il ne les configure pas. Restait donc à installer les services métiers, la supervision et les pare-feux, puis à faire en sorte que cette configuration reste vraie dans le temps.

Une première version confiait ce travail à cloud-init, qui était déjà utilisé pour l'amorçage des machines. Cette approche a été abandonnée : cloud-init ne s'exécute qu'une seule fois, au tout premier démarrage. Il ne sait ni se rejouer, ni rendre compte de ce qu'il a fait, ni corriger une configuration qui aurait dérivé. La moindre modification obligerait à détruire puis recréer la machine.

Le projet est donc organisé en trois couches, chacune avec son outil et son périmètre.

**[INSÉRER ICI figure3-couches.png]**

*Figure 2 : Les trois couches d'automatisation*

Cloud-init a été ramené à son seul rôle d'amorçage : rendre la machine joignable et conforme au durcissement de base. Tout le reste appartient désormais à Ansible.

---

## Ce qui a été construit

La configuration représente environ 1 500 lignes réparties en 7 rôles et 84 tâches. L'organisation du code suit la structure standard d'un projet Ansible.

**[INSÉRER ICI figure2-ansible.png]**

*Figure 3 : Architecture du code, configuration Ansible*

---

## Structure du projet

Le répertoire `ansible/` est organisé de la façon suivante.

```
ansible/
├── ansible.cfg                   connexion SSH, inventaire, escalade de privilèges
├── site.yml                      enchaînement des rôles, machine par machine
├── requirements.yml              collections Ansible nécessaires
├── Makefile                      automatisation des tâches courantes
├── README.md                     documentation du projet
├── .yamllint / .ansible-lint     règles de qualité du code
│
├── inventaire/
│   ├── hosts.yml                 généré par Terraform, jamais écrit à la main
│   ├── hosts.yml.example         exemple, pour valider le code avant déploiement
│   └── group_vars/
│       ├── all.yml               variables communes à toutes les machines
│       └── coffre.yml            secrets chiffrés par ansible-vault
│
├── playbooks/
│   └── verification.yml          contrôle de l'état, sans rien modifier
│
├── configurations/               configurations des pare-feux, exportées
│
└── roles/
    ├── commun/                   durcissement, heure, journaux         (17 tâches)
    ├── impression/               CUPS                                   (9 tâches)
    ├── visioconference/          Jitsi Meet                            (12 tâches)
    ├── pointeuses/               PostgreSQL et collecte                (15 tâches)
    ├── supervision/              Centreon                              (16 tâches)
    ├── parefeu_fortinet/         FortiOS                                (7 tâches)
    └── parefeu_paloalto/         PAN-OS                                 (8 tâches)
```

Chaque rôle suit la même organisation interne :

| Répertoire | Contenu |
|---|---|
| `tasks/main.yml` | Les tâches à exécuter, dans l'ordre |
| `defaults/main.yml` | Les paramètres modifiables : ports, chemins, listes |
| `handlers/main.yml` | Les redémarrages de service, déclenchés seulement si nécessaire |
| `templates/` | Les fichiers de configuration générés à partir des variables |

Cette séparation permet de modifier un paramètre sans toucher à la logique. Par exemple, ajouter une imprimante se fait dans `roles/impression/defaults/main.yml`, sans ouvrir le fichier de tâches.

---

## Un inventaire généré, jamais écrit à la main

Le point le plus important de cette organisation concerne l'inventaire.

Quand on sépare la création de l'infrastructure de sa configuration, une erreur classique consiste à maintenir deux listes d'adresses : une dans Terraform, une dans Ansible. Ces deux listes finissent toujours par diverger, et l'on passe du temps à chercher pourquoi Ansible ne joint pas une machine qui existe pourtant.

Ici, le fichier `ansible/inventaire/hosts.yml` est **généré par Terraform** à chaque déploiement, directement depuis `infrastructure/inventaire.tf`. Il porte d'ailleurs un avertissement en en-tête indiquant que toute modification manuelle sera perdue.

Le résultat obtenu est le suivant :

```
@all:
  |--@serveurs:
  |  |--@impression:      srv-print-01
  |  |--@visioconference: srv-visio-01
  |  |--@pointeuses:      srv-pointeuse-01
  |  |--@supervision:     sup-centreon-01
  |--@parefeux:
  |  |--@fortinet:        fw-forti-01
  |  |--@paloalto:        fw-palo-01
```

Les groupes sont déduits automatiquement d'un champ `groupe` présent sur chaque machine dans l'inventaire Terraform. Ajouter un serveur revient donc à ajouter une entrée dans `inventaire.tf` : la machine est créée, et Ansible sait immédiatement quel rôle lui appliquer.

À noter également : un pare-feu n'apparaît dans l'inventaire que si son image constructeur a été fournie. Tant que ce n'est pas le cas, Ansible ne tente pas de le configurer et ne signale aucune erreur.

---

## Le rôle commun : le durcissement, mais rejouable

Le durcissement demandé par INF-06 est déjà posé par cloud-init à la création de la machine. Le rôle `commun` le réaffirme à chaque exécution.

Cette redondance est volontaire. Cloud-init garantit qu'une machine neuve est conforme ; le rôle `commun` garantit qu'elle l'est encore trois semaines plus tard, même si quelqu'un a ouvert un port ou désactivé un service entre-temps. C'est ce qui permet de prouver la conformité à tout moment, et non seulement le jour de la création.

Le rôle applique notamment :

- l'authentification SSH par clé uniquement, avec `root` et les mots de passe refusés ;
- le pare-feu local en refus par défaut, chaque rôle métier ouvrant ensuite ses propres ports ;
- les mises à jour de sécurité automatiques ;
- la synchronisation de l'heure par chrony, pour INF-07 ;
- des paramètres noyau de sécurité, comme le refus des redirections ICMP ;
- l'envoi des journaux vers le serveur de supervision ;
- une vérification que le fichier d'échange de 2 Go est toujours présent, avec arrêt en erreur s'il a disparu.

---

## Les trois services métiers

### Impression

Le rôle installe CUPS et crée une file d'attente par imprimante. Les quotas par utilisateur et la journalisation des travaux sont configurés pour permettre le suivi de consommation. L'accès est restreint au seul VLAN des postes de travail.

Une subtilité a demandé une attention particulière : la commande `lpadmin` n'est pas idempotente sur la description d'une file. Sans précaution, Ansible aurait signalé une modification à chaque exécution. Le rôle vérifie donc l'existence de la file avant de la créer.

### Visioconférence

Jitsi Meet pose normalement deux questions à l'installation : le nom de domaine et le type de certificat. Le rôle y répond à l'avance par `debconf`, ce qui rend l'installation entièrement automatique.

C'est une amélioration par rapport à la version précédente, où seul le dépôt était configuré et où il fallait ensuite lancer l'installation à la main.

### Pointeuses

Le rôle installe PostgreSQL, crée la base et applique un schéma de collecte comprenant les tables des terminaux et des pointages, ainsi qu'une vue `etat_collecte` qui indique la date du dernier pointage reçu. Cette vue est directement exploitée par la supervision.

Deux points sensibles sont traités explicitement :

- **La dérive d'horloge**, qui fausserait directement les pointages. Le rôle mesure l'état de l'horloge à chaque exécution et s'arrête en erreur si elle n'est pas lisible.
- **La perte de données**, qu'une interruption de collecte rendrait irrécupérable. Une sauvegarde quotidienne est planifiée, avec une rétention de quatorze jours.

La base n'écoute que sur la boucle locale : elle n'est jamais exposée sur le réseau.

---

## La supervision, qui satisfait réellement INF-04

L'exigence INF-04 demande qu'une machine sous Centreon surveille toutes les autres. Installer Centreon ne suffit donc pas : il faut aussi que les machines y soient déclarées, avec leurs sondes.

C'est ce que fait le rôle `supervision`, en trois temps :

1. **Installation** de Centreon depuis le dépôt officiel de l'éditeur.
2. **Réception des journaux** des autres machines, un fichier par machine émettrice.
3. **Déclaration des hôtes et des sondes** par la ligne de commande Centreon, plutôt que par l'interface web, afin que l'opération reste rejouable.

Les sondes dépendent du rôle de chaque machine et reprennent le tableau des indicateurs du cahier des charges : service CUPS et travaux en attente pour l'impression, les trois composants Jitsi pour la visioconférence, base PostgreSQL et date de dernière collecte pour les pointeuses.

Le rôle commence par une vérification de la distribution. Centreon ne publie de dépôt que pour Debian et la famille RHEL. Sur Ubuntu, le rôle s'arrête immédiatement avec un message qui explique la situation et rappelle la solution prévue au cahier des charges : basculer cette seule machine sous Debian 12. Il vaut mieux un arrêt net et explicite qu'une installation à moitié faite qui échouera plus loin sans qu'on sache pourquoi.

---

## Les pare-feux, en deux temps

C'est la partie qui répond à la question de la configuration complète des pare-feux.

Les images FortiOS et PAN-OS n'acceptent pas cloud-init : ce sont des systèmes constructeur fermés. La configuration se fait donc en deux étapes distinctes.

### Premier temps : l'amorçage, une seule fois

L'objectif est de rendre la machine joignable et licenciée.

- **Palo Alto** dispose d'un mécanisme officiel : un disque virtuel contenant `config/init-cfg.txt` et `config/bootstrap.xml`, attaché au premier démarrage. Il fixe l'adresse d'administration, le compte et la licence.
- **FortiGate** accepte une configuration déposée sur une image ISO attachée au premier démarrage.

### Second temps : la configuration, autant de fois qu'on veut

Une fois la machine joignable, Ansible prend le relais par l'API du constructeur. Les collections `fortinet.fortios` et `paloaltonetworks.panos` sont idempotentes : chaque exécution ramène le pare-feu à l'état décrit dans les fichiers de variables.

| Pare-feu | Ce qui est configuré |
|---|---|
| Fortinet | Interfaces et zones, règles en refus par défaut, traduction d'adresses, serveurs de temps, envoi des journaux |
| Palo Alto | Une zone de sécurité et une sous-interface de niveau 3 par VLAN, matrice de flux du cahier des charges, profils de sécurité |

Le rôle Fortinet commence par vérifier les limites de la licence d'évaluation permanente, qui plafonne la machine à trois interfaces, trois règles et trois routes. Si la configuration dépasse ces limites, le rôle s'arrête avec un message explicite plutôt que de laisser l'API échouer.

Après configuration, chaque pare-feu exporte sa configuration dans le répertoire `configurations/`, ce qui répond aux exigences INF-08 sur le versionnement et INF-10 sur la sauvegarde avant modification.

---

## Gestion des secrets

Aucun mot de passe ne figure en clair dans le dépôt.

Les valeurs sensibles, comme le mot de passe de la base des pointages ou les identifiants d'administration des pare-feux, vivent dans `inventaire/group_vars/coffre.yml`, chiffré par `ansible-vault`. Le fichier chiffré peut être versionné sans risque dans Git ; seul le mot de passe du coffre ne l'est jamais.

Un fichier `coffre.yml.example` est fourni comme modèle, avec des valeurs à remplacer.

---

## Exécutions partielles

Toutes les tâches portent des étiquettes, ce qui évite de tout rejouer pour corriger un détail.

| Commande | Effet |
|---|---|
| `make configurer` | Configure toutes les machines |
| `make commun` | Applique seulement le durcissement |
| `make services` | Configure seulement les trois services métiers |
| `make supervision` | Configure seulement Centreon |
| `make parefeux` | Configure seulement les pare-feux |
| `make simuler` | Montre ce qui changerait, sans rien modifier |
| `make recette` | Contrôle l'état du laboratoire, sans rien modifier |

Il est également possible de cibler une seule machine avec `--limit srv-print-01`, ou une seule préoccupation avec `--tags parefeu`.

---

## Vérifications réalisées

Plusieurs contrôles ont été effectués pour valider le code avant tout déploiement.

| Contrôle | Résultat |
|---|---|
| `yamllint` | Conforme |
| `ansible-playbook --syntax-check` | Conforme |
| `ansible-lint` | 0 échec, profil production, 5 étoiles sur 5 |
| Lecture de l'inventaire | 6 groupes correctement construits |
| Cohérence Terraform et Ansible | 6 groupes déclarés, 7 rôles présents, aucun orphelin |
| `terraform validate` | Success! The configuration is valid. |

L'analyse par `ansible-lint` a permis de corriger cinq points, dont **deux véritables erreurs** qui auraient échoué à l'exécution :

- le module `postgresql_query` n'accepte pas le paramètre `path_to_script` : il a été remplacé par `postgresql_script` ;
- le module `panos_ntp` n'existe pas dans la collection Palo Alto : la configuration NTP passe en réalité par `panos_mgtconfig`.

Sans cette analyse préalable, ces deux erreurs n'auraient été découvertes que sur la machine cible, en plein déploiement.

Deux modules dépréciés ont également été remplacés : `apt_repository` cède la place à `deb822_repository`, qui sera la seule forme supportée dans les prochaines versions d'Ansible.

---

## Conformité aux exigences

| Exigence | État |
|---|---|
| INF-02 : une machine par service métier | Conforme |
| INF-03 : Ubuntu Server 22.04 LTS | Conforme |
| INF-04 : Centreon surveille toutes les machines | Conforme, hôtes et sondes déclarés |
| INF-05 : plan VLAN et adressage | Conforme |
| INF-06 : durcissement des serveurs | Conforme, et rejouable |
| INF-07 : heure synchronisée par NTP | Conforme, serveurs et pare-feux |
| INF-08 : configurations versionnées dans Git | Conforme |
| INF-09 : création automatisée par Terraform | Conforme |
| INF-10 : sauvegarde avant modification | Conforme, export des pare-feux |
| INF-01 : deux pare-feux déployés | Code prêt, images constructeur à fournir |

---

## Ce qui reste à faire

Deux réserves méritent d'être posées clairement.

**Le code n'a pas encore tourné contre un véritable hyperviseur.** Il est validé sur le plan syntaxique et cohérent d'un bout à l'autre, mais il n'a pas été éprouvé à l'exécution. Le poste actuel est en Apple Silicon avec 16 Go de mémoire, et libvirt n'y est pas disponible. Le premier déploiement réel se fera sur la machine Intel fournie par l'entreprise.

**Les images des pare-feux restent à récupérer** auprès de Fortinet et de Palo Alto. Tant qu'elles ne sont pas fournies, les serveurs se déploient normalement et les pare-feux sont simplement absents de l'inventaire.

---

## Conclusion

La partie 1 est maintenant automatisée de bout en bout : Terraform crée l'infrastructure, cloud-init amorce les machines, Ansible installe et maintient la configuration.

Ce qui change par rapport à la version précédente tient en trois points. Les services métiers ne sont plus seulement préparés mais réellement installés et configurés. La supervision déclare désormais les machines et leurs sondes, ce qui satisfait enfin INF-04. Enfin, les deux pare-feux disposent d'une configuration complète et rejouable, là où il n'y avait auparavant que la création de la machine.

L'ensemble est rejouable : détruire puis reconstruire le laboratoire redonne exactement la même infrastructure, avec la même configuration, sans intervention manuelle.

La prochaine étape consiste à réaliser un déploiement complet sur la machine cible afin de valider l'ensemble en conditions réelles, puis à récupérer les images constructeur pour activer les deux pare-feux.
