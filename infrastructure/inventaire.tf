###############################################################################
#  Inventaire du laboratoire : source de verite unique
#
#  Ce fichier reprend mot pour mot les tableaux du cahier des charges :
#    - plan VLAN                    (tableau 6)
#    - adressage des machines       (tableau 7)
#    - machines virtuelles          (tableau 8)
#
#  Toute modification de dimensionnement ou d'adressage se fait ici, et
#  nulle part ailleurs. Les modules ne font que consommer ces valeurs.
###############################################################################

locals {

  # --------------------------------------------------------------- plan VLAN
  # dhcp = true  : le VLAN accueille des equipements qui n'ont pas d'adresse fixe
  # reseau = null : VLAN sans adressage, isole (VLAN natif des liens trunk)
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

  # VLAN autorises a sortir vers Internet pendant l'installation des paquets.
  vlans_avec_sortie = ["mgmt", "servers"]

  # ------------------------------------------------- serveurs de la partie 1
  # Les paquets et commandes sont propres au role : le durcissement commun
  # (compte nominatif, SSH par cle, pare-feu local, mises a jour, NTP, swap)
  # est applique a tous par le module serveur.
  serveurs = {
    "srv-print-01" = {
      description = "Serveur d'impression"
      vcpu        = 1
      memoire_mo  = 2048
      disque_go   = 25
      vlan        = "servers"
      ip          = "10.10.20.11"
      ports       = [631]
      paquets     = ["cups", "cups-filters", "printer-driver-all", "samba"]
      commandes = [
        "install -d -m 0755 /etc/cups",
        "systemctl enable --now cups",
      ]
    }

    "srv-visio-01" = {
      description = "Serveur de visioconference"
      vcpu        = 2
      memoire_mo  = 4096
      disque_go   = 25
      vlan        = "servers"
      ip          = "10.10.20.12"
      ports       = [443, 10000]
      # Jitsi Meet demande un nom de domaine et un certificat TLS : le depot
      # et les dependances sont poses ici, la fin de l'installation est
      # documentee dans le README (etape manuelle assumee).
      paquets = ["nginx-full", "openjdk-11-jre-headless", "gnupg2", "apt-transport-https"]
      commandes = [
        "curl -fsSL https://download.jitsi.org/jitsi-key.gpg.key | gpg --dearmor -o /usr/share/keyrings/jitsi-keyring.gpg",
        "echo 'deb [signed-by=/usr/share/keyrings/jitsi-keyring.gpg] https://download.jitsi.org stable/' > /etc/apt/sources.list.d/jitsi-stable.list",
        "apt-get update",
      ]
    }

    "srv-pointeuse-01" = {
      description = "Collecte et gestion des pointeuses"
      vcpu        = 1
      memoire_mo  = 2048
      disque_go   = 30
      vlan        = "servers"
      ip          = "10.10.20.13"
      ports       = [5432]
      paquets     = ["postgresql", "postgresql-contrib", "python3-psycopg2"]
      commandes = [
        "systemctl enable --now postgresql",
        # L'heure fausse directement les pointages : on rend la derive visible.
        "chronyc tracking > /var/log/chrony-etat-initial.log || true",
      ]
    }

    "sup-centreon-01" = {
      description = "Supervision Centreon"
      vcpu        = 4
      memoire_mo  = 8192
      disque_go   = 60
      vlan        = "mgmt"
      ip          = "10.10.10.30"
      ports       = [80, 443]
      # Centreon ne prend officiellement en charge que Debian et la famille
      # RHEL. Les dependances communes sont installees ici, la suite est
      # decrite dans le README avec la solution de repli sous Debian 12.
      paquets = ["apache2", "mariadb-server", "php", "php-mysql", "snmp", "snmpd"]
      commandes = [
        "systemctl enable --now mariadb apache2",
      ]
    }
  }

  # ------------------------------------------------ pare-feux de la partie 1
  # Images constructeur, sans cloud-init : la configuration se fait ensuite
  # dans l'interface de l'editeur, puis est exportee et versionnee.
  # Chaque pare-feu n'est cree que si son image est fournie.
  parefeux = {
    "fw-forti-01" = {
      description = "Pare-feu peripherique"
      vcpu        = 1
      memoire_mo  = 2048
      disque_go   = 40
      image       = var.image_fortios
      ip_admin    = "10.10.10.254"
      # Licence d'evaluation permanente : 3 interfaces au maximum.
      reseaux = ["mgmt", "servers"]
    }

    "fw-palo-01" = {
      description = "Pare-feu interne, routage inter-VLAN"
      vcpu        = 2
      memoire_mo  = 8192
      disque_go   = 60
      image       = var.image_panos
      ip_admin    = "10.10.10.253"
      # Une sous-interface de niveau 3 par VLAN : tous les VLAN adresses.
      reseaux = ["mgmt", "servers", "equip", "storage", "users", "quarantine"]
    }
  }

  # ------------------------------------------------------------- derivations
  # Adresse MAC deterministe, dans la plage QEMU 52:54:00.
  # Construite a partir de l'identifiant de VLAN et du dernier octet de l'IP,
  # ce qui la rend lisible et stable d'un apply a l'autre.
  mac_serveurs = {
    for nom, s in local.serveurs :
    nom => format("52:54:00:00:%02x:%02x",
      local.vlans[s.vlan].id,
      tonumber(element(split(".", s.ip), 3))
    )
  }

  # Totaux, repris dans les sorties pour verifier le dimensionnement annonce.
  total_vcpu = sum([for s in local.serveurs : s.vcpu]) + sum([for f in local.parefeux : f.vcpu])
  total_mo   = sum([for s in local.serveurs : s.memoire_mo]) + sum([for f in local.parefeux : f.memoire_mo])
  total_go   = sum([for s in local.serveurs : s.disque_go]) + sum([for f in local.parefeux : f.disque_go])
}
