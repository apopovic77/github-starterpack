# Claude Code Configuration

Dieses `.claude/` Verzeichnis enthält projekt-spezifische Instructions für Claude Code.

## Dateien

### `PROJECT.md`
Wird automatisch von Claude Code geladen wenn du in diesem Projekt arbeitest.

Enthält:
- Projekt-Struktur & Übersicht
- Wie Templates funktionieren
- Workflow für Änderungen
- Testing & Troubleshooting
- Wichtige Regeln

## Globale Instructions

Zusätzlich zu diesem projekt-spezifischen Setup gibt es globale Instructions:

**Location:** `~/.claude/CLAUDE.md`

Diese gelten für ALLE Projekte und enthalten:
- Server Infrastructure (arkturian.com, arkserver)
- DevOps Workflow (./devops commands)
- Wie neue Projekte erstellt werden
- SSH Setup
- Git Workflow
- Commit Message Format

## Wie es funktioniert

Wenn Claude Code in einem Projekt gestartet wird:

1. **Lädt globale Instructions:** `~/.claude/CLAUDE.md`
2. **Lädt projekt-spezifische Instructions:** `.claude/PROJECT.md` (falls vorhanden)
3. **Kombiniert beide** für vollständigen Kontext

Das bedeutet:
- ✅ Claude kennt IMMER deine Server-Infrastruktur
- ✅ Claude kennt IMMER den DevOps Workflow
- ✅ Claude kennt ZUSÄTZLICH projekt-spezifische Details

## Verwendung

Einfach Claude Code im Projekt starten:

```bash
cd /Volumes/DatenAP/Code/github-starterpack
# Claude Code öffnen
```

Claude wird automatisch wissen:
- Dass dies das DevOps Framework Repo ist
- Wie Templates funktionieren
- Wie Updates zu anderen Projekten deployed werden
- Welche Files wichtig sind

## Für andere Projekte

Du kannst `.claude/PROJECT.md` in jedem Projekt anlegen:

```bash
cd /Volumes/DatenAP/Code/mein-projekt
mkdir -p .claude
nano .claude/PROJECT.md
```

Beispiel Inhalt:
```markdown
# Mein Projekt

**Type:** React Web App
**Deployment:** arkturian.com
**URL:** https://mein-projekt.arkturian.com

## Besonderheiten

- Uses custom API at api.example.com
- Special build configuration for...
- Environment variables: ...

## Commands

...
```

---

**Created:** 2025-11-28
