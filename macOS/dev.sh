#!/usr/bin/env bash
# Installation des outils de développement (macOS)
# Utilise Homebrew (installé automatiquement s’il est absent).
#
# Usage : ./dev.sh [all|frontend|backend|mobile|help]
#   all       — tout installer (défaut)
#   frontend  — NVM, bun (+ dépendances minimales)
#   backend   — PostgreSQL, PHP, rôle/base dev (+ dépendances)
#   mobile    — JDK 21, Android Studio, Flutter ; SDK CLI si DEV_INSTALL_ANDROID_SDK=1
#
# Variables d’environnement (optionnelles) : mêmes que linux/dev.sh
#   NVM_INSTALL_TAG, FLUTTER_ROOT, DEV_SKIP_SHELL_RC, DEV_ACCEPT_ANDROID_LICENSES,
#   DEV_SKIP_POSTGRES_SETUP, POSTGRES_DEV_USER, POSTGRES_DEV_DB,
#   DEV_INSTALL_ANDROID_SDK, ANDROID_SDK_ROOT, ANDROID_API, ANDROID_BUILD_TOOLS,
#   ANDROID_CMDLINE_TOOLS_URL  (zip mac : commandlinetools-mac-* par défaut)
#
# Note : Android Studio via Homebrew Cask. SDK en CLI : zip « mac », pas « linux ».

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly MARKER_FLUTTER_BEGIN="# >>> script-dev/macOS/dev.sh: Flutter PATH"
readonly MARKER_FLUTTER_END="# <<< script-dev/macOS/dev.sh: Flutter PATH"
readonly MARKER_BUN_BEGIN="# >>> script-dev/macOS/dev.sh: bun PATH"
readonly MARKER_BUN_END="# <<< script-dev/macOS/dev.sh: bun PATH"
readonly MARKER_ANDROID_BEGIN="# >>> script-dev/macOS/dev.sh: Android SDK PATH"
readonly MARKER_ANDROID_END="# <<< script-dev/macOS/dev.sh: Android SDK PATH"

BREW_UPDATED=""

log() { printf '[%s] %s\n' "$SCRIPT_NAME" "$*"; }
warn() { printf '[%s] AVERTISSEMENT: %s\n' "$SCRIPT_NAME" "$*" >&2; }
die() { printf '[%s] ERREUR: %s\n' "$SCRIPT_NAME" "$*" >&2; exit 1; }

require_macos() {
  [[ "$(uname -s)" == "Darwin" ]] || die "Ce script est prévu pour macOS (Darwin)."
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

ensure_brew() {
  if have_cmd brew; then
    eval "$(brew shellenv 2>/dev/null)" || true
    return 0
  fi
  log "Homebrew introuvable — installateur officiel (suivez les invites éventuelles)…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    die "Homebrew semble installé mais « brew » n’est pas dans le PATH. Ajoutez-le (voir message d’install Homebrew)."
  fi
}

brew_update_once() {
  ensure_brew
  [[ -n "${BREW_UPDATED:-}" ]] && return 0
  brew update
  BREW_UPDATED=1
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
    for rc in "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.bashrc"; do
      append_profile_block_if_needed "$rc" "$MARKER_FLUTTER_BEGIN" "$MARKER_FLUTTER_END" \
        'export FLUTTER_ROOT="${FLUTTER_ROOT:-$HOME/flutter}"' \
        'export PATH="$FLUTTER_ROOT/bin:$PATH"'
    done
  fi
  if [[ -d "$HOME/.bun/bin" ]]; then
    for rc in "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.bashrc"; do
      append_profile_block_if_needed "$rc" "$MARKER_BUN_BEGIN" "$MARKER_BUN_END" \
        'case ":$PATH:" in *:"$HOME/.bun/bin":*) ;; *) export PATH="$HOME/.bun/bin:$PATH" ;; esac'
    done
  fi
  local sdk="${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}"
  if [[ -x "${sdk}/cmdline-tools/latest/bin/sdkmanager" ]]; then
    for rc in "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.bashrc"; do
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
  log "Homebrew : git, vim, httpie, curl, wget, unzip…"
  brew_update_once
  brew install git vim httpie curl wget gnupg unzip
}

install_postgresql_server() {
  log "PostgreSQL (Homebrew)…"
  brew_update_once
  brew install postgresql
  brew services start postgresql 2>/dev/null || brew services start postgresql@16 2>/dev/null || true
  sleep 2
}

setup_postgres_dev() {
  [[ "${DEV_SKIP_POSTGRES_SETUP:-0}" == "1" ]] && return 0
  if ! have_cmd psql; then
    warn "psql absent ; configuration PostgreSQL ignorée."
    return 0
  fi
  if ! psql -d postgres -c 'SELECT 1' >/dev/null 2>&1; then
    warn "PostgreSQL : connexion à la base « postgres » impossible. Démarrez le service : brew services start postgresql"
    return 0
  fi
  local user="${POSTGRES_DEV_USER:-dev}"
  local db="${POSTGRES_DEV_DB:-devdb}"
  log "PostgreSQL : rôle « $user », base « $db » (superuser local dev)…"
  if ! psql -d postgres -tc "SELECT 1 FROM pg_roles WHERE rolname='${user}'" 2>/dev/null | grep -qE '^[[:space:]]*1[[:space:]]*$'; then
    createuser -s "$user" 2>/dev/null || psql -d postgres -c "CREATE ROLE \"${user}\" WITH SUPERUSER LOGIN;"
  fi
  if ! psql -d postgres -tc "SELECT 1 FROM pg_database WHERE datname='${db}'" 2>/dev/null | grep -qE '^[[:space:]]*1[[:space:]]*$'; then
    createdb -O "$user" "$db" 2>/dev/null || psql -d postgres -c "CREATE DATABASE \"${db}\" OWNER \"${user}\";"
  fi
}

install_git_vim_httpie_postgres() {
  install_core_cli_packages
  install_postgresql_server
}

install_vscode() {
  if have_cmd code || [[ -d "/Applications/Visual Studio Code.app" ]]; then
    log "VS Code déjà présent, ignoré."
    return 0
  fi
  log "Visual Studio Code (Cask)…"
  brew_update_once
  brew install --cask visual-studio-code
}

install_android_studio() {
  if [[ -d "/Applications/Android Studio.app" ]]; then
    log "Android Studio déjà installé, ignoré."
    return 0
  fi
  log "Android Studio (Cask)…"
  brew_update_once
  brew install --cask android-studio
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
  log "NVM installé. Ouvrez un nouveau terminal ou : source ~/.nvm/nvm.sh"
}

install_bun() {
  if have_cmd bun; then
    log "bun déjà présent, ignoré."
    return 0
  fi
  log "bun…"
  curl -fsSL https://bun.sh/install | bash
  log "bun installé. Un bloc PATH sera ajouté aux profils (sauf DEV_SKIP_SHELL_RC=1)."
}

install_php() {
  if have_cmd php; then
    log "PHP déjà présent ($(php -r 'echo PHP_VERSION;' 2>/dev/null || echo ?)), ignoré."
    return 0
  fi
  log "PHP (Homebrew)…"
  brew_update_once
  brew install php
}

brew_openjdk21_prefix() {
  brew --prefix openjdk@21 2>/dev/null || true
}

ensure_java_home_21() {
  if [[ -n "${JAVA_HOME:-}" ]] && [[ -x "${JAVA_HOME}/bin/java" ]]; then
    return 0
  fi
  local p
  p="$(brew_openjdk21_prefix)"
  if [[ -n "$p" ]]; then
    local home="${p}/libexec/openjdk.jdk/Contents/Home"
    if [[ -x "${home}/bin/java" ]]; then
      export JAVA_HOME="$home"
      return 0
    fi
  fi
  return 1
}

install_openjdk21() {
  if have_cmd java && java -version 2>&1 | grep -qE 'version "21\.|"21\.'; then
    log "Java 21 déjà utilisée par défaut, ignoré."
    ensure_java_home_21 || true
    return 0
  fi
  log "OpenJDK 21 (Homebrew)…"
  brew_update_once
  brew install openjdk@21
  ensure_java_home_21 || true
  log "Pour les outils système : sudo ln -sfn \"\$(brew --prefix openjdk@21)/libexec/openjdk.jdk\" /Library/Java/JavaVirtualMachines/openjdk-21.jdk"
  ensure_java_home_21 || warn "JAVA_HOME : exportez JAVA_HOME=\"\$(/usr/libexec/java_home -v 21)\" ou le chemin Homebrew openjdk@21 (voir brew info openjdk@21)."
}

install_android_sdk_cli() {
  [[ "${DEV_INSTALL_ANDROID_SDK:-0}" == "1" ]] || return 0
  install_openjdk21
  ensure_java_home_21 || die "JDK 21 requis pour sdkmanager. Installez openjdk@21 puis relancez avec DEV_INSTALL_ANDROID_SDK=1."
  local root="${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}"
  export ANDROID_SDK_ROOT="$root"
  export ANDROID_HOME="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
  if [[ -x "${root}/cmdline-tools/latest/bin/sdkmanager" ]] && [[ -d "${root}/platform-tools" ]]; then
    log "Android SDK CLI déjà présent dans $root, mise à jour des paquets listés…"
  else
    log "Android SDK command-line tools (Google, macOS)…"
    mkdir -p "${root}/cmdline-tools"
    local zip_url="${ANDROID_CMDLINE_TOOLS_URL:-https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip}"
    local zf
    zf="$(mktemp /tmp/cmdline-tools-mac-XXXXXX.zip)"
    curl -fsSL -o "$zf" "$zip_url" || die "Téléchargement commandlinetools échoué. Définissez ANDROID_CMDLINE_TOOLS_URL."
    local tmp
    tmp="$(mktemp -d /tmp/android-cmdline-mac-XXXXXX)"
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
  flutter doctor || warn "flutter dooutés dans ~/.zshrc / ~/.bash_profile si présents (sauf DEV_SKIP_SHELL_RC=1)."
}

run_all() {
  require_macos
  ensure_brew
  export FLUTTER_ROOT="${FLUTTER_ROOT:-$HOME/flutter}"
  log "Mode all — démarrage (Homebrew + téléchargements)…"

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
  log "  - Nouveau terminal ou source ~/.zshrc (PATH Flutter, bun, Android SDK)."
  log "  - NVM : source ~/.nvm/nvm.sh puis nvm install --lts"
  log "  - JDK 21 : brew info openjdk@21 (symlink optionnel vers /Library/Java/JavaVirtualMachines/)"
  log "  - PostgreSQL : rôle ${POSTGRES_DEV_USER:-dev} / base ${POSTGRES_DEV_DB:-devdb}"
  log "  - SDK Android CLI : DEV_INSTALL_ANDROID_SDK=1 ./dev.sh all"
}

run_frontend() {
  require_macos
  ensure_brew
  log "Mode frontend…"
  install_core_cli_packages
  install_nvm
  install_bun
  finalize_shell_profiles
  log "Frontend terminé (NVM + bun)."
}

run_backend() {
  require_macos
  ensure_brew
  log "Mode backend…"
  install_core_cli_packages
  install_postgresql_server
  setup_postgres_dev
  install_php
  log "Backend terminé (PostgreSQL + PHP)."
}

run_mobile() {
  require_macos
  ensure_brew
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
Installation outils dev (macOS, Homebrew).

Usage : dev.sh [all|frontend|backend|mobile|help]

  all        Tout installer (défaut si aucun argument).
  frontend   NVM, bun + paquets de base.
  backend    PostgreSQL (rôle/base dev), PHP + paquets de base.
  mobile     JDK 21, Android Studio, Flutter ; SDK CLI si DEV_INSTALL_ANDROID_SDK=1.

Variables : voir l’en-tête du script (DEV_*, POSTGRES_*, ANDROID_*, NVM_INSTALL_TAG, …).

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
