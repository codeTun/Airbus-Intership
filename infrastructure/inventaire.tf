# Source de verite unique : plan VLAN, adressage et machines, repris des
# tableaux 6, 7 et 8 du cahier des charges. Les modules ne font que consommer
# ces valeurs, toute modification se fait ici.

locals {

  # reseau = null : VLAN sans adressage, isole. C'est le VLAN natif des trunks.
  vlans = {
    mgmt = {
      id         = 10
      nom        = "MGMT"
      reseau     = "10.10.10.0/24"
      passerelle = "10.10.10.1"
      dhcp       = false
      usage      = "Administration et supervision"
    }
    servers = {
      id         = 20
      nom        = "SERVERS"
      reseau     = "10.10.20.0/24"
      passerelle = "10.10.20.1"
      dhcp       = false
      usage      = "Serveurs metiers"
    }
    equip = {
      id         = 30
      nom        = "EQUIP"
      reseau     = "10.10.30.0/24"
      passerelle = "10.10.30.1"
      dhcp       = true
      usage      = "Imprimantes, pointeuses, bancs d'essais"
    }
    storage = {
      id         = 40
      nom        = "STORAGE"
      reseau     = "10.10.40.0/24"
      passerelle = "10.10.40.1"
      dhcp       = false
      usage      = "Flux de stockage IP"
    }
    users = {
      id         = 50
      nom        = "USERS"
      reseau     = "10.10.50.0/24"
      passerelle = "10.10.50.1"
      dhcp       = true
      usage      = "Postes de travail"
    }
    quarantine = {
      id         = 99
      nom        = "QUARANTINE"
      reseau     = "10.10.99.0/24"
      passerelle = "10.10.99.1"
      dhcp       = true
      usage      = "Equipements non authentifies"
    }
    natif = {
      id         = 999
      nom        = "NATIVE-UNUSED"
      reseau     = null
      passerelle = null
      dhcp       = false
      usage      = "VLAN natif des liens trunk, volontairement inutilise"
    }
  }

  # Seuls ces VLAN sortent vers Internet, et seulement pendant l'installation.
  vlans_avec_sortie = ["mgmt", "servers"]

  # Le champ "groupe" indique a Ansible quel role appliquer.
  # Le champ "os" choisit le gabarit et le mode de connexion : "ubuntu" passe
  # par cloud-init et SSH, "windows" par cloudbase-init et SSH en PowerShell.
  serveurs = {
    # Dimensionne pour un hote de 32 Go : Windows Server, IIS et SQL Express
    # tournent a l'aise avec 4 Go. Xerox Workplace Suite recommande 4 vCPU,
    # 8 Go et 160 Go de disque : a remettre le jour ou la licence est obtenue.
    "srv-print-01" = {
      description = "Serveur d'impression Follow-You"
      os          = "windows"
      vcpu        = 2
      memoire_mo  = 4096
      disque_go   = 60
      vlan        = "servers"
      ip          = "10.10.20.11"
      groupe      = "impression"
    }

    "srv-visio-01" = {
      description = "Serveur de visioconference"
      os          = "ubuntu"
      vcpu        = 2
      memoire_mo  = 4096
      disque_go   = 25
      vlan        = "servers"
      ip          = "10.10.20.12"
      groupe      = "visioconference"
    }

    # Nom raccourci : NetBIOS plafonne le nom d'hote Windows a 15 caracteres,
    # et "srv-pointeuse-01" en fait 16.
    # MorphoManager demande un dual core et 4 Go : ce dimensionnement les
    # respecte deja, seul le disque sera a agrandir avec la base biometrique.
    "srv-point-01" = {
      description = "Gestion des pointeuses biometriques"
      os          = "windows"
      vcpu        = 2
      memoire_mo  = 4096
      disque_go   = 50
      vlan        = "servers"
      ip          = "10.10.20.13"
      groupe      = "pointeuses"
    }

    # Centreon publie 4 vCPU et 8 Go pour une production. Le laboratoire ne
    # supervise que six machines : la moitie suffit largement.
    "sup-centreon-01" = {
      description = "Supervision Centreon"
      os          = "ubuntu"
      vcpu        = 2
      memoire_mo  = 4096
      disque_go   = 40
      vlan        = "mgmt"
      ip          = "10.10.10.30"
      groupe      = "supervision"
    }
  }

  # Images constructeur, sans cloud-init. Un pare-feu n'est cree que si son
  # image est fournie.
  parefeux = {
    "fw-forti-01" = {
      description = "Pare-feu peripherique"
      vcpu        = 1
      memoire_mo  = 2048
      disque_go   = 40
      image       = var.image_fortios
      ip_admin    = "10.10.10.254"
      groupe      = "fortinet"
      # La licence d'evaluation plafonne a 3 interfaces.
      reseaux = ["mgmt", "servers"]
    }

    "fw-palo-01" = {
      description = "Pare-feu interne, routage inter-VLAN"
      vcpu        = 2
      memoire_mo  = 8192
      disque_go   = 60
      image       = var.image_panos
      ip_admin    = "10.10.10.253"
      groupe      = "paloalto"
      # Une sous-interface de niveau 3 par VLAN adresse.
      reseaux = ["mgmt", "servers", "equip", "storage", "users", "quarantine"]
    }
  }

  # Les deux familles ne se deploient pas de la meme facon : gabarit different,
  # amorcage different, connexion Ansible differente.
  serveurs_ubuntu = { for nom, s in local.serveurs : nom => s if s.os == "ubuntu" }

  # Tant que le gabarit Windows n'est pas prepare, ces machines sont ignorees
  # et le reste du laboratoire se deploie normalement.
  serveurs_windows = trimspace(var.image_windows) != "" ? {
    for nom, s in local.serveurs : nom => s if s.os == "windows"
  } : {}

  # Adresse MAC deterministe, construite depuis le VLAN et le dernier octet de
  # l'IP : lisible, et stable d'un apply a l'autre.
  mac_serveurs = {
    for nom, s in local.serveurs :
    nom => format("52:54:00:00:%02x:%02x",
      local.vlans[s.vlan].id,
      tonumber(element(split(".", s.ip), 3))
    )
  }

  # Adresse du serveur de supervision, ou les autres machines envoient leurs journaux.
  ip_supervision = one([for nom, s in local.serveurs : s.ip if s.groupe == "supervision"])

  # Groupes de l'inventaire Ansible.
  groupes_serveurs = {
    for groupe in distinct([for s in local.serveurs : s.groupe]) :
    groupe => {
      hosts = {
        for nom, s in local.serveurs : nom => { ansible_host = s.ip }
        if s.groupe == groupe
      }
    }
  }

  # Groupes par systeme. Ils ne portent aucun role : seulement la facon de se
  # connecter. Chaque machine appartient donc a deux groupes, celui de son role
  # et celui de son systeme.
  groupes_os = merge(
    length(local.serveurs_ubuntu) > 0 ? {
      linux = {
        hosts = { for nom, s in local.serveurs_ubuntu : nom => { ansible_host = s.ip } }
        vars = {
          ansible_python_interpreter = "/usr/bin/python3"
          ansible_become             = true
        }
      }
    } : {},
    length(local.serveurs_windows) > 0 ? {
      windows = {
        hosts = { for nom, s in local.serveurs_windows : nom => { ansible_host = s.ip } }
        vars = {
          # OpenSSH est present nativement depuis Windows Server 2019. Sans
          # shell_type, Ansible enverrait du bash et echouerait en silence.
          ansible_shell_type = "powershell"
          ansible_become     = false
        }
      }
    } : {}
  )

  # Un pare-feu n'entre dans l'inventaire que si son image a ete fournie.
  groupes_parefeux = {
    for groupe in distinct([for f in local.parefeux : f.groupe if trimspace(f.image) != ""]) :
    groupe => {
      hosts = {
        for nom, f in local.parefeux : nom => { ansible_host = f.ip_admin }
        if f.groupe == groupe && trimspace(f.image) != ""
      }
    }
  }

  # Totaux, compares au cahier des charges dans les sorties.
  total_vcpu = sum([for s in local.serveurs : s.vcpu]) + sum([for f in local.parefeux : f.vcpu])
  total_mo   = sum([for s in local.serveurs : s.memoire_mo]) + sum([for f in local.parefeux : f.memoire_mo])
  total_go   = sum([for s in local.serveurs : s.disque_go]) + sum([for f in local.parefeux : f.disque_go])
}
