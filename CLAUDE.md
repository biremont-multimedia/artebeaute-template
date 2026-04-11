# CLAUDE.md

## Stack technique

<!-- A completer pour chaque repo ArteBeaute -->

## Convention de branches

| Branche | Rôle |
|---------|------|
| `main` | Production, protégée, releases automatiques via semantic-release |
| `develop` | Intégration, protégée |
| `feature/YYYYMM-xxx` | Nouvelle fonctionnalité (ex: `feature/202604-gmail-sync`) |
| `fix/YYYYMM-xxx` | Correction de bug |
| `hotfix/YYYYMM-xxx` | Correctif urgent en production |

## Convention de commits (Conventional Commits)

Format : `type(scope): description`

| Type | Usage |
|------|-------|
| `feat` | Nouvelle fonctionnalité |
| `fix` | Correction de bug |
| `chore` | Maintenance, dépendances, CI |
| `docs` | Documentation |
| `refactor` | Refactoring sans changement fonctionnel |
| `test` | Ajout ou modification de tests |

## Versioning automatique (semantic-release)

Le versioning suit SemVer et est déclenché automatiquement sur merge dans `main` :

- `fix:` -> bump **PATCH** (1.0.x)
- `feat:` -> bump **MINOR** (1.x.0)
- `feat!:` ou `BREAKING CHANGE:` dans le footer -> bump **MAJOR** (x.0.0)

Les commits `chore`, `docs`, `refactor`, `test` ne déclenchent pas de release.

## Regles de workflow

- **Ne jamais pousser directement sur `main` ou `develop`** : toujours passer par une Pull Request.
- **Toujours utiliser `git worktree`** pour travailler sur les branches feature, fix et hotfix. Cela permet de garder le worktree principal propre et de travailler sur plusieurs branches en parallele.
