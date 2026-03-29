#!/usr/bin/env bash
# Installation simple des outils de développement (macOS / Homebrew)
# Outils : Git, Vim, HTTPie, PostgreSQL, VS Code, Android Studio, OpenJDK 21,
# PHP, NVM, bun, Flutter (canal stable).
#
# Usage : chmod +x setup.sh && ./setup.sh
# Prérequis : macOS, connexion Internet (install Homebrew si besoin).

set -euo pipefail

echo "==> Vérification macOS…"
[[ "$(uname -s)" == "Darwin" ]] || { echo "Erreur : ce script est pour macOS." >&2; exit 1; }

if ! command -v brew >/dev/null 2>&1; then
  echo "==> Installation de Homebrew…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    echo "Erreur : Homebrew installé mais « brew » introuvable dans le PATH." >&2
    exit 1
  fi
else
  eval "$(brew shellenv 2>/dev/null)" || true
fi

echo "==> Mise à jour Homebrew et paquets de base…"
brew update
brew install git vim httpie curl wget gnupg unzip postgresql

echo "==> Démarrage de PostgreSQL…"
brew services start postgresql 2>/dev/null || brew services start postgresql@16 2>/dev/null || true

echo "==> Visual Studio Code…"
if [[ -d "/Applications/Visual Studio Code.app" ]] || command -v code >/dev/null 2>&1; then
  echo "    (déjà installé)"
else
  brew install --cask visual-studio-code
fi

echo "==> Android Studio…"
if [[ -d "/Applications/Android Studio.app" ]]; then
  echo "    (déjà installé)"
else
  brew install --cask android-studio
fi

echo "==> OpenJDK 21…"
if java -version 2>&1 | grep -qE 'version "21\.|"21\.'; then
  echo "    (Java 21 déjà utilisée ou présente)"
else
  brew install openjdk@21
fi

echo "==> PHP…"
if command -v php >/dev/null 2>&1; then
  echo "    (déjà installé)"
else
  brew install php
fi

echo "==> NVM…"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  echo "    (déjà installé)"
else
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi

echo "==> bun…"
if command -v bun >/dev/null 2>&1; then
  echo "    (déjà installé)"
else
  curl -fsSL https://bun.sh/install | bash
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
echo "  • Nouveau terminal (ou : eval \"\$(brew shellenv)\")"
echo "  • Node : source \"\$NVM_DIR/nvm.sh\" && nvm install --lts"
echo "  • Flutter : export PATH=\"\$HOME/flutter/bin:\$PATH\" (à mettre dans ~/.zshrc si besoin)"
echo "  • JDK 21 : brew info openjdk@21 (JAVA_HOME, lien vers /Library/Java/JavaVirtualMachines/ optionnel)"
echo "  • PostgreSQL : brew services list"
