#!/usr/bin/env bash
# Installation des outils de développement (Ubuntu / Debian)
# Nécessite : sudo pour les paquets système
#
# Usage : ./dev.sh [all|frontend|backend|mobile|help]
#   all       — tout installer (défaut)
#   frontend  — NVM, bun (+ dépendances minimales)
#   backend   — PostgreSQL, PHP, rôle/base dev (+ dépendances)
#   mobile    — JDK 21, Android Studio, Flutter ; SDK CLI si DEV_INSTALL_ANDROID_SDK=1
#
# Variables d’environnement (optionnelles) :
#   NVM_INSTALL_TAG=latest | v0.x.x
#   FLUTTER_ROOT=~/flutter
#   DEV_SKIP_SHELL_RC=1
#   DEV_ACCEPT_ANDROID_LICENSES=1
#   DEV_SKIP_POSTGRES_SETUP=1     — ne pas créer rôle/base dev PostgreSQL
#   POSTGRES_DEV_USER=dev         — rôle PostgreSQL (superuser dev local)
#   POSTGRES_DEV_DB=devdb
#   DEV_INSTALL_ANDROID_SDK=1     — cmdline-tools, platform-tools, plateforme, build-tools
#   ANDROID_SDK_ROOT=~/Android/Sdk
#   ANDROID_API=34                — pour sdkmanager (platforms;android-NN)
#   ANDROID_BUILD_TOOLS=34.0.0
#   DEV_ANDROID_STUDIO_USE_TARBALL=1 — forcer l’archive .tar.gz (sinon Debian utilise le tar par défaut)
#   ANDROID_STUDIO_INSTALL_DIR=~/android-studio — répertoire d’installation de l’archive
#   ANDROID_STUDIO_LINUX_TARBALL_URL — URL .tar.gz Android Studio (repli si snap échoue)
#   ANDROID_CMDLINE_TOOLS_URL     — zip des command line tools (optionnel)
#
# Note : snap Android Studio est privilégié sur Ubuntu ; sur Debian, l’archive Google est utilisée par défaut.

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly MARKER_FLUTTER_BEGIN="# >>> script-dev/linux/dev.sh: Flutter PATH"
readonly MARKER_FLUTTER_END="# <<< script-dev/linux/dev.sh: Flutter PATH"
readonly MARKER_BUN_BEGIN="# >>> script-dev/linux/dev.sh: bun PATH"
readonly MARKER_BUN_END="# <<< script-dev/linux/dev.sh: bun PATH"
readonly MARKER_ANDROID_BEGIN="# >>> script-dev/linux/dev.sh: Android SDK PATH"
readonly MARKER_ANDROID_END="# <<< script-dev/linux/dev.sh: Android SDK PATH"

APT_UPDATED=""

log() { printf '[%s] %s\n' "$SCRIPT_NAME" "$*"; }
warn() { printf '[%s] AVERTISSEMENT: %s\n' "$SCRIPT_NAME" "$*" >&2; }
die() { printf '[%s] ERREUR: %s\n' "$SCRIPT_NAME" "$*" >&2; exit 1; }

require_debian_family() {
  if [[ ! -f /etc/os-release ]]; then
    die "Fichier /etc/os-release introuvable. Ce script cible Debian/Ubuntu."
  fi
  # shellcheck source=/dev/null
  source /etc/os-release
  case "${ID:-}" in
    ubuntu|debian|linuxmint|pop) ;;
    *) die "Distribution non prise en charge: ${ID:-inconnu}. Utilisez Debian ou Ubuntu." ;;
  esac
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

apt_update_once() {
  export DEBIAN_FRONTEND=noninteractive
  [[ -n "${APT_UPDATED:-}" ]] && return 0
  sudo apt-get update -qq
  APT_UPDATED=1
}

apt_refresh_after_repo() {
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get update -qq
  APT_UPDATED=1
}

apt_install() {
  export DEBIAN_FRONTEND=noninteractive
  apt_update_once
  sudo apt-get install -y --no-install-recommends "$@"
}

nvm_resolve_install_tag() {
  local req="${NVM_INSTALL_TAG:-latest}"
  if [[ "$req" != "latest" ]]; then
    printf '%s\n' "$req"
    return 0
  fi
  local tag=""
  tag="$(curl -fsSL --connect-timeout 12 https://api.github.com/repos/nvm-sh/nvm/releases/latest 2>/dev/null \
    | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1 || true)"
  if [[ -z "$tag" ]]; then
    warn "Tag nvm « latest » indisponible (réseau/API) ; repli sur v0.40.1."
    printf '%s\n' "v0.40.1"
  else
    printf '%s\n' "$tag"
  fi
}

profile_contains_marker() {
  local f="$1"
  local m="$2"
  [[ -f "$f" ]] && grep -qF "$m" "$f"
}

append_profile_block_if_needed() {
  [[ "${DEV_SKIP_SHELL_RC:-0}" == "1" ]] && return 0
  local file="$1"
  local begin="$2"
  local end="$3"
  shift 3
  [[ -f "$file" ]] || return 0
  if profile_contains_marker "$file" "$begin"; then
    return 0
  fi
  {
    printf '\n%s\n' "$begin"
    printf '%s\n' "$@"
    printf '%s\n' "$end"
  } >>"$file"
  log "Bloc PATH ajouté dans $file"
}

finalize_shell_profiles() {
  [[ "${DEV_SKIP_SHELL_RC:-0}" == "1" ]] && return 0
  local flutter_root="${FLUTTER_ROOT:-$HOME/flutter}"
  if [[ -x "${flutter_root}/bin/flutter" ]]; then
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
      append_profile_block_if_needed "$rc" "$MARKER_FLUTTER_BEGIN" "$MARKER_FLUTTER_END" \
        'export FLUTTER_ROOT="${FLUTTER_ROOT:-$HOME/flutter}"' \
        'export PATH="$FLUTTER_ROOT/bin:$PATH"'
    done
  fi
  if [[ -d "$HOME/.bun/bin" ]]; then
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
      append_profile_block_if_needed "$rc" "$MARKER_BUN_BEGIN" "$MARKER_BUN_END" \
        'case ":$PATH:" in *:"$HOME/.bun/bin":*) ;; *) export PATH="$HOME/.bun/bin:$PATH" ;; esac'
    done
  fi
  local sdk="${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}"
  if [[ -x "${sdk}/cmdline-tools/latest/bin/sdkmanager" ]]; then
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
      append_profile_block_if_needed "$rc" "$MARKER_ANDROID_BEGIN" "$MARKER_ANDROID_END" \
        'export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}"' \
        'export ANDROID_HOME="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"' \
        'export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"'
    done
  fi
}

maybe_accept_android_licenses() {
  [[ "${DEV_ACCEPT_ANDROID_LICENSES:-0}" == "1" ]] || return 0
  local flutter_root="${FLUTTER_ROOT:-$HOME/flutter}"
  [[ -x "${flutter_root}/bin/flutter" ]] || return 0
  export PATH="${flutter_root}/bin:${PATH}"
  log "DEV_ACCEPT_ANDROID_LICENSES=1 : acceptation des licences Android (SDK requis)…"
  if yes | flutter doctor --android-licenses; then
    log "Licences Android acceptées (ou déjà à jour)."
  else
    warn "Licences Android non traitées (pas de SDK, ou erreur). Quand le SDK est prêt : yes | flutter doctor --android-licenses"
  fi
}

install_core_cli_packages() {
  log "Paquets de base (git, curl, vim, httpie, …)…"
  apt_install \
    git \
    vim \
    httpie \
    ca-certificates \
    curl \
    wget \
    gnupg \
    software-properties-common \
    apt-transport-https \
    unzip
}

install_postgresql_server() {
  log "PostgreSQL (serveur)…"
  apt_install postgresql postgresql-contrib
}

setup_postgres_dev() {
  [[ "${DEV_SKIP_POSTGRES_SETUP:-0}" == "1" ]] && return 0
  if ! sudo -u postgres psql -c 'SELECT 1' >/dev/null 2>&1; then
    warn "PostgreSQL : impossible d’exécuter psql en tant que « postgres » (service arrêté ou droits sudo). Rôle/base dev ignorés."
    return 0
  fi
  local user="${POSTGRES_DEV_USER:-dev}"
  local db="${POSTGRES_DEV_DB:-devdb}"
  log "PostgreSQL : rôle « $user », base « $db » (superuser local dev)…"
  if ! sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='${user}'" 2>/dev/null | grep -qE '^[[:space:]]*1[[:space:]]*$'; then
    sudo -u postgres createuser -s "$user"
  fi
  if ! sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='${db}'" 2>/dev/null | grep -qE '^[[:space:]]*1[[:space:]]*$'; then
    sudo -u postgres createdb -O "$user" "$db"
  fi
}

install_git_vim_httpie_postgres() {
  install_core_cli_packages
  install_postgresql_server
}

install_vscode() {
  if have_cmd code; then
    log "VS Code déjà présent, ignoré."
    return 0
  fi
  log "Visual Studio Code…"
  local arch
  arch="$(dpkg --print-architecture)"
  sudo install -d -m 0755 /etc/apt/keyrings
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor \
    | sudo tee /etc/apt/keyrings/packages.microsoft.gpg >/dev/null
  echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
  apt_refresh_after_repo
  sudo apt-get install -y code
}

ensure_java_home_21() {
  if [[ -n "${JAVA_HOME:-}" ]] && [[ -x "${JAVA_HOME}/bin/java" ]]; then
    return 0
  fi
  local d
  for d in /usr/lib/jvm/java-21-* /usr/lib/jvm/temurin-21-*; do
    if [[ -x "${d}/bin/java" ]]; then
      export JAVA_HOME="$d"
      return 0
    fi
  done
  return 1
}

install_android_studio_tarball() {
  local url="${ANDROID_STUDIO_LINUX_TARBALL_URL:-https://dl.google.com/dl/android/studio/ide-zips/2024.3.1.19/android-studio-2024.3.1.19-linux.tar.gz}"
  local as_home="${ANDROID_STUDIO_INSTALL_DIR:-$HOME/android-studio}"
  if [[ -x "${as_home}/bin/studio.sh" ]]; then
    log "Android Studio (archive) déjà présent dans ${as_home}, ignoré."
    return 0
  fi
  log "Android Studio (archive .tar.gz)…"
  local parent
  parent="$(dirname "$as_home")"
  mkdir -p "$parent"
  local tgz
  tgz="$(mktemp /tmp/android-studio-XXXXXX.tar.gz)"
  wget -qO "$tgz" "$url" || die "Téléchargement Android Studio échoué. Définissez ANDROID_STUDIO_LINUX_TARBALL_URL."
  tar -xzf "$tgz" -C "$parent"
  rm -f "$tgz"
  if [[ "${as_home}" != "$parent/android-studio" ]] && [[ -d "$parent/android-studio" ]]; then
    if [[ ! -e "$as_home" ]]; then
      mv "$parent/android-studio" "$as_home"
    fi
  fi
  log "Android Studio extrait — lancez : ${as_home}/bin/studio.sh"
}

install_android_studio() {
  local as_home="${ANDROID_STUDIO_INSTALL_DIR:-$HOME/android-studio}"
  if have_cmd android-studio || snap list android-studio &>/dev/null; then
    log "Android Studio déjà installé (snap ou binaire), ignoré."
    return 0
  fi
  if [[ -x "${as_home}/bin/studio.sh" ]]; then
    log "Android Studio déjà présent (${as_home}), ignoré."
    return 0
  fi
  local prefer_tar=false
  if [[ "${DEV_ANDROID_STUDIO_USE_TARBALL:-0}" == "1" ]]; then
    prefer_tar=true
  elif [[ "${ID:-}" == "debian" ]]; then
    prefer_tar=true
  fi
  if [[ "$prefer_tar" == "true" ]]; then
    install_android_studio_tarball
    return 0
  fi
  log "Android Studio (snap, classic)…"
  if ! have_cmd snap; then
    log "Installation de snapd…"
    apt_install snapd
    sudo systemctl enable --now snapd.socket 2>/dev/null || true
  fi
  if sudo snap install android-studio --classic; then
    return 0
  fi
  warn "Snap Android Studio a échoué ; repli archive .tar.gz."
  install_android_studio_tarball
}

install_nvm() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    log "NVM déjà présent dans $NVM_DIR, ignoré."
    return 0
  fi
  local tag
  tag="$(nvm_resolve_install_tag)"
  log "NVM (installateur officiel, tag $tag)…"
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${tag}/install.sh" | bash
  # shellcheck source=/dev/null
  [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
  log "NVM installé. Le script d’install configure en général ~/.bashrc ou ~/.zshrc ; sinon : source ~/.nvm/nvm.sh"
}

install_bun() {
  if have_cmd bun; then
    log "bun déjà présent, ignoré."
    return 0
  fi
  log "bun…"
  curl -fsSL https://bun.sh/install | bash
  log "bun installé. Un bloc PATH sera ajouté aux profils (sauf si DEV_SKIP_SHELL_RC=1)."
}

install_php() {
  if have_cmd php; then
    log "PHP déjà présent ($(php -r 'echo PHP_VERSION;' 2>/dev/null || echo ?)), ignoré."
    return 0
  fi
  log "PHP (CLI + extensions courantes)…"
  apt_install \
    php \
    php-cli \
    php-xml \
    php-mbstring \
    php-curl \
    php-zip \
    php-pgsql
}

install_openjdk21() {
  if have_cmd java && java -version 2>&1 | grep -qE 'version "21\.|"21\.'; then
    log "Java 21 déjà utilisée par défaut, ignoré."
    ensure_java_home_21 || true
    return 0
  fi
  log "JDK 21…"
  # shellcheck source=/dev/null
  source /etc/os-release
  if apt-cache policy openjdk-21-jdk 2>/dev/null | grep -q 'Candidate:.*[1-9]'; then
    apt_install openjdk-21-jdk
  else
    log "OpenJDK 21 indisponible dans les dépôts : dépôt Eclipse Temurin (Adoptium)…"
    sudo install -d -m 0755 /etc/apt/keyrings
    wget -qO- https://packages.adoptium.net/artifactory/api/gpg/key/public \
      | gpg --dearmor \
      | sudo tee /etc/apt/keyrings/adoptium.gpg >/dev/null
    echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb ${VERSION_CODENAME:-$(lsb_release -cs 2>/dev/null || echo jammy)} main" \
      | sudo tee /etc/apt/sources.list.d/adoptium.list >/dev/null
    apt_refresh_after_repo
    sudo apt-get install -y temurin-21-jdk
  fi
  if have_cmd update-alternatives; then
    local j21=""
    for d in /usr/lib/jvm/java-21-* /usr/lib/jvm/temurin-21-*; do
      if [[ -x "${d}/bin/java" ]]; then
        j21="${d}/bin/java"
        break
      fi
    done
    if [[ -n "$j21" ]]; then
      sudo update-alternatives --install /usr/bin/java java "$j21" 21100 >/dev/null 2>&1 || true
      sudo update-alternatives --set java "$j21" 2>/dev/null || warn "Plusieurs JDK : choisissez la version par défaut avec : sudo update-alternatives --config java"
    fi
  fi
  ensure_java_home_21 || warn "JAVA_HOME non détecté ; sdkmanager peut échouer sans export JAVA_HOME."
}

install_android_sdk_cli() {
  [[ "${DEV_INSTALL_ANDROID_SDK:-0}" == "1" ]] || return 0
  install_openjdk21
  ensure_java_home_21 || die "JDK 21 requis pour sdkmanager. Installez Java 21 puis relancez avec DEV_INSTALL_ANDROID_SDK=1."
  local root="${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}"
  export ANDROID_SDK_ROOT="$root"
  export ANDROID_HOME="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
  if [[ -x "${root}/cmdline-tools/latest/bin/sdkmanager" ]] && [[ -d "${root}/platform-tools" ]]; then
    log "Android SDK CLI déjà présent dans $root, mise à jour des paquets listés…"
  else
    log "Android SDK command-line tools (Google)…"
    mkdir -p "${root}/cmdline-tools"
    local zip_url="${ANDROID_CMDLINE_TOOLS_URL:-https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip}"
    local zf
    zf="$(mktemp /tmp/cmdline-tools-XXXXXX.zip)"
    wget -qO "$zf" "$zip_url" || die "Téléchargement commandlinetools échoué. Définissez ANDROID_CMDLINE_TOOLS_URL."
    local tmp
    tmp="$(mktemp -d /tmp/android-cmdline-XXXXXX)"
    unzip -q -o "$zf" -d "$tmp"
    rm -f "$zf"
    rm -rf "${root}/cmdline-tools/latest"
    if [[ -d "${tmp}/cmdline-tools" ]]; then
      mv "${tmp}/cmdline-tools" "${root}/cmdline-tools/latest"
    else
      die "Structure du zip commandlinetools inattendue sous $tmp"
    fi
    rm -rf "$tmp"
  fi
  export PATH="${root}/cmdline-tools/latest/bin:${root}/platform-tools:${PATH}"
  local api="${ANDROID_API:-34}"
  local bt="${ANDROID_BUILD_TOOLS:-34.0.0}"
  log "sdkmanager : licences, platform-tools, android-${api}, build-tools…"
  yes | sdkmanager --sdk_root="$root" --licenses >/dev/null 2>&1 || true
  sdkmanager --sdk_root="$root" \
    "platform-tools" \
    "platforms;android-${api}" \
    "build-tools;${bt}"
}

install_flutter() {
  export FLUTTER_ROOT="${FLUTTER_ROOT:-$HOME/flutter}"
  if [[ -d "$FLUTTER_ROOT/bin" ]] && [[ -x "$FLUTTER_ROOT/bin/flutter" ]]; then
    log "Flutter déjà présent dans $FLUTTER_ROOT, ignoré."
    return 0
  fi
  log "Flutter (canal stable, clone git)…"
  git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_ROOT"
  export PATH="$FLUTTER_ROOT/bin:$PATH"
  flutter doctor || warn "flutter doctor a signalé des manques (SDK Android, licences, etc.). Corrigez selon les messages ci-dessus."
  log "PATH Flutter : un bloc sera ajouté à .bashrc / .zshrc (sauf DEV_SKIP_SHELL_RC=1)."
}

run_all() {
  require_debian_family
  export FLUTTER_ROOT="${FLUTTER_ROOT:-$HOME/flutter}"
  log "Mode all — démarrage (sudo requis)…"

  install_git_vim_httpie_postgres
  setup_postgres_dev
  install_vscode
  install_android_studio
  install_nvm
  install_bun
  install_php
  install_openjdk21
  install_android_sdk_cli
  install_flutter

  finalize_shell_profiles
  maybe_accept_android_licenses

  log "Terminé."
  log "Rappels :"
  log "  - Nouveau terminal ou source ~/.bashrc / ~/.zshrc (PATH Flutter, bun, Android SDK)."
  log "  - NVM : source ~/.nvm/nvm.sh puis nvm install --lts"
  log "  - JDK : sudo update-alternatives --config java si besoin"
  log "  - PostgreSQL : rôle ${POSTGRES_DEV_USER:-dev} / base ${POSTGRES_DEV_DB:-devdb} (connexion peer ou mot de passe selon pg_hba.conf)"
  log "  - SDK Android complet : ./dev.sh all avec DEV_INSTALL_ANDROID_SDK=1"
}

run_frontend() {
  require_debian_family
  log "Mode frontend…"
  install_core_cli_packages
  install_nvm
  install_bun
  finalize_shell_profiles
  log "Frontend terminé (NVM + bun)."
}

run_backend() {
  require_debian_family
  log "Mode backend…"
  install_core_cli_packages
  install_postgresql_server
  setup_postgres_dev
  install_php
  log "Backend terminé (PostgreSQL + PHP)."
}

run_mobile() {
  require_debian_family
  export FLUTTER_ROOT="${FLUTTER_ROOT:-$HOME/flutter}"
  log "Mode mobile…"
  install_core_cli_packages
  install_openjdk21
  install_android_studio
  install_android_sdk_cli
  install_flutter
  finalize_shell_profiles
  maybe_accept_android_licenses
  log "Mobile terminé (JDK, Android Studio, Flutter ; SDK CLI si DEV_INSTALL_ANDROID_SDK=1)."
}

usage() {
  cat <<'EOF'
Installation outils dev (Debian/Ubuntu).

Usage : dev.sh [all|frontend|backend|mobile|help]

  all        Tout installer (défaut si aucun argument).
  frontend   NVM, bun + paquets de base.
  backend    PostgreSQL (rôle/base dev), PHP + paquets de base.
  mobile     JDK 21, Android Studio, Flutter ; SDK CLI si DEV_INSTALL_ANDROID_SDK=1.

Variables utiles : voir l’en-tête du script (DEV_*, POSTGRES_*, ANDROID_*, etc.).

Exemples :
  ./dev.sh backend
  DEV_INSTALL_ANDROID_SDK=1 DEV_ACCEPT_ANDROID_LICENSES=1 ./dev.sh mobile
EOF
}

main() {
  case "${1:-all}" in
    -h|--help|help)
      usage
      ;;
    all|"")
      run_all
      ;;
    frontend)
      run_frontend
      ;;
    backend)
      run_backend
      ;;
    mobile)
      run_mobile
      ;;
    *)
      die "Commande inconnue : $1 — essayez : $SCRIPT_NAME help"
      ;;
  esac
}

main "$@"
