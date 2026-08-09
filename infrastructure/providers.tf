###############################################################################
#  Fournisseur et versions
#
#  Cible : virtualisation locale KVM / libvirt, conformement au scenario B
#  du cahier des charges (deploiement local, sans cloud public).
#
#  Portage ultérieur vers AWS ou Azure : seuls ce fichier et le contenu des
#  modules changent. L'inventaire (inventaire.tf), le plan VLAN, l'adressage
#  et les cloud-init restent identiques.
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8.0"
    }
    # Sert uniquement a ecrire l'inventaire Ansible sur le disque.
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "libvirt" {
  # Hote local        : "qemu:///system"
  # Hote distant      : "qemu+ssh://user@serveur/system"
  uri = var.libvirt_uri
}
