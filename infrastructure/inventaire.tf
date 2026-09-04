# Source de verite du laboratoire : plan VLAN, adressage, machines.
# Les modules consomment ces valeurs, toute modification se fait ici.

locals {

  # reseau = null : VLAN declare sans adressage. C'est le natif des trunks.
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

  # Sortie Internet temporaire, le temps d'installer les paquets.
  vlans_avec_sortie = ["mgmt", "servers"]

  # os : "ubuntu" et "debian" passent par cloud-init, "windows" par
  # cloudbase-init. "debian" n'existe que pour la supervision.
  serveurs = {
    # Xerox Workplace Suite recommande 4 vCPU et 8 Go. Reduit a 4 Go tant que
    # la licence n'est pas obtenue et que seule la plateforme est installee.
    "srv-print-01" = {
      description = "Serveur d'impression Follow-You"
      os          = "windows"
      vcpu        = 4
      memoire_mo  = 4096
      disque_go   = 60
      vlan        = "servers"
      ip          = "10.10.20.11"
      groupe      = "impression"
      # Aucune interface supplementaire.
      reseaux_secondaires = []
    }

    # Jitsi Meet en conteneurs. L'editeur annonce 4 vCPU et 8 Go pour une
    # vingtaine de participants, et environ 1 vCPU par tranche de 10 flux video.
    "srv-visio-01" = {
      description = "Serveur de visioconference"
      os          = "ubuntu"
      vcpu        = 6
      memoire_mo  = 8192
      disque_go   = 40
      vlan        = "servers"
      ip          = "10.10.20.12"
      groupe      = "visioconference"
      # Aucune interface supplementaire.
      reseaux_secondaires = []
    }

    # Nom raccourci : NetBIOS plafonne a 15 caracteres, "srv-pointeuse-01" en
    # fait 16 et Windows tronquerait en silence.
    "srv-point-01" = {
      description = "Gestion des pointeuses biometriques"
      os          = "windows"
      vcpu        = 4
      memoire_mo  = 4096
      disque_go   = 50
      vlan        = "servers"
      ip          = "10.10.20.13"
      groupe      = "pointeuses"
      # Aucune interface supplementaire.
      reseaux_secondaires = []
    }

    # Centreon publie 4 vCPU et 8 Go pour une production. Six machines
    # supervisees en demandent moitie moins. Seule machine sous Debian :
    # Centreon ne publie aucun depot pour Ubuntu.
    "sup-centreon-01" = {
      description = "Supervision Centreon"
      os          = "debian"
      vcpu        = 4
      memoire_mo  = 4096
      disque_go   = 40
      vlan        = "mgmt"
      ip          = "10.10.10.30"
      groupe      = "supervision"
      # Le pare-feu interne ne retransmet rien faute de licence, et aucun routage
      # inter-VLAN n'existe donc. La station de supervision est raccordee au VLAN
      # des serveurs pour les observer directement, pratique courante pour une
      # station d'observation. A retirer le jour ou le routage sera effectif.
      reseaux_secondaires = [
        { vlan = "servers", ip = "10.10.20.30" },
      ]
    }
  }

  # Images constructeur, sans cloud-init.
  parefeux = {
    "fw-forti-01" = {
      description = "Pare-feu peripherique"
      # La licence d'evaluation permanente de FortiFirewall-VM plafonne a 1 vCPU
      # et 2048 Mo. Au-dela, FortiOS demarre mais annonce "License invalid" et
      # restreint ses fonctions. Ne pas augmenter sans licence payante.
      vcpu       = 1
      memoire_mo = 2048
      disque_go  = 40
      image      = var.image_fortios
      ip_admin   = "10.10.10.254"
      groupe     = "fortinet"
      # La licence d'evaluation plafonne a 3 interfaces.
      reseaux = ["mgmt", "servers"]
    }

    "fw-palo-01" = {
      description = "Pare-feu interne, routage inter-VLAN"
      vcpu        = 4
      memoire_mo  = 8192
      disque_go   = 60
      image       = var.image_panos
      ip_admin    = "10.10.10.253"
      groupe      = "paloalto"
      # Une sous-interface de niveau 3 par VLAN adresse.
      reseaux = ["mgmt", "servers", "equip", "storage", "users", "quarantine"]
    }
  }

  serveurs_ubuntu = { for nom, s in local.serveurs : nom => s if s.os == "ubuntu" }
  serveurs_debian = { for nom, s in local.serveurs : nom => s if s.os == "debian" }

  # Meme module, meme cloud-init : seule l'image de base differe. Sans
  # image_debian renseignee, ces machines retombent sur la base Ubuntu.
  serveurs_linux = merge(local.serveurs_ubuntu, local.serveurs_debian)

  # Sans gabarit Windows, ces machines sont ignorees et le reste se deploie.
  serveurs_windows = trimspace(var.image_windows) != "" ? {
    for nom, s in local.serveurs : nom => s if s.os == "windows"
  } : {}

  # MAC deterministe : VLAN et dernier octet de l'IP. Stable d'un apply a l'autre.
  mac_serveurs = {
    for nom, s in local.serveurs :
    nom => format("52:54:00:00:%02x:%02x",
      local.vlans[s.vlan].id,
      tonumber(element(split(".", s.ip), 3))
    )
  }

  # Meme regle que pour les interfaces principales : VLAN et dernier octet.
  reseaux_secondaires = {
    for nom, s in local.serveurs : nom => [
      for r in s.reseaux_secondaires : {
        vlan   = r.vlan
        ip     = r.ip
        masque = 24
        mac = format("52:54:00:00:%02x:%02x",
          local.vlans[r.vlan].id,
          tonumber(element(split(".", r.ip), 3))
        )
      }
    ]
  }

  ip_supervision = one([for nom, s in local.serveurs : s.ip if s.groupe == "supervision"])

  # Seules les machines reellement creees entrent dans l'inventaire. Sans ce
  # filtre, Ansible tenterait de joindre les machines Windows non deployees.
  serveurs_deployes = merge(local.serveurs_linux, local.serveurs_windows)

  groupes_serveurs = {
    for groupe in distinct([for s in local.serveurs_deployes : s.groupe]) :
    groupe => {
      hosts = {
        for nom, s in local.serveurs_deployes : nom => { ansible_host = s.ip }
        if s.groupe == groupe
      }
    }
  }

  # Groupes de systeme : ils portent le mode de connexion, pas les roles.
  # Chaque machine appartient a son groupe de role et a celui-ci.
  groupes_os = merge(
    length(local.serveurs_linux) > 0 ? {
      linux = {
        hosts = { for nom, s in local.serveurs_linux : nom => {
          ansible_host = s.ip
          # Adressees par le role commun, cloud-init ne s'executant qu'une fois.
          # La liste est vide pour la plupart des machines.
          interfaces_secondaires = local.reseaux_secondaires[nom]
        } }
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
          # Sans shell_type, Ansible enverrait du bash et echouerait en silence.
          # C'est aussi lui qui fait preferer les modules .ps1 et qui active le
          # pipelining force du plugin ssh, lequel evite un pseudo-terminal dont
          # les fins de ligne corrompraient le JSON rendu par PowerShell.
          ansible_shell_type = "powershell"
          # Valeur par defaut en 2.16, declaree pour rester juste si un jour
          # ansible.cfg ou l'environnement imposait un autre transport.
          ansible_connection = "ssh"
          # Si become devait un jour passer a true ici, il faudrait imperativement
          # ansible_become_method = "runas" : le sudo global ne s'applique pas.
          ansible_become = false
        }
      }
    } : {}
  )

  # Un pare-feu n'entre dans l'inventaire que si son image est fournie.
  groupes_parefeux = {
    for groupe in distinct([for f in local.parefeux : f.groupe if trimspace(f.image) != ""]) :
    groupe => {
      hosts = {
        for nom, f in local.parefeux : nom => { ansible_host = f.ip_admin }
        if f.groupe == groupe && trimspace(f.image) != ""
      }
    }
  }

  # Interfaces web publiees sur l'hote. nginx relaie en TCP brut, sans dechiffrer :
  # le certificat presente au navigateur reste celui du service, et aucun secret ne
  # transite en clair par l'hote. Un seul point d'entree, donc une seule surface a
  # defendre, au lieu d'un tunnel SSH a ouvrir avant chaque visite.
  #
  # Ports au-dessus de 8000 : le 80 sert deja la page par defaut de l'hote, et un
  # port non privilegie evite d'elargir les droits du relais.
  publications = {
    "8080" = { cible = "sup-centreon-01", port = 80, service = "Centreon" }
    "8081" = { cible = "srv-print-01", port = 443, service = "Console d'impression" }
    "8443" = { cible = "fw-forti-01", port = 443, service = "FortiGate" }
    "8444" = { cible = "fw-palo-01", port = 443, service = "Palo Alto, substitut FortiOS" }
    "8445" = { cible = "srv-visio-01", port = 443, service = "Jitsi Meet" }
  }

  # Une cible est un serveur ou un pare-feu : l'adresse se lit dans l'un ou l'autre
  # inventaire, jamais recopiee a la main dans la configuration du relais.
  adresses_publiables = merge(
    { for nom, s in local.serveurs : nom => s.ip },
    { for nom, f in local.parefeux : nom => f.ip_admin },
  )

  total_vcpu = sum([for s in local.serveurs : s.vcpu]) + sum([for f in local.parefeux : f.vcpu])
  total_mo   = sum([for s in local.serveurs : s.memoire_mo]) + sum([for f in local.parefeux : f.memoire_mo])
  total_go   = sum([for s in local.serveurs : s.disque_go]) + sum([for f in local.parefeux : f.disque_go])
}
