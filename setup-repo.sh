#!/usr/bin/env bash
#
# setup-repo.sh - Configure un repo selon la convention ArteBeaute
#
# Usage : depuis la racine du repo cible, exécuter :
#   /Users/wilfrid/artebeaute-template/setup-repo.sh
#
set -euo pipefail

TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(pwd)"
cd "$REPO_DIR"

GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
NC="\033[0m"

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERR]${NC} $*"; }

SUMMARY=()
COPIED_FILES=()
add_summary() { SUMMARY+=("$1"); }

# 1. Verifier que gh cli est installe
info "Verification de gh cli..."
if ! command -v gh >/dev/null 2>&1; then
  err "gh cli n'est pas installe. Installation : brew install gh"
  exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
  err "gh cli n'est pas authentifie. Lancez : gh auth login"
  exit 1
fi
ok "gh cli OK"
add_summary "gh cli verifie"

# Verifier qu'on est dans un repo git
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  err "Le dossier courant n'est pas un repo git : $REPO_DIR"
  exit 1
fi

# 2. Copier les fichiers du template
info "Copie des fichiers de configuration ArteBeaute..."

copy_file() {
  local src="$1"
  local dst="$2"
  if [[ ! -f "$src" ]]; then
    err "Source introuvable : $src"
    return 1
  fi
  mkdir -p "$(dirname "$dst")"
  if [[ -f "$dst" ]]; then
    if cmp -s "$src" "$dst"; then
      ok "$dst deja a jour"
      add_summary "Fichier deja a jour : $dst"
    else
      cp "$src" "$dst"
      ok "$dst remplace"
      add_summary "Fichier mis a jour : $dst"
    fi
  else
    cp "$src" "$dst"
    ok "$dst cree"
    add_summary "Fichier cree : $dst"
  fi
  COPIED_FILES+=("$dst")
}

copy_file "$TEMPLATE_DIR/.releaserc.json"            "$REPO_DIR/.releaserc.json"
copy_file "$TEMPLATE_DIR/.github/workflows/release.yml" "$REPO_DIR/.github/workflows/release.yml"

# CLAUDE.md : ne pas ecraser s'il existe deja (specifique au repo)
if [[ -f "$REPO_DIR/CLAUDE.md" ]]; then
  warn "CLAUDE.md existe deja, conserve tel quel"
  add_summary "CLAUDE.md conserve (existait deja)"
else
  cp "$TEMPLATE_DIR/CLAUDE.md" "$REPO_DIR/CLAUDE.md"
  ok "CLAUDE.md cree depuis le template"
  add_summary "CLAUDE.md cree depuis le template"
fi

# 2bis. Verifier package.json et installer les dependances semantic-release
info "Verification de package.json et dependances semantic-release..."
INITIAL_PKG_VERSION=""
FINAL_PKG_VERSION=""
if [[ -f "$REPO_DIR/package.json" ]]; then
  INITIAL_PKG_VERSION=$(node -e "console.log(require('$REPO_DIR/package.json').version || '')" 2>/dev/null || echo "")
  if [[ -n "$INITIAL_PKG_VERSION" ]]; then
    info "Version actuelle de package.json : $INITIAL_PKG_VERSION (ne sera pas modifiee par ce script)"
  fi
  SR_DEPS=(
    semantic-release
    @semantic-release/commit-analyzer
    @semantic-release/release-notes-generator
    @semantic-release/changelog
    @semantic-release/git
    @semantic-release/github
  )
  MISSING_DEPS=()
  for DEP in "${SR_DEPS[@]}"; do
    if ! node -e "const p=require('$REPO_DIR/package.json'); process.exit((p.devDependencies && p.devDependencies['$DEP']) ? 0 : 1)" 2>/dev/null; then
      MISSING_DEPS+=("$DEP")
    fi
  done
  if [[ ${#MISSING_DEPS[@]} -eq 0 ]]; then
    ok "Toutes les dependances semantic-release sont deja dans devDependencies"
    add_summary "Dependances semantic-release : deja presentes"
  else
    info "Installation des dependances manquantes : ${MISSING_DEPS[*]}"
    (cd "$REPO_DIR" && npm install --save-dev --legacy-peer-deps "${MISSING_DEPS[@]}")
    ok "Dependances semantic-release installees"
    add_summary "Dependances semantic-release installees : ${MISSING_DEPS[*]}"
  fi
else
  warn "package.json absent, installation semantic-release skippee"
  add_summary "package.json absent : deps semantic-release non installees"
fi

# 3. VERSION_BUILD : creer si absent avec valeur 1
if [[ -f "$REPO_DIR/VERSION_BUILD" ]]; then
  ok "VERSION_BUILD existe deja (valeur : $(cat "$REPO_DIR/VERSION_BUILD"))"
  add_summary "VERSION_BUILD conserve"
else
  echo "1" > "$REPO_DIR/VERSION_BUILD"
  ok "VERSION_BUILD cree avec valeur 1"
  add_summary "VERSION_BUILD cree (valeur 1)"
fi

# 4. Creer la branche develop si elle n'existe pas
info "Verification de la branche develop..."
if git show-ref --verify --quiet refs/heads/develop; then
  ok "Branche develop existe deja en local"
  add_summary "Branche develop : deja presente"
else
  if git ls-remote --exit-code --heads origin develop >/dev/null 2>&1; then
    git fetch origin develop:develop
    ok "Branche develop recuperee depuis origin"
    add_summary "Branche develop recuperee depuis origin"
  else
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    git branch develop
    ok "Branche develop creee depuis $CURRENT_BRANCH"
    add_summary "Branche develop creee en local"
  fi
fi

# 5. Verifier que .env est dans .gitignore
info "Verification de .gitignore..."
if [[ ! -f "$REPO_DIR/.gitignore" ]]; then
  echo ".env" > "$REPO_DIR/.gitignore"
  ok ".gitignore cree avec .env"
  add_summary ".gitignore cree avec .env"
elif grep -qE '^\.env$|^\.env[[:space:]]*$' "$REPO_DIR/.gitignore"; then
  ok ".env est deja dans .gitignore"
  add_summary ".gitignore : .env deja present"
else
  echo "" >> "$REPO_DIR/.gitignore"
  echo ".env" >> "$REPO_DIR/.gitignore"
  ok ".env ajoute au .gitignore"
  add_summary ".env ajoute au .gitignore"
fi

# 6. Configurer les secrets GitHub
info "Configuration des secrets GitHub..."
SECRETS=(GH_PAT ZAMMAD_URL ZAMMAD_API_TOKEN DOCKERHUB_USERNAME DOCKERHUB_TOKEN)

REPO_SLUG=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
if [[ -z "$REPO_SLUG" ]]; then
  warn "Repo GitHub non detecte (pas de remote ou repo non cree)."
  warn "Skippe la configuration des secrets. Lancez gh repo create puis relancez."
  add_summary "Secrets GitHub : non configures (repo distant introuvable)"
else
  info "Repo distant : $REPO_SLUG"
  EXISTING_SECRETS=$(gh secret list --repo "$REPO_SLUG" --json name -q '.[].name' 2>/dev/null || echo "")
  for SECRET in "${SECRETS[@]}"; do
    if echo "$EXISTING_SECRETS" | grep -qx "$SECRET"; then
      ok "Secret $SECRET deja configure"
      add_summary "Secret $SECRET : deja present"
      continue
    fi
    echo ""
    read -r -s -p "Valeur pour $SECRET (vide pour skipper) : " VALUE
    echo ""
    if [[ -z "$VALUE" ]]; then
      warn "$SECRET skippe"
      add_summary "Secret $SECRET : skippe"
    else
      echo -n "$VALUE" | gh secret set "$SECRET" --repo "$REPO_SLUG" --body -
      ok "Secret $SECRET configure"
      add_summary "Secret $SECRET : configure"
    fi
  done
fi

# 7. Commit chore(release): setup convention ArteBeaute
info "Creation du commit..."
git add .releaserc.json .github/workflows/release.yml CLAUDE.md VERSION_BUILD .gitignore 2>/dev/null || true
if git diff --cached --quiet; then
  warn "Aucun changement a committer"
  add_summary "Commit : aucun changement"
else
  git commit -m "chore(release): setup convention ArteBeaute"
  ok "Commit cree"
  add_summary "Commit chore(release): setup convention ArteBeaute"
fi

# 7bis. Verifier que la version de package.json n'a pas ete modifiee
if [[ -f "$REPO_DIR/package.json" ]]; then
  FINAL_PKG_VERSION=$(node -e "console.log(require('$REPO_DIR/package.json').version || '')" 2>/dev/null || echo "")
  if [[ -n "$INITIAL_PKG_VERSION" && "$INITIAL_PKG_VERSION" != "$FINAL_PKG_VERSION" ]]; then
    err "package.json.version a change : $INITIAL_PKG_VERSION -> $FINAL_PKG_VERSION (bug du script)"
    add_summary "package.json : version MODIFIEE ($INITIAL_PKG_VERSION -> $FINAL_PKG_VERSION) - ANOMALIE"
  elif [[ -n "$FINAL_PKG_VERSION" ]]; then
    ok "package.json.version inchangee : $FINAL_PKG_VERSION"
    add_summary "package.json.version : $FINAL_PKG_VERSION (inchangee)"
  fi
fi

# 8. Resume
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  RESUME setup-repo ArteBeaute${NC}"
echo -e "${GREEN}========================================${NC}"
for line in "${SUMMARY[@]}"; do
  echo "  - $line"
done

if [[ ${#COPIED_FILES[@]} -gt 0 ]]; then
  echo ""
  echo -e "${GREEN}Fichiers copies depuis le template :${NC}"
  for f in "${COPIED_FILES[@]}"; do
    echo "  - $f"
  done
fi
echo ""
ok "Setup termine pour : $REPO_DIR"
