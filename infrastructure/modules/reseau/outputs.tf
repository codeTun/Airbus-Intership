output "ids" {
  description = "Identifiant libvirt de chaque reseau, indexe par cle de VLAN."
  value       = { for cle, r in libvirt_network.vlan : cle => r.id }
}

output "noms" {
  description = "Nom libvirt de chaque reseau, indexe par cle de VLAN."
  value       = { for cle, r in libvirt_network.vlan : cle => r.name }
}

output "recapitulatif" {
  description = "Plan VLAN tel que reellement cree, pour verification."
  value = {
    for cle, v in var.vlans : cle => {
      vlan       = v.id
      nom        = v.nom
      reseau     = coalesce(v.reseau, "sans adressage")
      passerelle = coalesce(v.passerelle, "sans passerelle")
      dhcp       = v.dhcp
      sortie     = local.sortie[cle]
      usage      = v.usage
    }
  }
}
