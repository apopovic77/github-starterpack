## studio-test: Agenten-Tests auf studio statt auf arkserver

Issue #3999, Auftrag Alex in Post 6490. Agenten auf arkserver starten Tests mit einem Befehl. Der
Arbeitsbaum geht per rsync an studio, ohne Commit. Die Tests laufen dort, Ausgabe und Rückgabewert
kommen zurück wie bei einem lokalen Lauf. Ist studio nicht erreichbar oder voll, läuft der Test
gedrosselt auf arkserver.

```mermaid
sequenceDiagram
  participant A as Agent (arkserver)
  participant C as studio-test
  participant S as studio-ci (studio, agentos-ci)
  A->>C: ./devops test -- tests/test_x.py
  C->>S: rsync nur Änderungen (ohne .git, node_modules, .venv, .env, Schlüssel)
  S->>S: Platz in der Schlange (höchstens 3), Abhängigkeiten aus dem Cache
  S->>S: Testbefehl mit nice 10 und Zeitlimit
  S-->>C: Ausgabe live, Rückgabewert
  C-->>A: wie lokal, Log unter ~/.cache/studio-test/
```

**Wofür, und wofür nicht:** `studio-test` ist für schnelle Rückmeldung beim Entwickeln da. Sein
Ergebnis entscheidet nie über `main` oder ein Release. Die Suite des Release-Takts läuft weiter auf den
Runnern am Kern. Grund: Bauen und Testen laufen auf studio unter demselben Benutzer, ein Test kann
die geteilten Caches verändern und einem späteren Lauf ein falsches Grün liefern.

### Benutzung

```bash
./devops test                         # ganze Suite nach Konfiguration
./devops test -- tests/test_x.py -x   # Argumente gehen an den Testbefehl
./devops test --detach                # Lauf-ID, nicht warten
studio-test status <lauf-id>          # Stand
studio-test log <lauf-id>             # volles Log
studio-test --local                   # gleich auf arkserver, gedrosselt
studio-test ping                      # studio erreichbar, Plätze belegt
```

Rückgabewerte: der des Tests; 124 bei Zeitlimit; Rückfall auf arkserver bei rc 255 (keine Verbindung)
oder 75 (alle Plätze länger als `TEST_WAIT` belegt).

### Konfiguration je Repo

`.devops/studio-test.conf`, alles optional:

```ini
TEST_DIR=backend
TEST_SETUP=python
TEST_CMD=python -m pytest -q -n 8
TEST_PIP=pytest-asyncio==1.3.0 greenlet
TEST_WAIT=600
```

`TEST_PIP` sind zusätzliche Pakete für die Python-Umgebung auf studio. Erlaubt sind nur Paketnamen,
optional mit Extras und Versionsangabe, keine Optionen, URLs oder Pfade. Sie fließen in den
Cache-Schlüssel ein.

Ohne Datei: `requirements.txt` ergibt Python mit `python -m pytest -q`, eine `package.json` mit
`test`-Skript ergibt Node mit `npm test --`.

### Abgleich mit Produktion (Python)

Gibt es auf arkserver eine Produktions-venv des Repos (`/var/www/<repo>/venv`, `.venv` oder
`/var/www/<repo>.arkturian.com/venv`; der Name kommt aus der Adresse von `origin`), schickt
`studio-test` ihre Python-Version und ihre Paketversionen als `.studio-test/` mit. studio-ci baut die
Umgebung dann mit derselben Python-Version (falls auf studio vorhanden) und den Versionen als
`pip -c`-Vorgabe. Braucht der Arbeitsstand neuere Pakete als Produktion, löst pip die Vorgabe nicht
auf. Dann baut studio-ci ohne Vorgabe und schreibt einen Hinweis in die Ausgabe.

- `TEST_PROD_VENV=/pfad/zur/venv` nimmt eine bestimmte venv, `TEST_PROD_VENV=aus` schaltet den
  Abgleich ab.
- Liegt die Produktion nicht auf arkserver, gehören die Versionen als `requirements.lock` ins Repo.
  Das ist ohnehin der gründlichere Weg.

### Testabhängigkeiten

- **Python:** `pytest` und `pytest-xdist` sind immer dabei. Was die Tests sonst brauchen, etwa
  `pytest-asyncio`, gehört in `requirements-test.txt` oder `requirements-dev.txt` neben
  `requirements.txt` oder in `TEST_PIP`. Alles fließt in den Cache-Schlüssel ein.
- **Offene Dateien:** macOS erlaubt einem Prozess standardmäßig 256. studio-ci hebt das je Lauf an
  (bis 65536), sonst brechen größere Suiten mit `Errno 24` ab.
- **Tests, die kein pytest sind** (eigenständige Skripte wie bei issue-api): `TEST_CMD` setzen.
- **Node:** Private Pakete aus GitHub Packages (z. B. `@arkturian/…`) brauchen auf studio einen
  Lese-Token. `.npmrc` geht nie mit. Ohne Token bricht `npm ci` mit 401 ab.

### Was nie mitgeht

`.git` (auch als Datei in einem git worktree), `node_modules`, `.venv`, `venv`, `.env*`, `*.key`, `*.pem`, `*.p12`, `secrets/`,
`.secrets/`, `.npmrc`, `.pypirc`, `*.db`, `*.sqlite*`, `dist/`, `build/` sowie alles aus
`.gitignore`. Dateien über 50 MB werden nicht übertragen. Tests müssen ohne Zugangsdaten laufen.

### Caches auf studio

- **Python:** venv je Hash von `requirements.lock`, `requirements*.txt`, `TEST_PIP` und der Python-Version
  unter `~/ci/cache/venv/`. Gibt es eine `requirements.lock`, wird sie statt `requirements.txt` installiert.
  `pytest` und `pytest-xdist` sind immer dabei.
- **Node:** `npm ci` je Hash von `package.json` und `package-lock.json` unter `~/ci/cache/node/`.
  Der Arbeitsbereich bekommt einen APFS-Klon (`cp -c`), sofort und ohne Platzbedarf. Lokale
  `file:`-Abhängigkeiten (etwa `vendor/*.tgz`) kommen mit und zählen zum Cache-Schlüssel.
- `studio-ci aufraeumen` löscht Läufe nach 7 Tagen sowie Caches und Arbeitsbereiche nach 14 Tagen
  ohne Nutzung.

### Einrichtung auf studio (Cloud-Operator)

1. Benutzer `agentos-ci`: kein Admin, kein Zugriff auf fremde Bereiche. Homebrew-`python3.13`,
   `node`/`npm` und `rsync` 3.x müssen für ihn ausführbar sein.
2. `studio-ci` nach `/Users/agentos-ci/bin/studio-ci`, Besitzer `root:wheel`, Modus `0755`.
3. `~agentos-ci/.ssh/authorized_keys`, Besitzer `root`, für agentos-ci nicht schreibbar:

   ```
   command="/Users/agentos-ci/bin/studio-ci gate",no-port-forwarding,no-agent-forwarding,no-X11-forwarding,no-pty ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIABRw8x5FsuDypgDzOwWBJoWHYeaxp9QE8Ys8crtkLa2 studio-test@arkserver (#3999)
   ```

   Warum root-eigen: Tests führen Code des Repos als agentos-ci aus. Gehören `authorized_keys` oder
   das Gate dem Benutzer, könnte ein Test den Zwangsbefehl entfernen.
4. Optional ein Aufräumen per launchd, täglich `studio-ci aufraeumen`.

### Einrichtung auf arkserver (GitHub)

```bash
sudo install -o root -g root -m 755 devops-tools/studio-test/studio-test /usr/local/bin/studio-test
```

`~/.ssh/config` von alex:

```
Host studio-ci
  HostName localhost
  Port 3342
  User agentos-ci
  ProxyJump arkturian
  IdentityFile ~/.ssh/studio_ci_ed25519
  IdentitiesOnly yes
```

### Git im Arbeitsbereich

`.git` geht nie mit. Damit Tests mit `git ls-files` trotzdem laufen, schickt `studio-test` die Liste
der versionierten Dateien mit (`.studio-test/tracked`). studio-ci baut daraus vor jedem Lauf einen
Git-Index ohne Verlauf. Dateien, die nicht übertragen wurden (etwa `.env`), fehlen darin. `git log`,
`git diff` und `git blame` liefern dort nichts; Tests, die den Verlauf brauchen, gehören auf
`--local`.

### Grenzen

- **Gate:** Es erlaubt nur rsync als Empfänger in `~/ci/ws/<name>/` sowie `studio-ci run|status|log|ping`.
  Es verhindert Shell, Portweiterleitung und Pfade außerhalb von `~/ci`. Ein Test ist trotzdem
  beliebiger Code. Die Trennung zum Rest von studio leistet allein der Benutzer `agentos-ci`.
- **Plattform:** studio ist macOS auf arm64. Tests, die Linux brauchen (systemd, `/proc`, native
  Linux-Pakete), laufen mit `--local` auf arkserver.
- **Mehrere Läufe:** Ein Agent und ein Repo teilen sich einen Arbeitsbereich. Zwei gleichzeitige
  Läufe desselben Agenten im selben Repo warten aufeinander.
