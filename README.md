# script-dev

Scripts shell pour installer une **boîte à outils de développement** sur **Linux** (Debian / Ubuntu et dérivés) et **macOS**. Deux niveaux sont proposés : **simple** (`setup.sh`) et **avancé** (`dev.sh`, Linux uniquement dans ce dépôt).

## Contenu du dépôt

| Chemin | Rôle |
|--------|------|
| `linux/setup.sh` | Installation **linéaire** : une seule commande, peu d’options. |
| `linux/dev.sh` | Installation **modulaire** : sous-commandes, variables d’environnement, SDK Android en CLI, profils shell, PostgreSQL « dev », etc. |
| `macOS/setup.sh` | Même esprit que `linux/setup.sh`, via **Homebrew**. |

## Choisir un script

- **Nouvelle machine, tout installer vite** → `setup.sh` du dossier qui correspond à ton OS.
- **Contrôle fin** (seulement front, back, mobile ; SDK Android ; PATH dans `.zshrc` / `.bashrc` ; rôle Postgres `dev`) → `linux/dev.sh` sous Linux.

Sur **macOS**, ce dépôt fournit aujourd’hui uniquement la **version simple** (`macOS/setup.sh`). Pour reproduire la logique de `linux/dev.sh` (modes `frontend` / `backend` / `mobile`, `DEV_INSTALL_ANDROID_SDK`, etc.) sur Mac, il faudrait un `macOS/dev.sh` équivalent basé sur Homebrew (non inclus ici pour l’instant).

---

## Prérequis communs

- **Connexion Internet** (téléchargements `apt`, Homebrew, GitHub, Google, etc.).
- **Git** n’est pas obligatoire pour lancer les scripts : `setup.sh` / `dev.sh` peuvent l’installer pour toi.
- Exécuter les scripts depuis un terminal, en étant dans le dépôt (ou en donnant le **chemin complet** au script).

Rendre les scripts exécutables une fois (depuis la racine du dépôt) :

```bash
chmod +x linux/dev.sh linux/setup.sh macOS/setup.sh
```

---

## Linux

Systèmes pris en charge : **Ubuntu**, **Debian**, **Linux Mint**, **Pop!_OS** (détection via `/etc/os-release`).

### Installation simple — `linux/setup.sh`

Enchaîne sans sous-commandes : paquets `apt`, dépôt Microsoft pour VS Code, snap pour Android Studio (sur Ubuntu ; ajustements possibles), OpenJDK 21 ou Temurin, PHP, NVM (tag fixe `v0.40.1`), bun, clone Flutter stable dans `~/flutter`.

```bash
./linux/setup.sh
```

`sudo` sera demandé pour `apt` et snap.

### Installation avancée — `linux/dev.sh`

#### Commandes (modes)

```bash
./linux/dev.sh              # ou : ./linux/dev.sh all  — tout installer (défaut)
./linux/dev.sh frontend     # NVM, bun + paquets de base
./linux/dev.sh backend      # PostgreSQL, rôle/base dev, PHP + base
./linux/dev.sh mobile       # JDK 21, Android Studio, Flutter ; SDK CLI si variable ci‑dessous
./linux/dev.sh help         # aide résumée
```

#### Exemples avec variables d’environnement

```bash
# SDK Android en ligne de commande + acceptation des licences Flutter
DEV_INSTALL_ANDROID_SDK=1 DEV_ACCEPT_ANDROID_LICENSES=1 ./linux/dev.sh mobile

# Installation complète sans modifier .bashrc / .zshrc
DEV_SKIP_SHELL_RC=1 ./linux/dev.sh all

# Ne pas créer l’utilisateur / la base PostgreSQL « dev » / « devdb »
DEV_SKIP_POSTGRES_SETUP=1 ./linux/dev.sh backend

# NVM : dernier tag publié sur GitHub (sinon repli interne sur v0.40.1)
NVM_INSTALL_TAG=latest ./linux/dev.sh frontend

# Forcer Android Studio en archive .tar.gz (ex. Debian sans snap fiable)
DEV_ANDROID_STUDIO_USE_TARBALL=1 ./linux/dev.sh all
```

Les variables détaillées (`FLUTTER_ROOT`, `POSTGRES_DEV_USER`, `ANDROID_API`, URLs des outils Google, etc.) sont documentées dans **l’en-tête** de `linux/dev.sh`.

#### Après `linux/dev.sh`

- Ouvre un **nouveau terminal** ou `source ~/.bashrc` / `~/.zshrc` pour prendre en compte les blocs PATH (Flutter, bun, Android SDK si installé).
- **Node** : `source ~/.nvm/nvm.sh` puis `nvm install --lts` (NVM n’installe pas Node tout seul).
- **SDK Android complet** en mode `all` : activer `DEV_INSTALL_ANDROID_SDK=1` (sinon seul Android Studio / Flutter restent possibles, avec compléments manuels).

---

## macOS

### Installation simple — `macOS/setup.sh`

Installe **Homebrew** si nécessaire, puis enchaîne : outils CLI, PostgreSQL (service Homebrew), casks VS Code et Android Studio, OpenJDK 21, PHP, NVM, bun, Flutter dans `~/flutter`.

```bash
./macOS/setup.sh
```

Après coup : nouveau terminal ou `eval "$(brew shellenv)"`, puis `source ~/.nvm/nvm.sh` et `nvm install --lts` si tu utilises Node ; ajoute `~/flutter/bin` au `PATH` dans `~/.zshrc` si besoin.

---

## Outils visés (liste d’ensemble)

Les scripts installent une sélection parmi : **Git**, **Vim**, **HTTPie**, **PostgreSQL**, **Visual Studio Code**, **Android Studio**, **NVM**, **bun**, **PHP**, **JDK 21**, **Flutter**, et éventuellement les **outils Android en CLI** (`dev.sh` + `DEV_INSTALL_ANDROID_SDK=1`).

Les versions exactes dépendent des dépôts (`apt`, Homebrew, canaux snap/cask) et des scripts officiels (NVM, bun, Flutter).

---

## Dépannage rapide

- **Permission denied** : `chmod +x` sur le script concerné.
- **Mauvais OS** : utiliser le dossier `linux/` ou `macOS/` qui correspond à la machine.
- **Échec réseau / 404** (archives Google, zip command line tools) : mettre à jour les URLs dans les variables prévues à cet effet (voir en-tête de `linux/dev.sh`).
- **PostgreSQL** : sous Linux, le service doit tourner et `sudo` doit permettre `sudo -u postgres …`. Sous macOS avec Homebrew, utiliser `brew services start postgresql` si la connexion échoue.

---

## Licence

Voir le dépôt Git du projet (fichier `LICENSE` s’il est présent).
