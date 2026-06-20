---
name: supabase-wire-stub
description: >-
  Step 3 of the Supabase backend — the repeatable workhorse. Replaces ONE stubbed
  hook/service in packages/core with a real Supabase implementation, preserving the
  exported interface so packages/ui and apps/mobile don't change. Run once per stub
  (useAuth email/password, useCurrentUser, useCharacters, etc.). For stubs that call
  an external secret API (story/image generation), it routes through a Supabase Edge
  Function instead of the client. Trigger on "wire up useCharacters", "implement the
  <X> stub with Supabase", or the /wire-supabase orchestrator.
allowed-tools: Bash Read Write Edit Glob Grep
---

# Wire one stub to Supabase

Implements a single `// TODO(human-review)` stub for real. Do exactly one stub per
run so each change is small and reviewable. Read
`../supabase-foundation/references/capacitor-integration.md` for the key/edge-function/
interface rules before editing.

## Inputs
- The target file in `packages/core/src/...` (one stub).
- For data stubs: the table it maps to (from the schema step).
- For secret-API stubs: confirmation to create an Edge Function.

## Procedure
1. Read the target file and note its EXPORTED interface (the `export interface ...`
   and the hook signature). This is a contract — preserve it.
2. Classify the stub:
   - **Data/auth (no external secret):** implement directly with the `supabase`
     client from `@app/core`. Email/password auth, profile reads, character CRUD,
     persistence — all go here.
   - **External secret API (AI story/image gen):** do NOT call the provider from the
     device. Scaffold a Supabase Edge Function under `supabase/functions/<name>/` that
     reads the provider key from `Deno.env` (set later via `supabase secrets set`),
     and implement the hook to call `supabase.functions.invoke('<name>', ...)`.
3. Replace the stub body, keeping the exported interface identical. Remove the
   `// TODO(human-review)` tag only once the real implementation is in.
4. **If the interface must go async** (e.g. `generateCharacterImage: () => string`
   must become `() => Promise<string>`): do NOT add `await` logic into
   `packages/ui`. Change the core signature, then absorb the async state in the
   `apps/mobile` shell and pass plain props down (a result + an `isGenerating` flag),
   matching how `StoryScreen` already takes `isGenerating`. Note every shell/UI prop
   touched in the run summary.
5. Add error handling and loading state. Never swallow auth/permission errors silently.
6. Do NOT remove the stub's typed shape from exports; only its fake body changes.
7. Output a short summary: file changed, table/function used, whether the interface
   changed, which shell/UI files were touched, and any remaining human step
   (e.g. "set OPENAI key: `supabase secrets set ...`", or "create storage bucket").

## Guardrails
- Auth code is security-critical. Implement it, but flag in the summary that it
  needs human review before shipping. Never invent token handling shortcuts.
- Provider/API keys live in Edge Function secrets only — never in `packages/core`,
  `apps/mobile`, or git.
- One stub per run. If asked to "do them all", do them sequentially with a summary
  between each, not in a single sweeping edit.
- Don't touch `.figma-src/`.
