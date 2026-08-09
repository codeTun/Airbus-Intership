###############################################################################
#  Laboratoire virtualise, partie 1 du cahier des charges
#
#  Assemble les trois modules a partir de l'inventaire :
#    1. les reseaux, un par VLAN
#    2. l'image Ubuntu de base, telechargee une seule fois
#    3. les quatre serveurs metiers et de supervision
#    4. les deux pare-feux, si leurs images sont fournies
#
#  Rien n'est ecrit en dur ici : tout vient de inventaire.tf ou de variables.tf.
###############################################################################

# ------------------------------------------------------------------ reseaux
module "reseau" {
  source = "./modules/reseau"

  prefixe               = var.prefixe
  domaine_dns           = var.domaine_dns
  vlans                 = local.vlans
  vlans_avec_sortie     = local.vlans_avec_sortie
  sortie_activee        = var.acces_internet_construction
  demarrage_automatique = true
}

# -------------------------------------------------------- image Ubuntu 22.04
# Telechargee une fois puis partagee : les disques des serveurs n'en gardent
# que les differences, ce qui reduit fortement la place occupee.
resource "libvirt_volume" "ubuntu_base" {
  name   = "${var.prefixe}-ubuntu-2204-base.qcow2"
  pool   = var.pool_stockage
  source = var.image_ubuntu
  format = "qcow2"
}

# ----------------------------------------------------------------- serveurs
module "serveur" {
  source   = "./modules/serveur"
  for_each = local.serveurs

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

  # Le resolveur est la passerelle du VLAN d'administration, ou libvirt
  # expose le DNS local du laboratoire.
  dns         = [local.vlans["mgmt"].passerelle]
  domaine_dns = var.domaine_dns

  admin_utilisateur = var.admin_utilisateur
  cle_ssh_publique  = var.cle_ssh_publique
  fuseau_horaire    = var.fuseau_horaire
  serveurs_ntp      = var.serveurs_ntp

  demarrage_automatique = var.demarrage_automatique
}

# ----------------------------------------------------------------- pare-feux
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

# ------------------------------------------------------- inventaire Ansible
# Ecrit apres la creation des machines, pour qu'Ansible parte des memes
# adresses que Terraform. C'est ce qui evite les deux inventaires qui
# divergent, faute classique quand on separe socle et configuration.
resource "local_file" "inventaire_ansible" {
  filename        = "${path.module}/../ansible/inventaire/hosts.yml"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/inventaire-ansible.yml.tftpl", {
    admin_utilisateur = var.admin_utilisateur
    domaine_dns       = var.domaine_dns
    fuseau_horaire    = var.fuseau_horaire
    serveurs_ntp      = var.serveurs_ntp
    supervision_ip    = local.ip_supervision
    vlan_users        = local.vlans["users"].reseau
    vlan_equip        = local.vlans["equip"].reseau

    groupes_serveurs = {
      for groupe in distinct([for s in local.serveurs : s.groupe]) :
      groupe => { for nom, s in local.serveurs : nom => s.ip if s.groupe == groupe }
    }

    groupes_parefeux = {
      for groupe in distinct([for f in local.parefeux : f.groupe if trimspace(f.image) != ""]) :
      groupe => {
        for nom, f in local.parefeux : nom => f.ip_admin
        if f.groupe == groupe && trimspace(f.image) != ""
      }
    }
  })

  depends_on = [module.serveur, module.parefeu]
}
