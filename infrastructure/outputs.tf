# Sorties de recette : ce qui sert de preuve pour les cas TI-01 et TI-05.

output "plan_vlan" {
  description = "Plan VLAN tel que reellement cree sur l'hote."
  value       = module.reseau.recapitulatif
}

output "serveurs" {
  description = "Serveurs deployes, avec leur adresse et leur commande de connexion."
  value = merge(
    {
      for nom, s in module.serveur : nom => {
        # Le repli sur Ubuntu quand image_debian n'est pas fournie doit se lire
        # ici aussi, sinon la sortie annoncerait un systeme qui n'est pas installe.
        systeme = (
          local.serveurs_linux[nom].os == "debian" && trimspace(var.image_debian) != ""
          ? "Debian 12"
          : "Ubuntu 22.04"
        )
        adresse = s.ip
        mac     = s.mac
        acces   = s.acces_ssh
      }
    },
    {
      for nom, s in module.serveur_windows : nom => {
        systeme = "Windows Server"
        adresse = s.ip
        mac     = s.mac
        acces   = s.acces_ssh
      }
    }
  )
}

output "machines_windows" {
  description = "Etat des machines Windows. Non deploye signifie que le gabarit syspreppe n'a pas ete fourni."
  value = trimspace(var.image_windows) != "" ? {
    for nom, s in module.serveur_windows : nom => format("deploye, administration sur %s", s.ip)
    } : {
    for nom, s in local.serveurs : nom => "non deploye : gabarit Windows absent" if s.os == "windows"
  }
}

output "parefeux" {
  description = "Etat des deux pare-feux. Non deploye signifie que l'image du constructeur n'a pas ete fournie."
  value = {
    for nom, f in module.parefeu : nom => (
      f.deploye
      ? format("deploye, %d interfaces, administration sur %s", f.interfaces, f.ip_admin)
      : "non deploye : image constructeur absente"
    )
  }
}

output "dimensionnement" {
  description = "Totaux du laboratoire, rapportes aux capacites de l'hote."
  value = {
    vcpu_total     = local.total_vcpu
    memoire_totale = format("%d Go", local.total_mo / 1024)
    disque_total   = format("%d Go declares, alloues a la demande", local.total_go)

    # Hote du laboratoire : i7-14700, 28 fils d'execution, 31 Gio utilisables.
    # Un constat plutot qu'un seuil fige, qui deviendrait faux au premier
    # changement de dimensionnement sans que personne ne le remarque.

    # Le temps processeur se partage : une machine au repos ne consomme rien,
    # et le surengagement est la norme.
    processeur = format(
      "%d vCPU declares sur 28 fils, %s",
      local.total_vcpu,
      local.total_vcpu > 28 ? "surengagement assume" : "sans surengagement"
    )

    # La memoire ne se partage pas. KVM l'alloue a la demande, mais si toutes
    # les machines saturaient la leur en meme temps, l'hote serait a court :
    # il faudrait alors les demarrer par vagues.
    memoire = format(
      "%d Go declares sur 31 Gio, marge theorique %d Go",
      local.total_mo / 1024,
      (31 * 1024 - local.total_mo) / 1024
    )
  }
}

output "etapes_suivantes" {
  description = "Ce qu'il reste a faire apres le apply."
  value = [
    "1. Verifier que les machines repondent : make etat",
    "2. Se connecter a un serveur : ${try(values(module.serveur)[0].acces_ssh, "ssh adminlab@10.10.10.30")}",
    "3. Preparer le gabarit Windows si ce n'est pas fait, puis renseigner image_windows",
    "4. Terminer l'installation de Centreon et de Jitsi (etapes decrites dans le README)",
    "5. Configurer les deux pare-feux, puis exporter leur configuration dans le depot Git",
    "6. Repasser acces_internet_construction a false une fois les paquets installes",
  ]
}

output "publication" {
  description = "Interfaces web publiees sur l'hote par le relais nginx."
  value = {
    for port, p in local.publications : port => {
      service     = p.service
      destination = format("%s:%d", local.adresses_publiables[p.cible], p.port)
      protocole   = p.port == 80 ? "http" : "https"
    }
  }
}
