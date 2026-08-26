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
        systeme = "Ubuntu 22.04"
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
  description = "Totaux du laboratoire, compares au dimensionnement retenu."
  value = {
    vcpu_total     = local.total_vcpu
    memoire_totale = format("%d Go", local.total_mo / 1024)
    disque_total   = format("%d Go declares, alloues a la demande", local.total_go)
    attendu        = "11 vCPU, 26 Go, 275 Go"
    conforme       = local.total_vcpu == 11 && local.total_mo == 26624 && local.total_go == 275

    # L'hote garde environ 2 Go pour lui : on se donne 30 Go de plafond.
    tient_sur_hote_32go = local.total_mo <= 30720
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
