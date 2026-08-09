# Assemblage des modules. Rien n'est ecrit en dur ici : tout vient de
# inventaire.tf ou de variables.tf.

module "reseau" {
  source = "./modules/reseau"

  prefixe               = var.prefixe
  domaine_dns           = var.domaine_dns
  vlans                 = local.vlans
  vlans_avec_sortie     = local.vlans_avec_sortie
  sortie_activee        = var.acces_internet_construction
  demarrage_automatique = true
}

# Telechargee une fois et partagee : les disques des serveurs n'en gardent que
# les differences.
resource "libvirt_volume" "ubuntu_base" {
  name   = "${var.prefixe}-ubuntu-2204-base.qcow2"
  pool   = var.pool_stockage
  source = var.image_ubuntu
  format = "qcow2"
}

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

  # Le resolveur est la passerelle du VLAN d'administration, ou libvirt expose
  # le DNS du laboratoire.
  dns         = [local.vlans["mgmt"].passerelle]
  domaine_dns = var.domaine_dns

  admin_utilisateur = var.admin_utilisateur
  cle_ssh_publique  = var.cle_ssh_publique
  fuseau_horaire    = var.fuseau_horaire
  serveurs_ntp      = var.serveurs_ntp

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

# Inventaire Ansible, ecrit apres la creation des machines pour que les deux
# outils partent des memes adresses.
resource "local_file" "inventaire_ansible" {
  filename        = "${path.module}/../ansible/inventaire/hosts.yml"
  file_permission = "0644"

  content = join("\n", [
    "# Genere par Terraform a partir de infrastructure/inventaire.tf.",
    "# Toute retouche manuelle sera perdue au prochain apply.",
    yamlencode({
      all = {
        vars = {
          ansible_user               = var.admin_utilisateur
          ansible_python_interpreter = "/usr/bin/python3"
          domaine_dns                = var.domaine_dns
          fuseau_horaire             = var.fuseau_horaire
          serveurs_ntp               = var.serveurs_ntp
          supervision_ip             = local.ip_supervision
          vlan_users                 = local.vlans["users"].reseau
          vlan_equip                 = local.vlans["equip"].reseau
        }
        children = merge(
          {
            serveurs = {
              vars     = { ansible_become = true }
              children = local.groupes_serveurs
            }
          },
          length(local.groupes_parefeux) > 0 ? {
            parefeux = { children = local.groupes_parefeux }
          } : {}
        )
      }
    }),
  ])

  depends_on = [module.serveur, module.parefeu]
}
