# Machine a partir d'une image constructeur (FortiOS ou PAN-OS). Ces images
# embarquent leur propre systeme, donc pas de cloud-init.
# Sans image fournie, rien n'est cree : les serveurs se deploient quand meme.

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

  # Pas d'agent invite dans ces images.
  qemu_agent = false

  cpu {
    mode = "host-passthrough"
  }

  disk {
    volume_id = libvirt_volume.disque[0].id
  }

  # Une interface par reseau, dans l'ordre declare : la premiere est port1
  # sur FortiOS, ethernet1/1 sur PAN-OS.
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

  # La premiere mise en service passe par la console, avant que l'interface
  # web ne reponde.
  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }
}
