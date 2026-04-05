# crazycode — Dev Plan

## M1: Installer script

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
- [ ] Scrivere `install.sh` con fase 1 (self-install di crazycode)
- [ ] Aggiungere prompt interattivo per ogni tool opzionale
- [ ] Rilevare prerequisiti (git, pipx, npm) e stampare avvisi chiari
- [ ] Rendere lo script idempotente (rieseguibile senza danni)
- [ ] Testare su shell pulita

---

## M2: README

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
- [ ] Scrivere `README.md` con tutte le sezioni
- [ ] Includere il quickinstall one-liner (presuppone `install.sh` su main)
- [ ] Aggiungere demo ASCII del menu crazycode
