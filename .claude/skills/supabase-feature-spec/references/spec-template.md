# Backend feature spec template

Every feature gets ONE spec, used identically as the Linear issue description and
the mirrored `specs/backend/<slug>.md` body. Fill every section. The spec is the
ONLY context a cold-start implementation subagent receives, so it must be
self-contained: copy interface signatures and prop names verbatim — do not
paraphrase a contract.

The mirrored file additionally carries a YAML front-block (see SKILL.md step 3);
the sections below are the human-readable body that follows it.

---

## Feature: <name>
One-line summary of the user-facing capability.

## Classification
`data` | `edge-function` | `native-auth`
- **sequence:** <n> (loop order; auth/profile is always 1)
- **depends_on:** [<slug>, ...] (features that must be Done first)

## User story
As a <role> I want <capability> so that <outcome>.

## UI surface (read-only — never edited)
- Screen/component(s) in `packages/ui/src/...` that consume this feature.
- The exact props / callbacks they already expose (copy the prop names and types).
  The implementation feeds these from the shell; it never edits the UI.

## Stubs / hooks touched
List every `packages/core/src/...` file this feature implements (the
`// TODO(human-review)` targets). For each, copy the EXPORTED interface verbatim —
this is the contract to preserve:
```ts
// packages/core/src/<path>
export interface <Name> { ... }
export function <hook>(...): <ReturnType>
```

## Data model
Tables/columns this feature owns or reads, mapped to `packages/core/src/types`.
This is a REQUEST to the schema owner (the orchestrator/main thread), not a place
to write migrations. State: table name, owner column (`user_id uuid references
auth.users(id)`, or `id` for `profiles`), and the columns derived from the domain
type. If the feature only reads tables another feature owns, say so.

## RLS
Per table, the owner-scoped policy: `auth.uid() = user_id` (or `auth.uid() = id`
for `profiles`). RLS is ON for every table — state the select/insert/update/delete
intent.

## Edge functions
Name(s) under `supabase/functions/<name>/` and the secret(s) each needs
(`supabase secrets set <KEY>=...`), or **none**. Required for any feature that
calls an external paid/secret API — that call never happens on the device.

## Interface-preservation note
Does any exported signature need to go sync → async (e.g. `() => string` becoming
`() => Promise<string>`)? If so, name the planned `apps/mobile` shell routing: the
async state (result + loading flag) is absorbed in the shell and passed to the UI
as plain props (mirroring how `StoryScreen` already receives `isGenerating`). The
UI signature does NOT change. If no async change, say "none".

## Human gates
The specific gate(s) for THIS feature:
- `data`: "run the app and confirm <capability> works against real data".
- `edge-function`: "`supabase secrets set <KEY>=...` + deploy the function, then test".
- `native-auth`: "complete the provider-console checklist
  (`supabase-native-auth/references/human-checklist.md`) + test on a real device".

## Acceptance criteria
The checklist the feature's gate validates — e.g.:
- [ ] Login persists across an app restart.
- [ ] RLS verified: a second user cannot read this user's rows.
- [ ] Loading + error states surface (errors not swallowed).
- [ ] Exported interface unchanged (`git diff` shows no signature change in `packages/ui`).

## Out of scope
- No changes to `packages/ui/**` or `.figma-src/**`.
- No migrations written by the implementing subagent (schema is owned centrally).
