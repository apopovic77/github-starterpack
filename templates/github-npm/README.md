# NPM Package Templates

GitHub Actions workflows and DevOps scripts for NPM package projects.

## Features

- **Automated NPM Publishing**: Publishes to NPM registry on push to main branch
- **CI/CD Pipeline**: Runs tests and type checks on every push
- **Version Management**: Scripts for semantic versioning (major/minor/patch)
- **Local Publishing**: Test publishing with dry-run mode

## Workflows

### `publish.yml`
Triggered on push to `main` branch. Builds the package and publishes to NPM.

**Required GitHub Secrets:**
- `NPM_TOKEN` - NPM authentication token (get from npmjs.com)

### `dev.yml`
Triggered on push to `dev` branch. Runs CI checks (build, test, type-check).

## DevOps Scripts

### `publish-npm.sh`
Publishes the package to NPM registry.

```bash
# Dry run (test without publishing)
./devops/scripts/publish-npm.sh --dry-run

# Actual publish
./devops/scripts/publish-npm.sh
```

### `version-bump.sh`
Bumps package version and creates git tag.

```bash
# Patch version (1.0.0 → 1.0.1)
./devops/scripts/version-bump.sh patch

# Minor version (1.0.0 → 1.1.0)
./devops/scripts/version-bump.sh minor

# Major version (1.0.0 → 2.0.0)
./devops/scripts/version-bump.sh major
```

## Setup Instructions

1. **Install templates** using `setup-devops.sh` from the starterpack
2. **Configure NPM token**:
   ```bash
   npm login
   # Then add NPM_TOKEN to GitHub Secrets
   ```
3. **Set package.json** fields:
   - `name`: Package name (e.g., `@scope/package-name`)
   - `version`: Initial version (e.g., `1.0.0`)
   - `main`: Entry point (e.g., `dist/index.js`)
   - `types`: TypeScript definitions (e.g., `dist/index.d.ts`)
   - `files`: Files to include in package (e.g., `["dist", "src"]`)

4. **Test locally**:
   ```bash
   npm run build
   npm pack --dry-run
   ```

5. **Publish workflow**:
   ```bash
   # Bump version
   ./devops/scripts/version-bump.sh patch
   
   # Push to trigger release
   git push && git push --tags
   
   # Or use the release script
   ./devops release
   ```

## Package.json Requirements

Your `package.json` should include:

```json
{
  "name": "@scope/package-name",
  "version": "1.0.0",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "files": ["dist", "src"],
  "scripts": {
    "build": "tsc",
    "test": "jest",
    "prepublishOnly": "npm run build"
  }
}
```

## NPM Token Setup

1. Go to [npmjs.com](https://www.npmjs.com/)
2. Settings → Access Tokens → Generate New Token
3. Choose "Automation" type
4. Copy the token
5. Add to GitHub: Repo → Settings → Secrets → Actions → New secret
   - Name: `NPM_TOKEN`
   - Value: `npm_xxxxxxxxxxxx`

## Publishing Scoped Packages

For scoped packages (`@scope/package`), ensure your `package.json` has:

```json
{
  "name": "@scope/package-name",
  "publishConfig": {
    "access": "public"
  }
}
```

Or publish with `--access public` flag (already included in scripts).

---

## Complete Setup Guide: Creating a New NPM Package

Vollständige Anleitung zum Erstellen eines neuen npm Packages mit automatischem Publishing.

### 1. NPM Token einmalig einrichten (falls noch nicht vorhanden)

Der NPM_TOKEN wird **nur einmal** erstellt und kann für alle Packages wiederverwendet werden.

#### NPM Token erstellen:

```bash
# Option 1: Token-Seite direkt öffnen
open "https://www.npmjs.com/settings/arkturian/tokens"

# Option 2: Neuen Token generieren
# 1. Gehe zu npmjs.com → Settings → Access Tokens
# 2. "Generate New Token" → "Classic Token"
# 3. Name: "GitHub Actions - Automation"
# 4. Type: "Automation" (wichtig für CI/CD!)
# 5. Token kopieren (startet mit npm_...)
```

#### Token speichern (3 Orte für Wiederverwendung):

```bash
# 1. In ~/.npmrc für lokale npm CLI
echo "//registry.npmjs.org/:_authToken=npm_YOUR_TOKEN_HERE" > ~/.npmrc
chmod 600 ~/.npmrc

# 2. In macOS Keychain als Backup
security add-generic-password -a "$USER" -s "npm_token" -w "npm_YOUR_TOKEN_HERE"

# 3. In GitHub Secrets (pro Repository) - siehe unten
```

**Wichtig**: Token wird mit anderen Projekten geteilt! Einmal erstellt, für immer nutzbar.

---

### 2. Projekt-Setup und Package-Konfiguration

#### 2.1 Repository erstellen

```bash
# Neue Repository mit gh CLI erstellen
cd /path/to/your/project
gh repo create username/package-name --public --source=. --remote=origin

# Oder manuell auf GitHub erstellen und dann:
git remote add origin git@github.com:username/package-name.git
```

#### 2.2 package.json konfigurieren

**WICHTIG**: Arkturian Packages verwenden **KEIN** `@arkturian/` Scope!

✅ **Richtig**: `arkturian-package-name`
❌ **Falsch**: `@arkturian/package-name`

Minimale `package.json` Konfiguration:

```json
{
  "name": "arkturian-package-name",
  "version": "1.0.0",
  "description": "Package description",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "files": [
    "dist",
    "src",
    "README.md"
  ],
  "scripts": {
    "build": "tsc",
    "dev": "tsc --watch",
    "test": "echo \"No tests yet\" && exit 0",
    "prepublishOnly": "npm run build"
  },
  "keywords": [
    "keyword1",
    "keyword2"
  ],
  "author": "Arkturian <hello@arkturian.com>",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/username/package-name"
  },
  "publishConfig": {
    "access": "public"
  },
  "peerDependencies": {
    // Optional: Packages die der User installieren muss
  },
  "dependencies": {
    // Runtime dependencies
  },
  "devDependencies": {
    "typescript": "^5.0.0"
    // Build tools
  }
}
```

#### 2.3 TypeScript konfigurieren (falls TypeScript)

`tsconfig.json` für Library:

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "lib": ["ES2020"],
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "outDir": "./dist",
    "rootDir": "./src",
    "removeComments": true,
    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true,
    "strict": true,
    "skipLibCheck": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "**/*.test.ts"]
}
```

#### 2.4 src/index.ts - Public API definieren

```typescript
// src/index.ts - Nur exports die public sein sollen!
export { MyClass } from './MyClass';
export { myFunction } from './utils';
export type { MyType } from './types';
```

---

### 3. GitHub Actions Workflow einrichten

#### 3.1 Workflow-Datei erstellen

```bash
mkdir -p .github/workflows
```

`.github/workflows/publish.yml`:

```yaml
name: Publish NPM Package

on:
  push:
    branches:
      - main
  workflow_dispatch:

jobs:
  publish:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          registry-url: 'https://registry.npmjs.org'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build package
        run: npm run build

      - name: Run tests
        run: npm test
        continue-on-error: true

      - name: Publish to NPM
        run: npm publish --access public
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}

      - name: Notify on success
        if: success()
        run: echo "✅ Package published successfully"

      - name: Notify on failure
        if: failure()
        run: echo "❌ Package publishing failed"
```

#### 3.2 NPM_TOKEN in GitHub Secrets setzen

```bash
# Mit gh CLI:
gh secret set NPM_TOKEN --body "npm_YOUR_TOKEN_HERE" --repo username/package-name

# Oder manuell:
# GitHub → Repository → Settings → Secrets and variables → Actions → New repository secret
# Name: NPM_TOKEN
# Value: npm_YOUR_TOKEN_HERE
```

#### 3.3 Workflow testen

```bash
# Secret verifizieren
gh secret list --repo username/package-name

# Sollte anzeigen:
# NPM_TOKEN  Updated YYYY-MM-DD
```

---

### 4. Erstes npm Publish (Manuell)

Bevor der Workflow läuft, Package einmal manuell publishen:

```bash
# 1. Build testen
npm run build

# 2. Dry-run (zeigt was published würde, ohne zu publishen)
npm publish --access public --dry-run

# 3. Tatsächlich publishen
npm publish --access public

# 4. Verifizieren
npm view arkturian-package-name

# 5. Package-Seite öffnen
open "https://www.npmjs.com/package/arkturian-package-name"
```

**Erwartetes Ergebnis**:
```
arkturian-package-name@1.0.0 | MIT | deps: X | versions: 1
Description here
https://github.com/username/package-name#readme
...
published just now by your_username
```

---

### 5. Workflow zu GitHub pushen

```bash
# 1. Alle Änderungen committen
git add .
git commit -m "Add GitHub Actions workflow for automated npm publishing"

# 2. Zu GitHub pushen
git push origin main

# 3. Workflow-Status prüfen
gh run list --repo username/package-name --limit 5

# 4. Details anschauen (wenn Fehler)
gh run view --repo username/package-name
```

**Erster Workflow wird fehlschlagen** mit:
```
npm error 403 - You cannot publish over the previously published versions: 1.0.0.
```

Das ist **normal und korrekt**! Der Workflow funktioniert, aber Version 1.0.0 existiert bereits.

---

### 6. Zukünftige Updates publishen

Ab jetzt läuft alles automatisch:

#### 6.1 Version erhöhen

```bash
# In package.json die Version ändern:
# "version": "1.0.0" → "1.0.1"  (Patch - Bugfixes)
# "version": "1.0.0" → "1.1.0"  (Minor - neue Features)
# "version": "1.0.0" → "2.0.0"  (Major - Breaking Changes)

# Oder mit npm:
npm version patch  # 1.0.0 → 1.0.1
npm version minor  # 1.0.0 → 1.1.0
npm version major  # 1.0.0 → 2.0.0
```

#### 6.2 Code ändern, committen, pushen

```bash
# Code ändern...

# Committen
git add .
git commit -m "Add new feature"

# Pushen → triggert automatisch GitHub Actions → published zu npm
git push origin main

# Workflow verfolgen
gh run watch
```

#### 6.3 Publish verifizieren

```bash
# Nach ~30 Sekunden:
npm view arkturian-package-name

# Sollte neue Version anzeigen:
# latest: 1.0.1
```

---

### 7. README.md Vorlage

Dein Package sollte ein gutes README haben:

```markdown
# arkturian-package-name

One-line description of what your package does.

## Features

- Feature 1
- Feature 2
- Feature 3

## Installation

\`\`\`bash
npm install arkturian-package-name
\`\`\`

## Quick Start

\`\`\`typescript
import { MyClass } from 'arkturian-package-name';

const instance = new MyClass();
instance.doSomething();
\`\`\`

## API Reference

### MyClass

Description...

\`\`\`typescript
const instance = new MyClass(options);
\`\`\`

## License

MIT

## Author

Arkturian <hello@arkturian.com>
```

---

### 8. Troubleshooting

#### Problem: "You cannot publish over the previously published versions"

**Lösung**: Version in `package.json` erhöhen

#### Problem: "npm error code E403"

**Lösung**: NPM_TOKEN prüfen:
```bash
# Token in GitHub Secrets verifizieren
gh secret list --repo username/package-name

# Token lokal testen
npm whoami  # Sollte deinen Username anzeigen
```

#### Problem: Workflow läuft nicht

**Lösung**:
```bash
# 1. Workflow-Datei prüfen
cat .github/workflows/publish.yml

# 2. Workflow-Runs anschauen
gh run list --repo username/package-name

# 3. Details zu fehlgeschlagenem Run
gh run view <RUN_ID> --log
```

#### Problem: Package nicht gefunden nach Publish

**Lösung**: Warte 1-2 Minuten, npm braucht Zeit zum Propagieren:
```bash
sleep 60
npm view arkturian-package-name
```

---

### 9. Best Practices

#### 9.1 Naming Convention

- ✅ `arkturian-package-name` (kebab-case, kein Scope)
- ❌ `@arkturian/package-name` (kein Scope für Arkturian!)
- ❌ `arkturianPackageName` (kein camelCase)

#### 9.2 Semantic Versioning

- **Patch** (1.0.0 → 1.0.1): Bugfixes, keine neuen Features
- **Minor** (1.0.0 → 1.1.0): Neue Features, backwards compatible
- **Major** (1.0.0 → 2.0.0): Breaking Changes

#### 9.3 Files to include

In `package.json` nur nötige Dateien inkludieren:
```json
{
  "files": [
    "dist",      // ✅ Compiled code
    "src",       // ✅ Source code (optional, für debugging)
    "README.md"  // ✅ Documentation
    // ❌ NICHT: node_modules, .git, tests
  ]
}
```

#### 9.4 Dependencies vs DevDependencies

```json
{
  "dependencies": {
    // Runtime dependencies - wird mit installiert
    "package-needed-at-runtime": "^1.0.0"
  },
  "devDependencies": {
    // Build tools - wird NICHT mit installiert
    "typescript": "^5.0.0",
    "@types/node": "^20.0.0"
  },
  "peerDependencies": {
    // User muss selbst installieren
    "react": "^18.0.0"
  }
}
```

---

### 10. Checklist für neues Package

```bash
# Vor dem ersten Publish:
[ ] package.json korrekt konfiguriert (Name, Version, Main, Types)
[ ] tsconfig.json für Library setup (declaration: true)
[ ] src/index.ts exportiert public API
[ ] README.md vorhanden
[ ] .gitignore enthält node_modules/, dist/
[ ] npm run build funktioniert
[ ] npm publish --dry-run zeigt korrekten Inhalt

# Für GitHub Actions:
[ ] .github/workflows/publish.yml erstellt
[ ] NPM_TOKEN in GitHub Secrets gesetzt
[ ] GitHub Repository erstellt und connected

# Nach erstem Publish:
[ ] Package auf npmjs.com sichtbar
[ ] npm view arkturian-package-name funktioniert
[ ] npm install arkturian-package-name funktioniert
[ ] GitHub Actions Workflow läuft (auch wenn 403 Fehler)

# Für Updates:
[ ] Version in package.json erhöht
[ ] CHANGELOG.md aktualisiert (optional)
[ ] git commit und push
[ ] GitHub Actions published automatisch
```

---

### 11. Beispiel-Packages

Schau dir diese Arkturian Packages als Referenz an:

- `arkturian-typescript-utils` - Utilities (keine React Abhängigkeit)
- `arkturian-storage-sdk` - API SDK
- `arkturian-canvas-engine` - React Library mit Canvas Rendering
- `react-asset-preloader` - React Component Library

```bash
# Pakete anschauen
npm view arkturian-typescript-utils
npm view arkturian-canvas-engine

# Struktur inspizieren
npm pack arkturian-typescript-utils --dry-run
```

