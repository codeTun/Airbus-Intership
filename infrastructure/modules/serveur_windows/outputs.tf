output "nom" {
  description = "Nom de la machine."
  value       = libvirt_domain.vm.name
}

output "id" {
  description = "Identifiant libvirt de la machine."
  value       = libvirt_domain.vm.id
}

output "ip" {
  description = "Adresse IP fixe posee par le script d'amorcage."
  value       = var.ip
}

output "mac" {
  description = "Adresse MAC de l'interface."
  value       = var.mac
}

output "acces_ssh" {
  description = "Commande de connexion a la machine."
  value       = "ssh ${var.admin_utilisateur}@${var.ip}"
}
