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

## Form accessibility (label ↔ control association)
- Every `<label>` must be programmatically associated with its form control
  (`<input>`/`<textarea>`/`<select>`). Figma Make emits visually-adjacent but
  unlinked labels — that fails a11y (screen readers, tap-target-to-focus) and
  trips the "A form label must be associated with an input" lint.
- Default fix: give the control an `id` and the label a matching `htmlFor`. Use a
  stable, screen-scoped id (`auth-email`, `character-name`). Inside a `.map`,
  derive the id from the row key (`` htmlFor={`character-field-${field.key}`} ``)
  so each pair stays unique.
- Alternative: wrap the control inside the `<label>` (implicit association) when
  there's no styling reason to keep them as siblings.
- Apply on every sync and when building new screens. Never leave a bare `<label>`
  with no `htmlFor` and no wrapped control.

## Icon / SVG accessibility (decorative vs. meaningful)
- An `<svg>` has an implicit `img` role, so it needs an accessible name or it must
  be explicitly hidden. Figma Make emits bare `<svg>` icons with neither — that
  trips the "Alternative text title element cannot be empty" lint and confuses
  screen readers.
- Default fix (decorative): when the icon adds no information the surrounding
  text/state doesn't already convey — a checkmark inside a toggled button, a
  chevron next to a label, a glyph beside its own caption — mark it
  `aria-hidden="true"` so it's removed from the accessibility tree. Don't invent a
  `<title>`; that just adds redundant noise.
- Alternative (meaningful): when the icon is the *only* thing conveying meaning —
  an icon-only button, a standalone status indicator — give it an accessible name
  via `aria-label` on the control (e.g. icon-only button) or a non-empty
  `<title>` inside the `<svg>`. Never leave the name empty.
- Apply at the layout/component level, preferring the shared icon/button
  primitives over editing Figma-derived inline markup, so the next sync stays
  clean. Apply on every sync and when building new screens. Never leave an `<svg>`
  with no `aria-hidden`, no `aria-label`, and no non-empty `<title>`.

## List keys (no array index as key)
- Never use a bare array index as a React `key` (`key={i}`). Figma Make emits this
  in `.map()` blocks — it trips the "Avoid using the index of an array as key
  property in an element" lint, and on reorder/insert/delete React matches by
  position instead of identity, reusing the wrong DOM node and corrupting state.
- Default fix: key on a stable, unique field of the item (`key={item.id}`,
  `key={field.key}`). When the data has no unique field and content isn't
  guaranteed unique (split text, blank/repeated lines), combine the index with the
  content (`` key={`${i}-${line}`} ``) so the key is both stable and unique.
- Apply at the component level on every sync and when building new screens. Never
  leave a `.map()` keyed on the bare index.

## Effect dependencies (no unused deps)
- A `useEffect`/`useMemo`/`useCallback` dependency array must list exactly the
  reactive values the hook *body* reads — no more, no less. Figma Make often emits
  a "scroll to bottom on new content" effect that lists the content prop as a dep
  but only touches a ref inside, tripping the "This hook specifies more
  dependencies than necessary" lint.
- The intent (re-run when that value changes) is usually correct — the value just
  isn't referenced in the body. Default fix: actually read the value in the effect
  (`` if (!storyContent) return; ``) so the dependency is justified, rather than
  deleting the dep and silently changing when the effect re-runs.
- Don't paper over it by depending on a derived expression (`storyContent.length`)
  the body still doesn't read — the lint fires the same way. Don't add an eslint
  disable comment. Make the body and the dep array agree.
- Apply at the component level on every sync and when building new screens.

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
