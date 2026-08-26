# Machine Windows amorcee par cloudbase-init, qui lit le meme disque NoCloud
# que cloud-init. Le gabarit se prepare une fois a la main, voir le README.

terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8.0"
    }
  }
}

locals {
  # Les listes Terraform ne sont pas des tableaux PowerShell.
  dns_powershell = join(",", formatlist("\"%s\"", var.dns))
}

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

  user_data = templatefile("${path.module}/templates/user-data.ps1.tftpl", {
    nom                    = var.nom
    mac                    = var.mac
    ip                     = var.ip
    masque                 = var.masque
    passerelle             = var.passerelle
    dns_powershell         = local.dns_powershell
    admin_utilisateur      = var.admin_utilisateur
    admin_mot_de_passe     = var.admin_mot_de_passe
    cle_ssh_publique       = var.cle_ssh_publique
    fuseau_horaire_windows = var.fuseau_horaire_windows
  })
}

resource "libvirt_domain" "vm" {
  name        = var.nom
  description = var.description
  vcpu        = var.vcpu
  memory      = var.memoire_mo
  autostart   = var.demarrage_automatique

  # Fourni par les invites virtio de la preparation du gabarit.
  qemu_agent = true

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
    # L'adresse est posee par le script d'amorcage, pas par DHCP.
    wait_for_lease = false
  }

  # Seul acces de secours si le reseau ne monte pas : Windows n'expose pas de
  # console serie exploitable.
  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }
}
