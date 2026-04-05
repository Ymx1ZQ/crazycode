# crazycode — Dev Plan

## M1: Installer script ✅

**Goal:** A single `install.sh` that:
1. Installs crazycode itself (clona il repo in `~/.crazycode/`, aggiunge il source a `~/.bashrc`)
2. Poi, uno per uno, chiede se installare ogni tool opzionale

**UX scelta:** prompt interattivo stile "opt-in per ogni tool" — l'utente vede nome, descrizione di una riga, e risponde `y/N`. Nessun tool viene installato silenziosamente.

**Struttura:**

```
install.sh
  └── fase 1: installa crazycode
        - git clone git@github.com:Ymx1ZQ/crazycode.git ~/.crazycode  (o pull se già esiste)
        - aggiunge `source ~/.crazycode/crazycode.sh` a ~/.bashrc se non già presente
  └── fase 2: tool opzionali (uno per uno)
        - [caffeine]     sudo apt install caffeine
        - [aider]        pipx install aider-chat  (fallback: pip install aider-chat)
        - [claude code]  curl -fsSL https://claude.ai/install.sh | bash
        - [opencode]     npm i -g opencode-ai@latest
        - [codex]        npm i -g @openai/codex
```

**Prerequisiti rilevati automaticamente:**
- `pipx` — se assente, suggerisce `sudo apt install pipx`
- `npm` / Node.js — se assente, suggerisce installazione via nvm
- `git` — se assente, blocca e avvisa

**Tasks:**
- [x] Scrivere `install.sh` con fase 1 (self-install di crazycode)
- [x] Aggiungere prompt interattivo per ogni tool opzionale
- [x] Rilevare prerequisiti (git, pipx, npm) e stampare avvisi chiari
- [x] Rendere lo script idempotente (rieseguibile senza danni)
- [x] Testare su shell pulita (bash -n syntax check)

---

## M2: README ✅

**Goal:** `README.md` che spiega cos'è crazycode, cosa fa ogni opzione del menu, e come installarlo con un solo comando.

**Struttura:**

```
README.md
  ├── Titolo + one-liner descrittivo
  ├── Screenshot / demo (ASCII del menu)
  ├── Quick install (un solo comando che pesca da GitHub)
  │     curl -fsSL https://raw.githubusercontent.com/Ymx1ZQ/crazycode/main/install.sh | bash
  ├── Cosa fa — tabella con ogni opzione del menu
  │     coffeeshot: tiene lo schermo acceso (usa caffeine-indicator)
  │     nosleep:    blocca suspend/hibernate via systemd
  │     aider / claudecode / opencode / codex: launcher AI
  ├── Installazione manuale (alternativa al quickinstall)
  └── Requisiti
```

**Tasks:**
- [x] Scrivere `README.md` con tutte le sezioni
- [x] Includere il quickinstall one-liner (presuppone `install.sh` su main)
- [x] Aggiungere demo ASCII del menu crazycode

---

## M3: Fix awake mode — `systemctl restart systemd-logind` kills the session ✅

**Problema:** Premere `c` per attivare/disattivare awake mode chiama `sudo systemctl restart systemd-logind` (righe 87 e 105 di `crazycode.sh`). Questo **termina tutte le sessioni utente** — il desktop crasha, l'utente viene buttato fuori.

**Obiettivo:** L'awake mode deve tenere il PC sempre attivo per l'utente — niente schermata di login, niente standby, niente lock dello schermo. Il toggle deve funzionare senza distruggere la sessione.

**Fix:**
- Sostituire `systemctl restart systemd-logind` con `sudo systemctl kill -s HUP systemd-logind` che ricarica la config senza killare le sessioni (sia in `enable_awake` che in `disable_awake`)
- Verificare che il segnale HUP sia sufficiente per applicare le modifiche a `logind.conf`

**Tasks:**
- [x] Sostituire `restart` con `kill -s HUP` in `enable_awake`
- [x] Sostituire `restart` con `kill -s HUP` in `disable_awake`
- [x] Testare che il toggle coffeeshot/camomile non uccida la sessione

---

## M4: Fix posizione prompt sudo nel TUI ✅

**Problema:** Quando `enable_awake`/`disable_awake` chiede la password sudo, il prompt appare nella posizione corrente del cursore (in fondo al terminale), non vicino alla riga coffeeshot/camomile. L'utente non capisce cosa sta succedendo.

**Fix:**
- Pre-autenticare sudo prima dei comandi awake: posizionare il cursore sulla riga giusta (sotto coffeeshot/camomile) e fare un `sudo -v` lì, così il prompt della password appare nel posto giusto
- Dopo l'autenticazione, procedere con i comandi sudo (che useranno il token sudo già attivo)

**Tasks:**
- [x] Aggiungere `sudo -v` con cursore posizionato sotto la riga awake prima di chiamare `enable_awake`/`disable_awake`
- [x] Ripulire eventuali artefatti visivi dopo l'inserimento password
- [x] Ridisegnare il menu dopo il toggle

---

## M5: Riga "all tools launch without asking permission" ✅

**Problema:** L'utente non vede che tutti i tool vengono lanciati senza chiedere permessi (es. `--dangerously-skip-permissions`, `--yes-always`, `--sandbox danger-full-access`).

**Fix:**
- Aggiungere una riga informativa in fondo al menu, sotto la riga di help, es:
  `⚠ all tools launch without asking permission`

**Tasks:**
- [x] Aggiungere la riga sotto l'help nel draw del menu
- [x] Assicurarsi che non rompa il posizionamento delle altre righe (aggiornare offset righe)

---

## M6: Installer — default "installa tutto", opt-out ✅

**Problema:** Attualmente `install.sh` chiede `[y/N]` per ogni tool (opt-in). L'utente vuole il contrario: di default installa tutto, l'utente dice `n` solo se non vuole qualcosa.

**Fix:**
- Cambiare il prompt da `[y/N]` a `[Y/n]`
- Invertire la logica: se l'utente preme invio senza scrivere nulla, il tool viene installato

**Tasks:**
- [x] Modificare `_ask()` in `install.sh`: default a `Y`, accettare `n/N` come skip
- [x] Aggiornare il testo del prompt (`Install? [Y/n]`)
- [x] Aggiornare il messaggio introduttivo della fase 2

---

## M7: Ottimizzazioni varie ✅

### M7a: Verifica tool installato prima di lanciare

**Problema:** Quando l'utente preme enter su un tool (es. `aider`), lo script lo lancia direttamente. Se il tool non è installato, l'utente vede un errore bash criptico.

**Fix:** Aggiungere `command -v` check prima del lancio; se manca, mostrare messaggio chiaro con istruzioni di installazione.

### M7b: Trap per cleanup terminale

**Problema:** Se l'utente fa Ctrl+C durante il menu, il terminale potrebbe rimanere in stato sporco (cursore nascosto, echo disabilitato, ecc.).

**Fix:** Aggiungere `trap` per ripristinare il terminale su EXIT/INT/TERM.

### M7c: Evitare sudo ridondanti

**Problema:** `enable_awake` chiama `sudo` per ogni comando. Se il token sudo è scaduto, chiede la password più volte.

**Fix:** Fare un singolo `sudo -v` all'inizio e poi usare il token per tutti i comandi.

### M7d: Caffeine activation — approccio più robusto

**Problema:** Il blocco gdbus (righe 71-82) per attivare caffeine usa il bus KDE (`org.kde.StatusNotifierWatcher`) ed è fragile. Potrebbe non funzionare su GNOME o altri DE.

**Fix:** Considerare alternative più semplici/portabili:
- `xdg-screensaver reset` in un loop
- `xset s off -dpms` come fallback
- Controllare se caffeine ha un CLI per l'attivazione (`caffeine-indicator --activate` o simile)

**Tasks:**
- [x] M7a: Check `command -v` prima di lanciare ogni tool
- [x] M7b: Aggiungere trap per cleanup terminale su EXIT/INT/TERM
- [x] M7c: Singolo `sudo -v` prima dei comandi awake
- [x] M7d: Sostituito gdbus KDE con `xset s off -dpms` (cross-DE) + caffeine-indicator come indicatore visivo

---

## M8: Chiamata programmatica + autocomplete ✅

**Goal:** Poter chiamare `crazycode <subcommand>` direttamente da terminale senza passare dal TUI. Se nessun argomento → mostra il TUI come oggi.

**Subcomandi:**
- `crazycode aider` → lancia aider direttamente
- `crazycode claudecode` → lancia claude code direttamente
- `crazycode opencode` → lancia opencode direttamente
- `crazycode codex` → lancia codex direttamente
- `crazycode coffeeshot` → attiva awake mode (toggle on/off)
- `crazycode status` → mostra stato awake mode senza TUI
- `crazycode --help` → mostra usage con lista comandi

**Autocomplete bash:**
- Funzione `_crazycode_completions` registrata con `complete -F`
- Completa i subcomandi: `aider claudecode opencode codex coffeeshot status --help`
- La registrazione va nel file sorgato (`crazycode.sh`) così è attiva appena caricato

**Installer:**
- L'installer deve installare il file di completamento (o verificare che il source in bashrc lo attivi automaticamente — dato che il complete è dentro `crazycode.sh`, basta il source esistente)

**Tasks:**
- [x] Aggiungere parsing argomenti all'inizio di `crazycode()`: se `$1` è un subcomando noto, eseguire direttamente senza TUI
- [x] Implementare `crazycode coffeeshot` come toggle non-interattivo (stampa stato dopo toggle)
- [x] Implementare `crazycode status` (stampa stato awake mode)
- [x] Implementare `crazycode --help`
- [x] Aggiungere funzione `_crazycode_completions` + `complete -F` alla fine di `crazycode.sh`
- [x] Verificare che l'autocomplete funzioni dopo `source ~/.bashrc`

---

## M9: Miglioramenti grafici / UX del TUI ✅

### M9a: Indicatore tool installati

**Problema:** L'utente non sa quali tool sono installati fino a quando non li seleziona e preme enter.

**Fix:** Mostrare un indicatore accanto a ogni tool nel menu: `✓` se installato, `✗` se mancante (in dim). Usare l'array `cmds` per il check con `command -v`.

### M9b: Navigazione con shortcut diretti

**Problema:** Attualmente si può solo navigare con frecce + enter. Sarebbe comodo premere un tasto per andare direttamente al tool.

**Fix:** Aggiungere shortcut numerici `1-4` per selezionare e lanciare direttamente il tool corrispondente.

### M9c: Stato dettagliato awake mode

**Problema:** Il menu mostra solo "awake mode on/off" ma non quali componenti sono attivi.

**Fix:** Quando awake è parziale (alcuni check passano, altri no), mostrare un indicatore intermedio tipo `[partial]` in giallo, oppure mostrare i singoli stati su hover/espansione.

### M9d: Ridisegno completo su resize terminale

**Problema:** Se l'utente ridimensiona il terminale durante il menu, il layout si rompe.

**Fix:** Aggiungere trap su `WINCH` che ridisegna tutto il menu.

**Tasks:**
- [x] M9a: Aggiungere ✓/✗ accanto a ogni tool nel menu
- [x] M9b: Aggiungere shortcut numerici 1-4 per lancio diretto
- [x] M9c: Mostrare stato parziale awake in giallo `[partial X/4]`
- [x] M9d: Trap WINCH per ridisegno su resize via `draw_all`

---

## M10: Miglioramenti installer

### M10a: Verifica post-install

**Problema:** L'installer non verifica se l'installazione di ogni tool è andata a buon fine. Se un `npm i -g` fallisce silenziosamente, l'utente non lo sa.

**Fix:** Dopo ogni installazione, fare `command -v <tool>` e mostrare ✓ o ✗ con messaggio chiaro. A fine installer, stampare una tabella riassuntiva.

### M10b: Flag `--all` / `--silent`

**Problema:** Per automazione (CI, dotfiles bootstrap), serve un modo per installare tutto senza prompt.

**Fix:** Aggiungere `--all` (installa tutto senza chiedere) e `--silent` (nessun output interattivo, solo errori).

### M10c: Supporto zsh

**Problema:** L'installer modifica solo `~/.bashrc`. Utenti zsh devono farlo manualmente.

**Fix:** Rilevare la shell dell'utente (`$SHELL`) e aggiungere il source al file rc corretto (`~/.bashrc` o `~/.zshrc`).

**Tasks:**
- [ ] M10a: Aggiungere verifica post-install per ogni tool + tabella riassuntiva
- [ ] M10b: Aggiungere flag `--all` e `--silent`
- [ ] M10c: Rilevare shell e supportare zsh
