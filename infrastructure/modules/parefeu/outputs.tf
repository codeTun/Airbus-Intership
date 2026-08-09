output "deploye" {
  description = "Vrai si l'image etait fournie et le pare-feu cree."
  value       = local.actif
}

output "nom" {
  description = "Nom du pare-feu, vide s'il n'est pas deploye."
  value       = local.actif ? libvirt_domain.vm[0].name : ""
}

output "ip_admin" {
  description = "Adresse d'administration a saisir dans l'interface du constructeur."
  value       = var.ip_admin
}

output "interfaces" {
  description = "Nombre d'interfaces raccordees."
  value       = local.actif ? length(var.reseaux_ids) : 0
}
