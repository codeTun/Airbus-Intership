# Machine Ubuntu amorcee par cloud-init. Le module ne connait pas le role de
# la machine : ajouter un serveur se fait par une entree d'inventaire.

terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8.0"
    }
  }
}

# Le volume de base reste intact, seules les differences sont ecrites. D'ou
# l'ecart entre la taille declaree et la place occupee.
resource "libvirt_volume" "disque" {
  name           = "${var.nom}.qcow2"
  pool           = var.pool_stockage
  base_volume_id = var.volume_base_id
  size           = var.disque_go * 1024 * 1024 * 1024
  format         = "qcow2"
}

resource "libvirt_cloudinit_disk" "init" {
  name = "${var.nom}-cloudinit.iso"
  pool = var.pool_stockage

  user_data = templatefile("${path.module}/templates/user-data.yaml.tftpl", {
    nom               = var.nom
    description       = var.description
    domaine_dns       = var.domaine_dns
    ip                = var.ip
    admin_utilisateur = var.admin_utilisateur
    cle_ssh_publique  = var.cle_ssh_publique
    fuseau_horaire    = var.fuseau_horaire
    serveurs_ntp      = var.serveurs_ntp
  })

  network_config = templatefile("${path.module}/templates/network-config.yaml.tftpl", {
    mac         = var.mac
    ip          = var.ip
    masque      = var.masque
    passerelle  = var.passerelle
    dns         = var.dns
    domaine_dns = var.domaine_dns
  })
}

resource "libvirt_domain" "vm" {
  name        = var.nom
  description = var.description
  vcpu        = var.vcpu
  memory      = var.memoire_mo
  autostart   = var.demarrage_automatique
  qemu_agent  = true

  cloudinit = libvirt_cloudinit_disk.init.id

  cpu {
    mode = "host-passthrough"
  }

  disk {
    volume_id = libvirt_volume.disque.id
  }

  network_interface {
    network_id = var.reseau_id
    mac        = var.mac
    # L'adresse vient de cloud-init : aucun bail DHCP a attendre.
    wait_for_lease = false
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }
}
