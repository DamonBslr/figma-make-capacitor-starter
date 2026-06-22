# Project rules

Mobile app generated from a Figma Make prototype, wrapped in Capacitor. These
rules keep the design→production pipeline working. Follow them in every session.

## Architecture (non-negotiable boundary)
- `packages/ui` — presentation only. Figma-derived screens/components. Props in,
  callbacks out. NO data, auth, storage, env, or business logic. May import TYPES
  from `@app/core`, never implementations. **The Figma sync only ever writes here.**
- `packages/core` — logic. Auth, data clients, API, domain types, hooks. Hand-written.
  The Figma sync never touches this.
- `apps/mobile` — the Capacitor app. Composes ui + core; owns routing, native
  projects, `capacitor.config.ts`, and OTA init.

If you find data/auth/business logic inside `packages/ui`, that is a bug — move it
to `packages/core` and leave the UI consuming a prop or hook.

## Safe areas (device insets)
- Respect device safe areas on every screen — notch, Dynamic Island, status bar,
  and the home indicator. Content must never sit under them.
- Use the CSS env() insets, not hardcoded pixel values:
  `env(safe-area-inset-top/right/bottom/left)`. Pair with `viewport-fit=cover`
  in the `apps/mobile` index `<meta name="viewport">` so the insets resolve.
- Figma Make prototypes assume a full rectangular web viewport and have no inset
  awareness. When syncing or building screens in `packages/ui`, apply insets at
  the layout shell (scroll containers, sticky headers, bottom nav/CTAs) rather
  than editing individual Figma-derived components, so the next sync stays clean.
- Prefer Tailwind/`@capacitor/*`-safe utilities (e.g. `pt-[env(safe-area-inset-top)]`,
  `min-h-[100dvh]`) over fixed heights; account for the keyboard on input screens.

## Shared components (no one-off buttons)
- Figma Make often emits custom/inline button implementations (raw `<button>`,
  ad-hoc styled divs, per-screen button variants). Always replace these with the
  shared button component in `packages/ui` — never let a one-off button survive.
- Preserve the intended Figma style exactly: match the variant/size to the
  existing look, or extend the shared button with a new variant if none fits.
  Refactor toward the shared component; do not restyle the design.
- Apply this on every sync and when building new screens. If the shared button
  can't express a Figma style, add the variant to the shared component rather
  than reintroducing a bespoke button.
- When Figma uses an animated `motion.button` (Framer Motion), don't replace it
  with the plain shared button — that drops the animation. Instead generate/use a
  shared `MotionButton` component in `packages/ui` that wraps `motion.button` and
  carries the shared button's variants/styles, so the motion props (`whileTap`,
  `whileHover`, transitions, etc.) live in one place. Route every animated button
  through `MotionButton`; preserve the intended Figma animation exactly.
- The same principle holds for other repeated primitives (inputs, cards, etc.):
  prefer the shared `packages/ui` component over duplicating Figma's inline markup.

## Hard rules
- `.figma-src/` is read-only upstream source. Never edit it or push to it.
- Never fabricate auth, secrets, tokens, or data-access logic. Backend touchpoints
  are typed stubs tagged `// TODO(human-review)` until a human wires them.
- Generated UI is not secure by default. Anything near auth or data needs human
  review before it ships.
- Native build, signing, and store submission are human steps, not agent steps.

## Shipping model
- UI / web-layer changes ship via OTA live update (no store review).
- New native capabilities (plugins, permissions) require a store submission.

## Common commands
- Build web bundle: from `apps/mobile`, run the app's build script.
- Sync native: `cap sync` from `apps/mobile`.
- Path aliases: `@app/ui`, `@app/core` (see `tsconfig.base.json`).
