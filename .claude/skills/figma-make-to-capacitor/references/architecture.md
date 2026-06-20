# Target architecture & layer rules

The whole point of this structure is that designer-driven UI changes can be
re-synced from Figma forever without ever touching backend logic. That only works
if the boundary below is kept clean. Treat these as hard rules, not suggestions.

## Repo tree (after transformation)

```
<repo>/
├── .figma-src/              # cloned Figma Make repo — READ-ONLY upstream, gitignored
├── apps/
│   └── mobile/              # the Capacitor app (the only deployable)
│       ├── src/             # app entry, router, providers, shell
│       ├── ios/             # native project (committed)
│       ├── android/         # native project (committed)
│       ├── capacitor.config.ts
│       ├── index.html
│       └── package.json
├── packages/
│   ├── ui/                  # PRESENTATION layer — Figma-derived
│   │   └── src/             #   screens + components: props in, callbacks out
│   └── core/               # LOGIC layer — hand-written
│       └── src/             #   auth, data, api, domain types, hooks
├── CLAUDE.md
├── package.json
├── tsconfig.base.json
└── pnpm-workspace.yaml      # (pnpm only)
```

## The three layers

### packages/ui — presentation (Figma-owned)
- Contains: screens, components, layout, styling, presentational state (open/closed,
  hover, form field values before submit).
- MUST NOT contain: `fetch`/HTTP, API/Supabase clients, auth, `localStorage`,
  env reads, navigation side effects, or any business rule.
- Talks to the outside world ONLY through props and callbacks (or hooks imported
  from `@app/core` via a typed interface).
- May import TYPES from `@app/core` (e.g. `import type { User } from '@app/core'`)
  but never concrete implementations.
- This is the ONLY directory the Figma sync pipeline is allowed to overwrite.

### packages/core — logic (engineer-owned)
- Contains: auth service, data clients, API layer, domain models/types, and the
  hooks that expose them (`useCurrentUser`, `useOrders`, etc.).
- Defines the interfaces the UI depends on, so the UI never knows the
  implementation.
- The Figma sync NEVER writes here. Humans own it.

### apps/mobile — composition + native
- Wires `core` implementations into `ui` components (providers, router, DI).
- Owns `capacitor.config.ts`, the native projects, OTA init, and platform glue
  (safe areas, back button, storage adapter, status bar/splash).

## Separation pattern (how to refactor a mixed component)

Before (Figma output — logic tangled into UI):
```tsx
function ProfileScreen() {
  const [user, setUser] = useState(null)
  useEffect(() => { fetch('/api/me').then(r => r.json()).then(setUser) }, [])
  return <Profile name={user?.name} />
}
```

After:
- `packages/core/src/user/useCurrentUser.ts` — the hook + a stubbed service.
- `packages/ui/src/ProfileScreen.tsx` — pure, receives `user` (or calls the hook).

```tsx
// packages/core/src/user/useCurrentUser.ts
export function useCurrentUser(): { user: User | null } {
  // TODO(human-review): wire real backend / auth
  return { user: { id: 'stub', name: 'Stubbed User' } }
}

// packages/ui/src/ProfileScreen.tsx
export function ProfileScreen({ user }: { user: User | null }) {
  return <Profile name={user?.name} />
}
```

The container that calls `useCurrentUser()` and passes `user` down lives in
`apps/mobile` (or as a thin `*.container.tsx` in core). Keep `ui` dumb.

## Stubs, never fabrication
Every backend touchpoint becomes a typed stub returning mock data, tagged
`// TODO(human-review): ...`, and listed in `TRANSFORMATION_REPORT.md`. Do not
write real authentication, secret handling, or data-access code during the
initial transformation — that is a reviewed, human-owned step.

## Path aliases (set in tsconfig.base.json)
- `@app/ui` → `packages/ui/src`
- `@app/core` → `packages/core/src`
