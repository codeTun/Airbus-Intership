variable "nom" {
  description = "Nom du pare-feu."
  type        = string
}

variable "description" {
  description = "Role du pare-feu."
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
  description = "Taille du disque en gibioctets."
  type        = number
}

variable "image" {
  description = "Chemin ou URL du disque constructeur. Vide, le pare-feu n'est pas cree."
  type        = string
}

variable "pool_stockage" {
  description = "Pool de stockage libvirt."
  type        = string
}

variable "reseaux_ids" {
  description = "Identifiants des reseaux a raccorder, dans l'ordre des interfaces."
  type        = list(string)
}

variable "ip_admin" {
  description = "Adresse d'administration, a saisir dans l'interface du constructeur."
  type        = string
}

variable "demarrage_automatique" {
  description = "Demarre le pare-feu avec l'hote."
  type        = bool
  default     = false
}
