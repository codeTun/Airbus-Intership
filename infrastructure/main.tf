# Assemblage des modules. Toutes les valeurs viennent d'inventaire.tf.

module "reseau" {
  source = "./modules/reseau"

  prefixe               = var.prefixe
  domaine_dns           = var.domaine_dns
  vlans                 = local.vlans
  vlans_avec_sortie     = local.vlans_avec_sortie
  sortie_activee        = var.acces_internet_construction
  demarrage_automatique = true
}

# Volume partage : les disques des serveurs n'en gardent que les differences,
# d'ou l'ecart entre taille declaree et place occupee.
resource "libvirt_volume" "ubuntu_base" {
  name   = "${var.prefixe}-ubuntu-2204-base.qcow2"
  pool   = var.pool_stockage
  source = var.image_ubuntu
  format = "qcow2"
}

# Gabarit Windows syspreppe, prepare une fois a la main. Voir le README.
resource "libvirt_volume" "windows_base" {
  count = trimspace(var.image_windows) != "" ? 1 : 0

  name   = "${var.prefixe}-windows-2022-base.qcow2"
  pool   = var.pool_stockage
  source = var.image_windows
  format = "qcow2"
}

# Image cloud Debian, pour la seule machine de supervision.
resource "libvirt_volume" "debian_base" {
  count = trimspace(var.image_debian) != "" ? 1 : 0

  name   = "${var.prefixe}-debian-12-base.qcow2"
  pool   = var.pool_stockage
  source = var.image_debian
  format = "qcow2"
}

module "serveur" {
  source   = "./modules/serveur"
  for_each = local.serveurs_linux

  nom         = each.key
  description = each.value.description
  vcpu        = each.value.vcpu
  memoire_mo  = each.value.memoire_mo
  disque_go   = each.value.disque_go

  pool_stockage = var.pool_stockage
  # Repli volontaire sur Ubuntu si l'image Debian n'est pas fournie : la
  # machine reste deployee, et c'est le role Ansible qui explique le blocage.
  volume_base_id = (
    each.value.os == "debian" && length(libvirt_volume.debian_base) > 0
    ? libvirt_volume.debian_base[0].id
    : libvirt_volume.ubuntu_base.id
  )

  reseau_id  = module.reseau.ids[each.value.vlan]
  mac        = local.mac_serveurs[each.key]
  ip         = each.value.ip
  passerelle = local.vlans[each.value.vlan].passerelle

  # Terraform pose la carte, Ansible l'adresse : cloud-init ne s'executant qu'au
  # premier demarrage, une machine deja en service ne verrait jamais la sienne.
  reseaux_secondaires = [
    for r in local.reseaux_secondaires[each.key] : {
      reseau_id = module.reseau.ids[r.vlan]
      mac       = r.mac
      ip        = r.ip
      masque    = r.masque
    }
  ]

  # libvirt fait tourner un resolveur par reseau, sur la passerelle de celui-ci.
  # Designer celle du VLAN mgmt donnerait aux machines des autres VLAN une
  # adresse qu'elles ne joignent pas, et toute resolution echouerait.
  dns         = [local.vlans[each.value.vlan].passerelle]
  domaine_dns = var.domaine_dns

  admin_utilisateur = var.admin_utilisateur
  cle_ssh_publique  = var.cle_ssh_publique
  fuseau_horaire    = var.fuseau_horaire
  serveurs_ntp      = var.serveurs_ntp

  demarrage_automatique = var.demarrage_automatique
}

module "serveur_windows" {
  source   = "./modules/serveur_windows"
  for_each = local.serveurs_windows

  nom         = each.key
  description = each.value.description
  vcpu        = each.value.vcpu
  memoire_mo  = each.value.memoire_mo
  disque_go   = each.value.disque_go

  pool_stockage  = var.pool_stockage
  volume_base_id = libvirt_volume.windows_base[0].id

  reseau_id  = module.reseau.ids[each.value.vlan]
  mac        = local.mac_serveurs[each.key]
  ip         = each.value.ip
  passerelle = local.vlans[each.value.vlan].passerelle

  dns = [local.vlans[each.value.vlan].passerelle]

  admin_utilisateur      = var.admin_utilisateur
  admin_mot_de_passe     = var.admin_mot_de_passe_windows
  cle_ssh_publique       = var.cle_ssh_publique
  fuseau_horaire_windows = var.fuseau_horaire_windows

  demarrage_automatique = var.demarrage_automatique
}

module "parefeu" {
  source   = "./modules/parefeu"
  for_each = local.parefeux

  nom         = each.key
  description = each.value.description
  vcpu        = each.value.vcpu
  memoire_mo  = each.value.memoire_mo
  disque_go   = each.value.disque_go
  image       = each.value.image
  ip_admin    = each.value.ip_admin

  pool_stockage = var.pool_stockage
  reseaux_ids   = [for v in each.value.reseaux : module.reseau.ids[v]]

  demarrage_automatique = var.demarrage_automatique
}

# Ecrit apres la creation des machines : Terraform et Ansible partent ainsi
# des memes adresses, sans inventaire a tenir a jour a la main.
resource "local_file" "inventaire_ansible" {
  filename        = "${path.module}/../ansible/inventaire/hosts.yml"
  file_permission = "0644"

  content = join("\n", [
    "# Genere par Terraform a partir de infrastructure/inventaire.tf.",
    "# Toute retouche manuelle sera perdue au prochain apply.",
    yamlencode({
      all = {
        vars = {
          ansible_user   = var.admin_utilisateur
          domaine_dns    = var.domaine_dns
          fuseau_horaire = var.fuseau_horaire
          serveurs_ntp   = var.serveurs_ntp
          supervision_ip = local.ip_supervision
          vlan_users     = local.vlans["users"].reseau
          vlan_equip     = local.vlans["equip"].reseau
        }
        children = merge(
          { serveurs = { children = local.groupes_serveurs } },
          local.groupes_os,
          length(local.groupes_parefeux) > 0 ? {
            parefeux = {
              children = local.groupes_parefeux
              vars = {
                # Un pare-feu ne s'administre pas par SSH : il n'a ni shell POSIX
                # ni interpreteur Python. Ansible tourne sur le poste et dialogue
                # avec son API REST. Declare ici, et non seulement dans site.yml,
                # pour que les commandes ad hoc se comportent de meme.
                ansible_connection = "local"
                ansible_become     = false
              }
            }
          } : {}
        )
      }
    }),
  ])

  depends_on = [module.serveur, module.serveur_windows, module.parefeu]
}

# Configuration du relais de publication, generee ici pour que les adresses ne
# soient ecrites qu'une seule fois, dans inventaire.tf. Le fichier se pose sur
# l'hote par `make publication`, qui le copie et recharge nginx.
#
# Il vise /etc/nginx/modules-enabled/ et non sites-enabled/ : un bloc stream se
# declare a la racine de la configuration, hors du bloc http, et modules-enabled
# est le seul repertoire que Debian inclut a ce niveau. Le prefixe 60 le fait
# charger apres 50-mod-stream.conf, qui fournit le module.
resource "local_file" "publication_nginx" {
  filename        = "${path.module}/publication/60-labo-publication.conf"
  file_permission = "0644"

  content = join("\n", concat(
    [
      "# Genere par Terraform a partir de infrastructure/inventaire.tf.",
      "# Toute retouche manuelle sera perdue au prochain apply.",
      "#",
      "# Relais TCP brut : nginx ne dechiffre rien, le certificat vu par le",
      "# navigateur est celui du service. Se pose dans modules-enabled, seul",
      "# repertoire inclus hors du bloc http, ou un bloc stream peut vivre.",
      "",
      "stream {",
    ],
    [for port in sort(keys(local.publications)) :
      format(
        "    server { listen %s; proxy_pass %-18s }  # %s",
        port,
        format("%s:%d;", local.adresses_publiables[local.publications[port].cible], local.publications[port].port),
        local.publications[port].service,
      )
    ],
    ["}", ""],
  ))
}
