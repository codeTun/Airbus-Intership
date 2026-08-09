###############################################################################
#  Module parefeu
#
#  Cree une machine a partir d'une image constructeur (FortiOS ou PAN-OS).
#  Ces images embarquent leur propre systeme : pas de cloud-init, pas de
#  compte a provisionner. La configuration se fait ensuite dans l'interface
#  de l'editeur, puis est exportee et versionnee (exigence INF-08).
#
#  Le pare-feu n'est cree que si son image est fournie. Cela permet de
#  deployer les serveurs seuls sur une machine qui ne peut pas executer ces
#  images, sans commenter du code.
###############################################################################

terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8.0"
    }
  }
}

locals {
  actif = trimspace(var.image) != ""
}

resource "libvirt_volume" "disque" {
  count = local.actif ? 1 : 0

  name   = "${var.nom}.qcow2"
  pool   = var.pool_stockage
  source = var.image
  format = "qcow2"
}

resource "libvirt_domain" "vm" {
  count = local.actif ? 1 : 0

  name        = var.nom
  description = var.description
  vcpu        = var.vcpu
  memory      = var.memoire_mo
  autostart   = var.demarrage_automatique

  # Les images constructeur n'embarquent pas d'agent invite.
  qemu_agent = false

  cpu {
    mode = "host-passthrough"
  }

  disk {
    volume_id = libvirt_volume.disque[0].id
  }

  # Une interface par reseau raccorde, dans l'ordre declare : la premiere
  # correspond a port1 sur FortiOS et a ethernet1/1 sur PAN-OS.
  dynamic "network_interface" {
    for_each = var.reseaux_ids
    content {
      network_id     = network_interface.value
      wait_for_lease = false
    }
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  # La premiere mise en service passe par la console graphique du
  # constructeur, avant que l'interface web ne soit joignable.
  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }
}
