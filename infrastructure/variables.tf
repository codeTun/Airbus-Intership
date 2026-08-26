# Les valeurs par defaut suivent le cahier des charges. Ne surcharger dans
# terraform.tfvars que ce qui depend de la machine hote.

variable "libvirt_uri" {
  description = "Connexion a libvirt. Distant : qemu+ssh://user@serveur/system"
  type        = string
  default     = "qemu:///system"
}

variable "pool_stockage" {
  description = "Pool de stockage libvirt qui recoit les disques."
  type        = string
  default     = "default"
}

variable "prefixe" {
  description = "Prefixe des noms d'objets, pour isoler plusieurs laboratoires sur un meme hote."
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

variable "image_ubuntu" {
  description = "Image Ubuntu Server 22.04 LTS au format cloud. Une URL est acceptee, libvirt la telecharge au premier apply."
  type        = string
  default     = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
}

variable "image_windows" {
  description = "Chemin local du gabarit Windows Server syspreppe, prepare une fois a la main. Laisser vide pour ne pas deployer les machines Windows."
  type        = string
  default     = ""
}

variable "admin_mot_de_passe_windows" {
  description = "Mot de passe initial du compte d'administration Windows. Obligatoire cote Windows, l'acces reste par cle SSH."
  type        = string
  default     = ""
  sensitive   = true
}

variable "fuseau_horaire_windows" {
  description = "Fuseau au format Windows, distinct du format IANA. Europe/Paris s'ecrit Romance Standard Time."
  type        = string
  default     = "Romance Standard Time"
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

variable "admin_utilisateur" {
  description = "Compte nominatif cree sur chaque serveur. Sans mot de passe : l'acces se fait par cle."
  type        = string
  default     = "adminlab"
}

variable "cle_ssh_publique" {
  description = "Cle SSH publique autorisee. Sans elle, les machines seraient inaccessibles."
  type        = string

  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-) ", var.cle_ssh_publique))
    error_message = "Fournir une cle SSH publique complete, par exemple le contenu de ~/.ssh/id_ed25519.pub."
  }
}

variable "acces_internet_construction" {
  description = "Sortie Internet temporaire sur les VLAN d'administration et de serveurs, le temps d'installer les paquets. A repasser a false ensuite : le routage doit alors passer par le Palo Alto."
  type        = bool
  default     = true
}

variable "demarrage_automatique" {
  description = "Demarre les machines avec l'hote. A laisser a false sur un poste de travail."
  type        = bool
  default     = false
}

variable "fuseau_horaire" {
  description = "Fuseau horaire applique a tous les serveurs."
  type        = string
  default     = "Europe/Paris"
}

variable "serveurs_ntp" {
  description = "Sources de temps utilisees par chrony."
  type        = list(string)
  default     = ["0.fr.pool.ntp.org", "1.fr.pool.ntp.org"]
}
