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

module "serveur" {
  source   = "./modules/serveur"
  for_each = local.serveurs_ubuntu

  nom         = each.key
  description = each.value.description
  vcpu        = each.value.vcpu
  memoire_mo  = each.value.memoire_mo
  disque_go   = each.value.disque_go

  pool_stockage  = var.pool_stockage
  volume_base_id = libvirt_volume.ubuntu_base.id

  reseau_id  = module.reseau.ids[each.value.vlan]
  mac        = local.mac_serveurs[each.key]
  ip         = each.value.ip
  passerelle = local.vlans[each.value.vlan].passerelle

  # libvirt expose le DNS du laboratoire sur la passerelle du VLAN mgmt.
  dns         = [local.vlans["mgmt"].passerelle]
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

  dns = [local.vlans["mgmt"].passerelle]

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
            parefeux = { children = local.groupes_parefeux }
          } : {}
        )
      }
    }),
  ])

  depends_on = [module.serveur, module.serveur_windows, module.parefeu]
}
