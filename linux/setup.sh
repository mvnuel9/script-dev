#!/usr/bin/env bash
# Installation simple des outils de développement (Ubuntu / Debian)
# Paquets : Git, Vim, HTTPie, PostgreSQL, VS Code, Android Studio (snap),
# NVM, bun, PHP, OpenJDK 21, Flutter (canal stable).
#
# Usage : chmod +x setup.sh && ./setup.sh
# Prérequis : sudo, connexion Internet.

set -euo pipefail

echo "==> Vérification de la distribution…"
if [[ ! -f /etc/os-release ]]; then
  echo "Erreur : /etc/os-release introuvable." >&2
  exit 1
fi
# shellcheck source=/dev/null
source /etc/os-release
case "${ID:-}" in
  ubuntu|debian|linuxmint|pop) ;;
  *) echo "Erreur : ${ID:-?} non pris en charge (utilisez Debian ou Ubuntu)." >&2; exit 1 ;;
esac

export DEBIAN_FRONTEND=noninteractive

echo "==> Mise à jour des paquets et installation (apt)…"
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
  git vim httpie \
  postgresql postgresql-contrib \
  ca-certificates curl wget gnupg \
  software-properties-common apt-transport-https unzip

echo "==> Visual Studio Code…"
if ! command -v code >/dev/null 2>&1; then
  arch="$(dpkg --print-architecture)"
  sudo install -d -m 0755 /etc/apt/keyrings
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor \
    | sudo tee /etc/apt/keyrings/packages.microsoft.gpg >/dev/null
  echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y code
else
  echo "    (déjà installé)"
fi

echo "==> Android Studio (snap)…"
if command -v android-studio >/dev/null 2>&1 || snap list android-studio &>/dev/null; then
  echo "    (déjà installé)"
else
  sudo apt-get install -y snapd
  sudo systemctl enable --now snapd.socket 2>/dev/null || true
  sudo snap install android-studio --classic
fi

echo "==> OpenJDK 21…"
if ! java -version 2>&1 | grep -qE 'version "21\.|"21\.'; then
  if apt-cache policy openjdk-21-jdk 2>/dev/null | grep -q 'Candidate:.*[1-9]'; then
    sudo apt-get install -y openjdk-21-jdk
  else
    echo "    OpenJDK 21 absent des dépôts : ajout du dépôt Adoptium (Temurin)…"
    sudo install -d -m 0755 /etc/apt/keyrings
    wget -qO- https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor \
      | sudo tee /etc/apt/keyrings/adoptium.gpg >/dev/null
    echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb ${VERSION_CODENAME:-$(lsb_release -cs 2>/dev/null || echo jammy)} main" \
      | sudo tee /etc/apt/sources.list.d/adoptium.list >/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y temurin-21-jdk
  fi
else
  echo "    (Java 21 déjà par défaut ou présente)"
fi

echo "==> PHP (CLI + extensions courantes)…"
if ! command -v php >/dev/null 2>&1; then
  sudo apt-get install -y \
    php php-cli php-xml php-mbstring php-curl php-zip php-pgsql
else
  echo "    (déjà installé)"
fi

echo "==> NVM…"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
else
  echo "    (déjà installé)"
fi

echo "==> bun…"
if ! command -v bun >/dev/null 2>&1; then
  curl -fsSL https://bun.sh/install | bash
else
  echo "    (déjà installé)"
fi

echo "==> Flutter (canal stable → ~/flutter)…"
FLUTTER_ROOT="${FLUTTER_ROOT:-$HOME/flutter}"
if [[ -x "$FLUTTER_ROOT/bin/flutter" ]]; then
  echo "    (déjà présent dans $FLUTTER_ROOT)"
else
  git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_ROOT"
  export PATH="$FLUTTER_ROOT/bin:$PATH"
  flutter doctor || true
fi

echo ""
echo "Terminé. Pensez à :"
echo "  • Nouveau terminal ou : source ~/.bashrc  (NVM / bun ajoutent souvent le PATH)"
echo "  • Node : source \"\$NVM_DIR/nvm.sh\" && nvm install --lts"
echo "  • Flutter : export PATH=\"\$HOME/flutter/bin:\$PATH\" (ou ajoutez-la dans ~/.bashrc)"
echo "  • PostgreSQL : sudo systemctl status postgresql"
