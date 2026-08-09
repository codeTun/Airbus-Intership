# Ce que l'on veut voir apres un apply, et ce qui sert de preuve pour la
# recette (cas TI-01 et TI-05).

output "plan_vlan" {
  description = "Plan VLAN tel que reellement cree sur l'hote."
  value       = module.reseau.recapitulatif
}

output "serveurs" {
  description = "Serveurs deployes, avec leur adresse et leur commande de connexion."
  value = {
    for nom, s in module.serveur : nom => {
      adresse = s.ip
      mac     = s.mac
      acces   = s.acces_ssh
    }
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
  description = "Totaux compares au tableau 8 du cahier des charges."
  value = {
    vcpu_total     = local.total_vcpu
    memoire_totale = format("%d Go", local.total_mo / 1024)
    disque_total   = format("%d Go declares, alloues a la demande", local.total_go)
    attendu        = "11 vCPU, 26 Go, 240 Go"
    conforme       = local.total_vcpu == 11 && local.total_mo == 26624 && local.total_go == 240
  }
}

output "etapes_suivantes" {
  description = "Ce qu'il reste a faire apres le apply."
  value = [
    "1. Verifier que les machines repondent : make etat",
    "2. Se connecter a un serveur : ${try(values(module.serveur)[0].acces_ssh, "ssh adminlab@10.10.10.30")}",
    "3. Terminer l'installation de Centreon et de Jitsi (etapes decrites dans le README)",
    "4. Configurer les deux pare-feux, puis exporter leur configuration dans le depot Git",
    "5. Repasser acces_internet_construction a false une fois les paquets installes",
  ]
}
