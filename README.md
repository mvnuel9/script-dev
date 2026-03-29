# Lucky-Scripts

Scripts shell pour installer une **boîte à outils de développement** sur **Linux** (Debian / Ubuntu et dérivés) et **macOS**. Deux niveaux sont proposés sur chaque OS : **simple** (`setup.sh`) et **avancé** (`dev.sh`).

## Contenu du dépôt

| Chemin | Rôle |
|--------|------|
| `linux/setup.sh` | Installation **linéaire** sous Linux : une seule commande, peu d’options. |
| `linux/dev.sh` | Installation **modulaire** Linux : sous-commandes, variables d’environnement, SDK Android en CLI, profils shell, PostgreSQL « dev », snap / archive Android Studio, etc. |
| `macOS/setup.sh` | Même esprit que `linux/setup.sh`, via **Homebrew**. |
| `macOS/dev.sh` | Même esprit que `linux/dev.sh`, via **Homebrew** (casks VS Code / Android Studio, zip **mac** pour les command line tools Android, PostgreSQL géré comme utilisateur local). |

## Choisir un script

- **Nouvelle machine, tout installer vite** → `setup.sh` dans `linux/` ou `macOS/`.
- **Contrôle fin** (front / back / mobile seuls, SDK Android en CLI, PATH dans les profils shell, rôle Postgres `dev`) → `dev.sh` du dossier qui correspond à ton OS (`linux/dev.sh` ou `macOS/dev.sh`).

Les variables d’environnement principales sont les **mêmes idées** sur Linux et macOS ; les détails et URLs spécifiques sont dans **l’en-tête** de chaque `dev.sh`.

---

## Prérequis communs

- **Connexion Internet** (téléchargements `apt`, Homebrew, GitHub, Google, etc.).
- **Git** n’est pas obligatoire pour lancer les scripts : ils peuvent l’installer.
- Lancer les scripts depuis un terminal, depuis la racine du dépôt ou avec le **chemin complet** vers le fichier.

Rendre les scripts exécutables une fois (depuis la racine du dépôt) :

```bash
chmod +x linux/dev.sh linux/setup.sh macOS/dev.sh macOS/setup.sh
```

---

## Linux

Systèmes pris en charge : **Ubuntu**, **Debian**, **Linux Mint**, **Pop!_OS** (détection via `/etc/os-release`).

### Installation simple — `linux/setup.sh`

Enchaîne sans sous-commandes : paquets `apt`, dépôt Microsoft pour VS Code, snap pour Android Studio (sur Ubuntu ; sur Debian l’archive peut être préférable via `linux/dev.sh`), OpenJDK 21 ou Temurin, PHP, NVM (tag fixe `v0.40.1`), bun, clone Flutter stable dans `~/flutter`.

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

- Ouvre un **nouveau terminal** ou `source ~/.bashrc` / `~/.zshrc` pour les blocs PATH (Flutter, bun, Android SDK si installé).
- **Node** : `source ~/.nvm/nvm.sh` puis `nvm install --lts`.
- **SDK Android complet** en mode `all` : utiliser `DEV_INSTALL_ANDROID_SDK=1` (sinon compléments manuels possibles).

---

## macOS

### Installation simple — `macOS/setup.sh`

Installe **Homebrew** si nécessaire, puis : outils CLI, PostgreSQL (service Homebrew), casks VS Code et Android Studio, OpenJDK 21, PHP, NVM, bun, Flutter dans `~/flutter`.

```bash
./macOS/setup.sh
```

Après coup : nouveau terminal ou `eval "$(brew shellenv)"`, puis `source ~/.nvm/nvm.sh` et `nvm install --lts` si tu utilises Node ; ajoute `~/flutter/bin` au `PATH` dans `~/.zshrc` si besoin.

### Installation avancée — `macOS/dev.sh`

Même découpage que sous Linux, avec **Homebrew** : pas de `apt` ni de snap ; **Android Studio** passe par le **cask** ; les **command line tools** du SDK Android utilisent le zip **macOS** (voir `ANDROID_CMDLINE_TOOLS_URL` dans l’en-tête du script si le téléchargement par défaut échoue).

#### Commandes (modes)

```bash
./macOS/dev.sh              # ou : ./macOS/dev.sh all
./macOS/dev.sh frontend
./macOS/dev.sh backend
./macOS/dev.sh mobile       # SDK CLI si DEV_INSTALL_ANDROID_SDK=1
./macOS/dev.sh help
```

#### Exemples avec variables d’environnement

```bash
DEV_INSTALL_ANDROID_SDK=1 DEV_ACCEPT_ANDROID_LICENSES=1 ./macOS/dev.sh mobile
DEV_SKIP_SHELL_RC=1 ./macOS/dev.sh all
DEV_SKIP_POSTGRES_SETUP=1 ./macOS/dev.sh backend
NVM_INSTALL_TAG=latest ./macOS/dev.sh frontend
```

**Particularités macOS** : PostgreSQL est configuré avec `psql` / `createuser` en **utilisateur courant** (pas de `sudo -u postgres`). Les blocs PATH idempotents sont ajoutés à **`~/.zshrc`**, **`~/.bash_profile`** et **`~/.bashrc`** lorsque ces fichiers existent.

La liste complète des variables (`ANDROID_CMDLINE_TOOLS_URL` pour le zip **mac**, etc.) figure dans **l’en-tête** de `macOS/dev.sh`.

#### Après `macOS/dev.sh`

- Nouveau terminal ou `source ~/.zshrc` (ou profil bash utilisé).
- **Node** : `source ~/.nvm/nvm.sh` puis `nvm install --lts`.
- **JDK** : `brew info openjdk@21` pour `JAVA_HOME` ou lien optionnel vers `/Library/Java/JavaVirtualMachines/`.

---

## Outils visés (liste d’ensemble)

Les scripts installent une sélection parmi : **Git**, **Vim**, **HTTPie**, **PostgreSQL**, **Visual Studio Code**, **Android Studio**, **NVM**, **bun**, **PHP**, **JDK 21**, **Flutter**, et éventuellement les **outils Android en CLI** (`dev.sh` + `DEV_INSTALL_ANDROID_SDK=1`).

Les versions exactes dépendent des dépôts (`apt`, Homebrew, snap/cask) et des scripts officiels (NVM, bun, Flutter).

---

## Dépannage rapide

- **Permission denied** : `chmod +x` sur le script concerné.
- **Mauvais OS** : utiliser le dossier `linux/` ou `macOS/` qui correspond à la machine.
- **Échec réseau / 404** (archives Google, zip command line tools) : ajuster les variables d’URL dans l’en-tête de `linux/dev.sh` ou `macOS/dev.sh` (zip **linux** vs **mac**).
- **PostgreSQL** : sous Linux, service actif et `sudo -u postgres` possible. Sous macOS / Homebrew : `brew services start postgresql` si la connexion échoue.

---

## Licence

Voir le dépôt Git du projet (fichier `LICENSE` s’il est présent).
