###############################################################################
#  Parametres du deploiement
#  Les valeurs par defaut correspondent au cahier des charges.
#  Ne surcharger que ce qui depend de la machine hote, via terraform.tfvars.
###############################################################################

# ----------------------------------------------------------------- hote KVM
variable "libvirt_uri" {
  description = "URI de connexion a libvirt sur l'hote de virtualisation."
  type        = string
  default     = "qemu:///system"
}

variable "pool_stockage" {
  description = "Pool de stockage libvirt qui recoit les disques des machines."
  type        = string
  default     = "default"
}

variable "prefixe" {
  description = "Prefixe applique aux noms des objets crees, pour isoler plusieurs laboratoires sur un meme hote."
  type        = string
  default     = "lab"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,15}$", var.prefixe))
    error_message = "Le prefixe doit etre en minuscules, sans accent, de 1 a 16 caracteres."
  }
}

variable "domaine_dns" {
  description = "Domaine DNS interne du laboratoire."
  type        = string
  default     = "lab.airbus.local"
}

# --------------------------------------------------------------- images disque
variable "image_ubuntu" {
  description = <<-EOT
    Image de base Ubuntu Server 22.04 LTS au format cloud (exigence INF-03).
    Une URL est acceptee, libvirt la telecharge au premier apply.
    Sur un hote sans acces Internet, indiquer un chemin local.
  EOT
  type        = string
  default     = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
}

variable "image_fortios" {
  description = "Chemin local du disque FortiOS (qcow2) fourni par Fortinet. Laisser vide pour ne pas deployer ce pare-feu."
  type        = string
  default     = ""
}

variable "image_panos" {
  description = "Chemin local du disque PAN-OS (qcow2) fourni par Palo Alto. Laisser vide pour ne pas deployer ce pare-feu."
  type        = string
  default     = ""
}

# ------------------------------------------------------------------- comptes
variable "admin_utilisateur" {
  description = "Compte nominatif cree sur chaque serveur (exigence INF-06). Aucun mot de passe n'est defini, l'acces se fait par cle."
  type        = string
  default     = "adminlab"
}

variable "cle_ssh_publique" {
  description = "Cle SSH publique autorisee sur les serveurs. Obligatoire : sans elle, les machines seraient inaccessibles."
  type        = string

  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-) ", var.cle_ssh_publique))
    error_message = "Fournir une cle SSH publique complete, par exemple le contenu de ~/.ssh/id_ed25519.pub."
  }
}

# ------------------------------------------------------------- comportement
variable "acces_internet_construction" {
  description = <<-EOT
    Ouvre temporairement une sortie Internet sur les VLAN d'administration et
    de serveurs, le temps que cloud-init installe les paquets.
    A repasser a false une fois les services installes : le routage doit alors
    passer par le pare-feu Palo Alto, comme prevu par l'architecture.
  EOT
  type        = bool
  default     = true
}

variable "demarrage_automatique" {
  description = "Demarre les machines avec l'hote. A laisser a false sur un poste de travail, ou la memoire est comptee."
  type        = bool
  default     = false
}

variable "fuseau_horaire" {
  description = "Fuseau horaire applique a tous les serveurs."
  type        = string
  default     = "Europe/Paris"
}

variable "serveurs_ntp" {
  description = "Sources de temps utilisees par chrony (exigence INF-07)."
  type        = list(string)
  default     = ["0.fr.pool.ntp.org", "1.fr.pool.ntp.org"]
}
