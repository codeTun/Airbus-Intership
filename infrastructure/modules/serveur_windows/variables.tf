variable "nom" {
  description = "Nom de la machine, qui sert aussi de nom d'hote Windows."
  type        = string

  # Windows tronque en silence au-dela de 15 caracteres, et le numero
  # d'instance saute. Mieux vaut refuser tout de suite.
  validation {
    condition     = length(var.nom) <= 15
    error_message = "NetBIOS plafonne le nom d'hote Windows a 15 caracteres. Renommez cette machine dans inventaire.tf."
  }
}

variable "description" {
  description = "Role de la machine, repris dans la description libvirt."
  type        = string
}

variable "vcpu" {
  description = "Nombre de processeurs virtuels."
  type        = number
}

variable "memoire_mo" {
  description = "Memoire vive en mebioctets."
  type        = number
}

variable "disque_go" {
  description = "Taille du disque en gibioctets, allouee a la demande."
  type        = number
}

variable "pool_stockage" {
  description = "Pool de stockage libvirt."
  type        = string
}

variable "volume_base_id" {
  description = "Identifiant du gabarit Windows syspreppe, partage par les machines Windows."
  type        = string
}

variable "reseau_id" {
  description = "Identifiant du reseau libvirt auquel la machine est raccordee."
  type        = string
}

variable "mac" {
  description = "Adresse MAC fixe. Le script d'amorcage s'en sert pour reconnaitre l'interface."
  type        = string
}

variable "ip" {
  description = "Adresse IP fixe de la machine."
  type        = string
}

variable "masque" {
  description = "Longueur du prefixe reseau."
  type        = number
  default     = 24
}

variable "passerelle" {
  description = "Passerelle par defaut du VLAN."
  type        = string
}

variable "dns" {
  description = "Serveurs DNS transmis a la machine."
  type        = list(string)
}

# ------------------------------------------------------------- durcissement
variable "admin_utilisateur" {
  description = "Compte local d'administration, utilise ensuite par Ansible."
  type        = string
}

variable "admin_mot_de_passe" {
  description = "Mot de passe initial du compte d'administration. Windows refuse un compte sans mot de passe : l'acces reste par cle SSH."
  type        = string
  sensitive   = true
}

variable "cle_ssh_publique" {
  description = "Cle SSH publique autorisee pour le compte d'administration."
  type        = string
}

variable "fuseau_horaire_windows" {
  description = "Identifiant de fuseau au format Windows, distinct du format IANA. Europe/Paris s'ecrit Romance Standard Time."
  type        = string
  default     = "Romance Standard Time"
}

variable "demarrage_automatique" {
  description = "Demarre la machine avec l'hote."
  type        = bool
  default     = false
}
