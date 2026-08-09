# Un reseau virtuel par VLAN du plan d'adressage.
# Sans sortie, le reseau est isole et le routage revient au Palo Alto.

terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8.0"
    }
  }
}

locals {
  # Un VLAN sans adressage ne sort jamais, quoi qu'on demande.
  sortie = {
    for cle, v in var.vlans :
    cle => var.sortie_activee && contains(var.vlans_avec_sortie, cle) && v.reseau != null
  }
}

resource "libvirt_network" "vlan" {
  for_each = var.vlans

  # Lisible dans virsh net-list : lab-vlan10-mgmt
  name      = format("%s-vlan%d-%s", var.prefixe, each.value.id, lower(each.value.nom))
  mode      = local.sortie[each.key] ? "nat" : "none"
  autostart = var.demarrage_automatique

  # Le VLAN natif n'a ni domaine ni plage : il est declare pour respecter le
  # plan, et volontairement inutilise.
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
