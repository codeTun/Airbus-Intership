#!/usr/bin/env bash
# Recette de la couche infrastructure : confronte ce que libvirt expose a ce que
# Terraform declare. Lecture seule, rejouable, sans effet sur le laboratoire.
#
#   ./recette.sh            recette complete
#   ./recette.sh --rapide   sans le controle de derive, qui prend une minute

set -uo pipefail

VIRSH="${VIRSH:-sudo virsh}"
CLE="${CLE_SSH:-$HOME/.ssh/id_ed25519_labo}"
RAPIDE=0
[[ "${1:-}" == "--rapide" ]] && RAPIDE=1

vert=$'\033[32m'; rouge=$'\033[31m'; jaune=$'\033[33m'; gras=$'\033[1m'; net=$'\033[0m'
ok=0; ko=0

resultat() {
  if [[ "$1" == "ok" ]]; then
    printf '  %s[ OK ]%s %s\n' "$vert" "$net" "$2"; ok=$((ok + 1))
  else
    printf '  %s[ KO ]%s %s\n' "$rouge" "$net" "$2"; ko=$((ko + 1))
  fi
}

titre() { printf '\n%s%s%s\n' "$gras" "$1" "$net"; }

cd "$(dirname "$0")" || exit 1

command -v terraform >/dev/null || { echo "terraform absent"; exit 1; }
SORTIES=$(terraform output -json 2>/dev/null) || { echo "Aucune sortie Terraform : lancer d'abord un apply."; exit 1; }

printf '%s================================================================%s\n' "$gras" "$net"
printf '%s Recette de la couche infrastructure                            %s\n' "$gras" "$net"
printf '%s================================================================%s\n' "$gras" "$net"

# ---------------------------------------------------------------- code source
titre "1. Code d'infrastructure"

terraform validate >/dev/null 2>&1 \
  && resultat ok "la configuration est syntaxiquement valide" \
  || resultat ko "terraform validate echoue"

if [[ $RAPIDE -eq 0 ]]; then
  terraform plan -detailed-exitcode -lock=false >/dev/null 2>&1
  case $? in
    0) resultat ok "aucune derive : le reel correspond au code" ;;
    2) resultat ko "derive detectee : lancer terraform plan pour la voir" ;;
    *) resultat ko "terraform plan a echoue" ;;
  esac
else
  printf '  %s[ -- ]%s controle de derive ignore (--rapide)\n' "$jaune" "$net"
fi

# -------------------------------------------------------------------- reseaux
titre "2. Reseaux VLAN"

VLANS=$(printf '%s' "$SORTIES" | python3 -c '
import json,sys
d=json.load(sys.stdin)["plan_vlan"]["value"]
for cle,v in sorted(d.items(), key=lambda x: x[1]["vlan"]):
    print("|".join([str(v["vlan"]), v["nom"], v["nom"].lower(), v["reseau"]]))
')

actifs=$($VIRSH net-list --name 2>/dev/null)
declares=$($VIRSH net-list --all --name 2>/dev/null)

# Le module nomme ses reseaux <prefixe>-vlan<id>-<nom en minuscules>, pas d'apres
# la cle du plan : NATIVE-UNUSED donne lab-vlan999-native-unused. Le motif ignore
# le prefixe, qui est configurable.
while IFS='|' read -r id nom suffixe reseau; do
  [[ -z "$id" ]] && continue
  motif="-vlan${id}-${suffixe}"
  if ! grep -q -- "${motif}$" <<<"$declares"; then
    resultat ko "VLAN ${id} ${nom} non declare"
  elif grep -q -- "${motif}$" <<<"$actifs"; then
    resultat ok "VLAN ${id} ${nom} actif (${reseau})"
  elif [[ "$reseau" == "sans adressage" ]]; then
    # Le VLAN natif d'un lien trunk n'a pas d'adressage : libvirt le declare
    # sans le demarrer, et c'est l'etat attendu.
    resultat ok "VLAN ${id} ${nom} declare sans adressage, inactif comme prevu"
  else
    resultat ko "VLAN ${id} ${nom} declare mais inactif"
  fi
done <<<"$VLANS"

# ------------------------------------------------------------------- machines
titre "3. Machines"

MACHINES=$(printf '%s' "$SORTIES" | python3 -c '
import json,sys
d=json.load(sys.stdin)
for nom,v in sorted(d["serveurs"]["value"].items()):
    print(nom, v["adresse"], v["mac"], v["systeme"].replace(" ","_"))
for nom,v in sorted(d.get("parefeux",{}).get("value",{}).items()):
    if v.startswith("deploye"):
        ip=v.split("sur ")[-1]
        print(nom, ip, "-", "image_constructeur")
')

vcpu_total=0; memoire_total=0

while read -r nom ip mac systeme; do
  [[ -z "$nom" ]] && continue

  etat=$($VIRSH domstate "$nom" 2>/dev/null)
  if [[ "$etat" == "running" ]]; then
    resultat ok "$nom en fonctionnement"
  else
    resultat ko "$nom : etat ${etat:-inconnu}"
    continue
  fi

  v=$($VIRSH dominfo "$nom" 2>/dev/null | awk -F: '/CPU\(s\)/ {gsub(/ /,"",$2); print $2}')
  m=$($VIRSH dominfo "$nom" 2>/dev/null | awk -F: '/Max memory/ {print $2}' | awk '{print $1}')
  vcpu_total=$((vcpu_total + ${v:-0}))
  memoire_total=$((memoire_total + ${m:-0}))

  if [[ "$mac" != "-" ]]; then
    if $VIRSH domiflist "$nom" 2>/dev/null | grep -qi "$mac"; then
      resultat ok "$nom porte l'adresse materielle declaree $mac"
    else
      resultat ko "$nom : adresse materielle differente de $mac"
    fi
  fi

  if ping -c1 -W2 "$ip" >/dev/null 2>&1; then
    resultat ok "$nom repond sur $ip"
  else
    resultat ko "$nom ne repond pas sur $ip"
  fi
done <<<"$MACHINES"

# --------------------------------------------------------------- dimensionnement
titre "4. Dimensionnement"

attendu_vcpu=$(printf '%s' "$SORTIES" | python3 -c 'import json,sys; print(json.load(sys.stdin)["dimensionnement"]["value"]["vcpu_total"])')
memoire_go=$((memoire_total / 1024 / 1024))

printf '  %s[ ii ]%s %s vCPU et %s Go alloues aux machines en fonctionnement\n' \
  "$jaune" "$net" "$vcpu_total" "$memoire_go"
printf '  %s[ ii ]%s %s vCPU declares au total dans inventaire.tf\n' \
  "$jaune" "$net" "$attendu_vcpu"

libre=$(free -g | awk '/^Mem:/ {print $7}')
if [[ ${libre:-0} -ge 4 ]]; then
  resultat ok "hote : ${libre} Go encore disponibles"
else
  resultat ko "hote : plus que ${libre} Go disponibles, marge insuffisante"
fi

# ------------------------------------------------------------- acces et systemes
titre "5. Acces distant et systemes"

SERVEURS=$(printf '%s' "$SORTIES" | python3 -c '
import json,sys
for nom,v in sorted(json.load(sys.stdin)["serveurs"]["value"].items()):
    print(nom, v["adresse"], v["systeme"].split()[0])
')

while read -r nom ip attendu; do
  [[ -z "$nom" ]] && continue
  if [[ "$attendu" == "Windows" ]]; then
    reel=$(ssh -n -i "$CLE" -o BatchMode=yes -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 "adminlab@$ip" \
      '(Get-CimInstance Win32_OperatingSystem).Caption' 2>/dev/null | tr -d '\r')
  else
    reel=$(ssh -n -i "$CLE" -o BatchMode=yes -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 "adminlab@$ip" \
      '. /etc/os-release && echo "$NAME $VERSION_ID"' 2>/dev/null)
  fi

  if [[ -z "$reel" ]]; then
    resultat ko "$nom : connexion SSH par cle refusee"
  else
    resultat ok "$nom accessible par cle : $reel"
  fi
done <<<"$SERVEURS"

# ------------------------------------------------------------------- conclusion
titre "Resultat"
printf '  %s%d controles reussis%s, %s%d en echec%s\n\n' \
  "$vert" "$ok" "$net" "$([[ $ko -gt 0 ]] && printf '%s' "$rouge" || printf '%s' "$vert")" "$ko" "$net"

[[ $ko -eq 0 ]]
