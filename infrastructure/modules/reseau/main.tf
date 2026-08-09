###############################################################################
#  Module reseau
#
#  Cree un reseau virtuel par VLAN du plan d'adressage (exigence INF-05).
#
#  Trois cas sont geres :
#    - VLAN adresse, sans sortie   -> reseau isole, routage assure par le
#                                     pare-feu Palo Alto
#    - VLAN adresse, avec sortie   -> traduction d'adresses, le temps de
#                                     l'installation des paquets
#    - VLAN sans adressage (999)   -> reseau isole, ni DHCP ni DNS
###############################################################################

terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8.0"
    }
  }
}

locals {
  # Un VLAN sort vers Internet s'il est dans la liste ET si l'interrupteur
  # global est arme. Un VLAN sans adressage ne sort jamais.
  sortie = {
    for cle, v in var.vlans :
    cle => var.sortie_activee && contains(var.vlans_avec_sortie, cle) && v.reseau != null
  }
}

resource "libvirt_network" "vlan" {
  for_each = var.vlans

  # Nom lisible dans virsh net-list, par exemple : lab-vlan10-mgmt
  name      = format("%s-vlan%d-%s", var.prefixe, each.value.id, lower(each.value.nom))
  mode      = local.sortie[each.key] ? "nat" : "none"
  autostart = var.demarrage_automatique

  # Un reseau sans adressage n'a ni domaine ni plage : c'est le VLAN natif,
  # declare pour respecter le plan mais volontairement inutilise.
  addresses = each.value.reseau == null ? [] : [each.value.reseau]
  domain    = each.value.reseau == null ? null : format("%s.%s", lower(each.value.nom), var.domaine_dns)

  dhcp {
    enabled = each.value.dhcp
  }

  dns {
    enabled    = each.value.reseau != null
    local_only = !local.sortie[each.key]
  }
}
