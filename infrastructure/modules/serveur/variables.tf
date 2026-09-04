variable "nom" {
  description = "Nom de la machine, qui sert aussi de nom d'hote."
  type        = string
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
  description = "Identifiant du volume Ubuntu de base, partage par tous les serveurs."
  type        = string
}

variable "reseau_id" {
  description = "Identifiant du reseau libvirt auquel la machine est raccordee."
  type        = string
}

variable "mac" {
  description = "Adresse MAC fixe, qui permet a cloud-init de reconnaitre l'interface."
  type        = string
}

variable "ip" {
  description = "Adresse IP fixe de la machine."
  type        = string
}

# Une machine peut etre raccordee a plusieurs reseaux. Le cas d'usage est la
# station de supervision, qui doit joindre les machines de plusieurs VLAN sans
# dependre d'un routage inter-VLAN. Aucune de ces interfaces ne porte de route
# par defaut : la passerelle reste celle de l'interface principale.
variable "reseaux_secondaires" {
  description = "Interfaces supplementaires, chacune avec son reseau, sa MAC et son adresse."
  type = list(object({
    reseau_id = string
    mac       = string
    ip        = string
    masque    = number
  }))
  default = []
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

variable "domaine_dns" {
  description = "Domaine de recherche DNS."
  type        = string
}

# ------------------------------------------------------------- durcissement
variable "admin_utilisateur" {
  description = "Compte nominatif cree sur la machine."
  type        = string
}

variable "cle_ssh_publique" {
  description = "Cle SSH publique autorisee."
  type        = string
}

variable "fuseau_horaire" {
  description = "Fuseau horaire."
  type        = string
}

variable "serveurs_ntp" {
  description = "Sources de temps."
  type        = list(string)
}

variable "demarrage_automatique" {
  description = "Demarre la machine avec l'hote."
  type        = bool
  default     = false
}
