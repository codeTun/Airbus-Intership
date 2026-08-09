variable "prefixe" {
  description = "Prefixe des noms de reseau."
  type        = string
}

variable "domaine_dns" {
  description = "Domaine DNS interne du laboratoire."
  type        = string
}

variable "vlans" {
  description = "Plan VLAN complet, issu de l'inventaire."
  type = map(object({
    id         = number
    nom        = string
    reseau     = optional(string)
    passerelle = optional(string)
    dhcp       = bool
    usage      = string
  }))
}

variable "vlans_avec_sortie" {
  description = "Cles des VLAN autorises a sortir vers Internet."
  type        = list(string)
  default     = []
}

variable "sortie_activee" {
  description = "Interrupteur global de la sortie Internet."
  type        = bool
  default     = false
}

variable "demarrage_automatique" {
  description = "Demarre les reseaux avec l'hote."
  type        = bool
  default     = true
}
