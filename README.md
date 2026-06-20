# Figma → Production

> **Work in Progress** — This pipeline is functional but actively evolving. Expect rough edges, incomplete docs, and breaking changes between commits.

A Claude Code–driven pipeline that takes a [Figma Make](https://www.figma.com/make/) prototype and produces a production-ready iOS/Android app — with Supabase backend, OTA updates via Capgo, and a clean monorepo architecture that survives future Figma syncs.

---

## What this is

Figma Make generates a working React app from your design. This repo gives you a repeatable pipeline to:

1. **Restructure** that Figma output into a maintainable monorepo (UI layer Figma can keep overwriting, logic layer you own)
2. **Wrap it in Capacitor** for native iOS and Android
3. **Wire a real Supabase backend** — auth, database, edge functions — incrementally, with human review gates at each step
4. **Ship** UI changes in minutes via OTA, and native changes through the stores

The heavy lifting is done by Claude Code slash commands and agent skills. You run the commands; Claude does the restructuring, wiring, and scaffolding; you review and approve at each gate.

---

## Stack

| Layer | Technology |
|---|---|
| UI | React 18, TypeScript, CSS (from Figma), Fontsource (local fonts) |
| Native shell | Capacitor 6+ |
| Backend | Supabase (Postgres + Auth + Edge Functions) |
| OTA updates | Capgo |
| Monorepo | pnpm workspaces |
| Bundler | Vite |
| CI/CD | GitHub Actions |

---

## Architecture

Three layers with hard boundaries:

```
packages/ui       ← Figma-owned. Screens, components, styles. Props in, callbacks out.
                    No data fetching, no auth, no env reads. Ever.

packages/core     ← Engineer-owned. Auth, data clients, hooks, domain types.
                    Figma sync never touches this.

apps/mobile       ← Composition layer. Wires core into UI. Owns routing,
                    Capacitor config, native projects, OTA init.
```

Path aliases: `@app/ui` and `@app/core` (configured in `tsconfig.base.json`).

This separation is what makes re-syncing from Figma safe — the pipeline can overwrite `packages/ui` without touching your backend wiring.

---

## Prerequisites

- [Claude Code](https://claude.ai/code) with the agent skills installed (see Setup)
- [pnpm](https://pnpm.io/) 9+
- [Node.js](https://nodejs.org/) 20+
- [Xcode](https://developer.apple.com/xcode/) (for iOS builds)
- [Android Studio](https://developer.android.com/studio) (for Android builds)
- A [Supabase](https://supabase.com/) account (free tier works)
- A [Capgo](https://capgo.app/) account (for OTA updates)
- A Figma Make project exported as a GitHub repo

---

## Setup

Install the Claude Code skills and commands from this repo into your Claude config:

```bash
# Clone this repo
git clone https://github.com/DamonBslr/figma-to-production.git
cd figma-to-production

# Install skills and commands
mkdir -p ~/.claude/skills ~/.claude/commands

cp -r .claude/skills/figma-make-to-capacitor ~/.claude/skills/
cp -r .claude/skills/supabase-foundation      ~/.claude/skills/
cp -r .claude/skills/supabase-schema          ~/.claude/skills/
cp -r .claude/skills/supabase-wire-stub       ~/.claude/skills/
cp -r .claude/skills/supabase-native-auth     ~/.claude/skills/

cp .claude/commands/init-from-figma.md ~/.claude/commands/
cp .claude/commands/wire-supabase.md   ~/.claude/commands/

chmod +x ~/.claude/skills/figma-make-to-capacitor/scripts/*.sh
```

Then use **this repo as a template** for each new project:

```bash
# Start a new project
gh repo create my-app --template DamonBslr/figma-to-production --private
git clone https://github.com/yourusername/my-app
cd my-app
```

---

## Phase 1 — Bootstrap from Figma

Inside your new project directory, open Claude Code and run:

```
/init-from-figma <figma-github-repo-url> <AppName> <com.bundle.id>
```

Example:
```
/init-from-figma https://github.com/you/my-figma-export MyApp com.yourco.myapp
```

Claude will:
- Clone the Figma Make export into `.figma-src/` (read-only from here on)
- Inventory all screens, components, routing, and data concerns
- Move screens/components into `packages/ui/src`
- Move the router and app entry into `apps/mobile/src`
- Create typed stubs in `packages/core` for every data/auth touchpoint (tagged `// TODO(human-review)`)
- Replace Google Fonts CDN links with local Fontsource packages
- Configure Capacitor with your app ID and bundle name
- Add iOS and Android native projects
- Install and configure Capgo OTA plugin
- Generate a `TRANSFORMATION_REPORT.md` summarizing everything it did

**You review:**
- The stub list — everything returning mock data is enumerated
- Nothing in `packages/ui` does any data fetching or auth (move it to core if found)
- Fonts loaded locally, not from Google CDN

**Then commit:**
```bash
git add -A && git commit -m "Initial transformation from Figma Make"
```

---

## Phase 2 — Wire the Supabase Backend

```
/wire-supabase
```

This runs five sub-skills in sequence, pausing at human gates:

| Step | What happens | Your gate |
|---|---|---|
| 1. Foundation | Supabase client, PKCE auth flow, Capacitor-safe session storage | Create Supabase project, fill `.env`, run `supabase login && supabase link` |
| 2. Schema | Generate Postgres tables + RLS from your domain types | Review SQL, run `supabase db push`, generate DB types |
| 3. Stubs | Wire stubs to real Supabase calls, one at a time | Test the app after each stub — confirm it works before moving on |
| 4. Edge Functions | Secret APIs (AI, image gen) routed through Supabase Edge Functions | Set provider secrets, deploy functions |
| 5. Native OAuth | Google and Apple sign-in via native plugins | Complete provider console checklist, test on real device |

Each step is reviewable and reversible before moving to the next.

**Key security rules enforced throughout:**
- Only the Supabase `anon` key goes in `.env` — never the `service_role` key
- Every table gets RLS policies, scoped to the authenticated user
- `useAuth` implementation (highest-risk code) gets flagged for explicit human review
- Secret provider keys (OpenAI, etc.) live only in Supabase Edge Function secrets, never in the client

---

## Phase 3 — Ship

### UI-only changes (OTA, no store review)

```bash
# From apps/mobile
pnpm build
npx @capgo/cli bundle upload --channel production
```

Live on users' devices in minutes.

### Native changes (store submission)

Required when you add new Capacitor plugins, change permissions, or update the native shell:

1. Increment version in `capacitor.config.ts`
2. Run `cap sync` from `apps/mobile`
3. Build and sign in Xcode / Android Studio
4. Submit to App Store / Google Play

---

## Re-syncing from Figma

When your design evolves in Figma Make, you can re-run the init command. Because `packages/ui` is presentation-only and `packages/core` is untouched by the sync, your backend wiring survives the update.

```
/init-from-figma <same args>
```

Review the diff in `packages/ui` before committing — verify no business logic crept back in.

---

## Common commands

```bash
# Install all dependencies
pnpm install

# Build the web bundle (from apps/mobile)
cd apps/mobile && pnpm build

# Sync native projects after web build
cd apps/mobile && npx cap sync

# Open in Xcode
cd apps/mobile && npx cap open ios

# Open in Android Studio
cd apps/mobile && npx cap open android
```

---

## Repo layout

```
.
├── .claude/
│   ├── commands/
│   │   ├── init-from-figma.md     # Phase 1 slash command
│   │   └── wire-supabase.md       # Phase 2 slash command
│   └── skills/                    # Agent skills (copy to ~/.claude/skills)
│       ├── figma-make-to-capacitor/
│       ├── supabase-foundation/
│       ├── supabase-schema/
│       ├── supabase-wire-stub/
│       └── supabase-native-auth/
├── apps/
│   └── mobile/                    # Capacitor app shell
├── packages/
│   ├── core/                      # Logic layer (hand-written)
│   └── ui/                        # Presentation layer (Figma-derived)
├── CLAUDE.md                      # Project rules (loaded by Claude Code)
├── PIPELINE_PLAYBOOK.md           # Detailed pipeline walkthrough
├── tsconfig.base.json             # Path aliases (@app/ui, @app/core)
└── pnpm-workspace.yaml
```

---

## Hard rules

- **`.figma-src/` is read-only.** Never edit files in it or push changes back to it.
- **`packages/ui` is presentation-only.** If you find data fetching or auth logic there, it's a bug — move it to `packages/core`.
- **Stubs, not fabrication.** Backend touchpoints start as typed stubs returning mock data, tagged `// TODO(human-review)`. Never invent real auth or secret-handling code.
- **Generated UI is not secure by default.** Anything near auth or data must be reviewed before it ships.
- **Native builds are human steps.** Signing, certificates, and store submission are not automated.

---

## Status

> **WIP.** The Phase 1 transformation and Phase 2 Supabase wiring are functional. Known gaps:
> - OTA CI/CD workflow needs per-project Capgo channel configuration
> - Android native auth (Google Sign-In) needs additional testing
> - Re-sync flow (updating an already-transformed project) is not yet hardened
> - No automated tests for the pipeline itself

Contributions and issues welcome.
