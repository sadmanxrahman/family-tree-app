# CLAUDE.md — Project constitution

> Put this file at the root of your repo. Claude Code reads it automatically at the
> start of every session, so these rules apply to every prompt without you repeating them.

---

## What this app is

A family tree + memory-keeping + social app for iOS and Android. A family builds a shared
private tree of relatives — living and deceased — attaches memories (photos, video, audio,
written stories) to each person, follows a feed of what relatives add, and views the family
on a map.

**Working name:** `Roots` (placeholder — rename before launch, check trademark availability).

**Priority order of the three pillars:** Preserve history → Discover relatives → Share daily life.

**Primary user:** the "family historian" — the one motivated person per family who builds
the tree and invites everyone else. Secondary user: the reluctant cousin who must understand
the app in thirty seconds.

---

## Non-negotiable rules

1. **TypeScript strict mode.** No `any`. No `@ts-ignore` without a comment explaining why.
2. **Row-level security is the permission system.** Every table has RLS policies. Never rely
   on client-side checks for authorization. If a rule is only in the UI, it is not enforced.
3. **Nothing is hard-deleted.** Every table has `deleted_at timestamptz`. Family data is
   irreplaceable and emotional. All queries filter `deleted_at IS NULL`.
4. **All dates are fuzzy.** Every date in the domain model is a `(date, precision)` pair.
   Never a bare `date` column for birth, death, marriage or event dates.
5. **Feature flags for anything risky.** Ads, maps, discovery, purchases, live location all
   read from the `app_config` table so they can be switched off without a store release.
6. **No secrets in the repo.** All keys in `.env`, `.env` in `.gitignore`, `.env.example`
   committed with placeholder values.
7. **Every user-facing string goes through `t()`.** English only for now, but never hardcode
   a string into JSX. Retrofitting i18n is miserable.
8. **Compress media on device before upload.** Target ≤300 KB for feed images. Always
   generate a thumbnail.
9. **Accessibility is not optional.** Every touchable has an `accessibilityLabel`. Minimum
   touch target 44×44. Test with the largest font size setting.
10. **Write the migration, never edit the database by hand.** Every schema change is a
    numbered SQL file in `supabase/migrations/`.

---

## Tech stack — do not substitute without asking

| Layer         | Choice                                                                                           |
| ------------- | ------------------------------------------------------------------------------------------------ |
| Framework     | React Native via **Expo** (managed workflow), SDK 52+                                            |
| Language      | TypeScript, strict                                                                               |
| Routing       | **Expo Router** (file-based)                                                                     |
| Backend       | **Supabase** — Postgres, Auth, Storage, Realtime, Edge Functions                                 |
| Auth          | **Supabase Auth** — email magic link (+ one-time code backup); session in **expo-secure-store**  |
| Server state  | **TanStack Query** (`@tanstack/react-query`)                                                     |
| Client state  | **Zustand**                                                                                      |
| Forms         | **react-hook-form** + **zod**                                                                    |
| Styling       | **StyleSheet** + a central theme object. No styling library.                                     |
| Tree canvas   | **react-native-svg** + **react-native-reanimated** + **react-native-gesture-handler** (NOT Skia) |
| Maps          | **react-native-maps** — Phase 5+, needs a development build                                      |
| Icons         | **@expo/vector-icons**                                                                           |
| Push          | **expo-notifications**                                                                           |
| Payments      | **RevenueCat** (`react-native-purchases`) — Phase 5+, needs a development build                  |
| Ads (dormant) | **react-native-google-mobile-ads** — Phase 5+, needs a development build                         |
| Errors        | **@sentry/react-native**                                                                         |
| Analytics     | **posthog-react-native**                                                                         |
| Testing       | **Jest** + **@testing-library/react-native**                                                     |

### The Expo Go rule

I develop on a physical iPhone using Expo Go, and have no Apple Developer account, so I cannot
install a custom development build on iOS. Do not add any package that is not included in Expo
Go without stopping and telling me first. If a feature seems to need one, propose an Expo
Go-compatible alternative and explain the tradeoff before writing code.

**Sign in with Apple and Sign in with Google are deferred to Phase 7**, when I have an Apple
Developer account and a development build. Until then, email magic link is the only sign-in
method. Apple must ship alongside Google (App Store rule 4.8). Both slot into
`src/features/auth/signInMethods.ts` as `action` methods — see the notes in that file.

**Do not add a dependency without saying why in the commit message.** Every package is a
future maintenance burden and a potential build break.

---

## Project structure

```
/app                      # Expo Router — file-based routes only, thin screens
  /(auth)                 #   sign-in, sign-up, magic-link callback
  /(tabs)                 #   tree, feed, map, profile
  /person/[id].tsx
  /memory/[id].tsx
  /invite/[token].tsx
/src
  /components             # reusable presentational components
  /features               # feature modules — the real code lives here
    /tree                 #   layout algorithm, canvas renderer, node components
    /persons
    /memories
    /feed
    /map
    /invites
    /billing
  /lib
    supabase.ts           # client singleton
    fuzzyDate.ts          # parse, format, compare fuzzy dates
    theme.ts
    i18n.ts
    flags.ts              # feature flag reader
  /hooks
  /types                  # generated Supabase types + domain types
/supabase
  /migrations             # numbered SQL migrations
  /functions              # Edge Functions
/assets
```

**Screens are thin.** A file in `/app` wires navigation params to a feature component and
renders it. Business logic lives in `/src/features/*`. Data fetching lives in hooks.

---

## Code conventions

- Functional components with hooks. No class components.
- Named exports, except for Expo Router route files which need `export default`.
- One component per file; file name matches the component.
- Data fetching always through a TanStack Query hook (`usePerson`, `useTree`), never a bare
  `supabase.from()` call inside a component.
- Every query hook handles three states explicitly: loading, error, empty. An empty state is
  a designed screen with a call to action, never a blank view.
- Errors surface to the user in plain language and go to Sentry with context. Never a silent
  `catch {}`.
- Comments explain _why_, not _what_.

---

## Domain vocabulary — use these words consistently

| Term           | Meaning                                                                                        |
| -------------- | ---------------------------------------------------------------------------------------------- |
| **Tree**       | A family space. Has members, persons, memories. A user can belong to several.                  |
| **Person**     | A node in the tree. May be living or deceased. May be claimed or unclaimed.                    |
| **Member**     | A user account with access to a tree.                                                          |
| **Claimed**    | A person record linked to the account of the real person it represents. Only they can edit it. |
| **Unclaimed**  | A person record any tree member can edit. All deceased persons are permanently unclaimed.      |
| **Union**      | A marriage or partnership between two persons.                                                 |
| **Memory**     | A story, photo set, video or audio recording attached to one or more persons.                  |
| **Fuzzy date** | A `(date, precision)` pair. Precision ∈ exact, month, year, decade, about, before, after.      |

Never say "user" when you mean "person", or "family member" when you mean "member".
The distinction between an _account_ and a _person node_ is the core of the data model.

---

## Privacy and safety requirements

These are not preferences. They affect App Store approval and legal exposure.

- **Private by default.** No tree, person or memory is publicly readable in v1.0.
- **Account deletion must exist in-app.** Apple rejects apps without it. It must actually
  delete or anonymize, and explain what happens to the user's contributions.
- **No precise location, ever, in v1.0.** Living relatives have a manually-set, opt-in
  **hometown** only, at city level. No GPS, no background location, no continuous tracking.
  The map's value comes from hometowns, ancestors' birth and burial places, and migration
  lines between them — not from live position.
- **No under-18 accounts in v1.0.** Minors may appear as person records added by relatives,
  but may not hold accounts. This avoids COPPA obligations you cannot meet solo.
- **Minimize what you collect.** If a field is not used by a feature that ships, do not
  collect it.

---

## Definition of done

A feature is not done until all of these are true:

- [ ] It works on a physical iPhone **and** a physical Android device
- [ ] Loading, error and empty states are all designed and handled
- [ ] RLS policies are written and verified — tested by querying as a user who should _not_
      have access, confirming zero rows come back
- [ ] It works offline or degrades gracefully; no infinite spinner with no network
- [ ] Every string goes through `t()`
- [ ] Every touchable has an accessibility label
- [ ] No TypeScript errors, no lint errors
- [ ] Manually tested against the acceptance criteria in the prompt that created it

---

## How to work with me

I am new to app development. When you build something:

- **Explain what you did in plain language** before showing code.
- **Tell me what to run** — exact terminal commands, no assumed knowledge.
- **Tell me how to verify it worked** — what to tap, what I should see.
- **Flag anything I need to do outside the code** — a Supabase dashboard setting, an
  App Store Connect field, a key to paste into `.env`.
- **Stop and ask** if a prompt is ambiguous or if you are about to make an architectural
  decision that is hard to reverse. A question costs me two minutes; the wrong schema
  costs me a month.
- **Do not build ahead.** Build what the current prompt asks for and stop. If you notice
  something the next phase will need, mention it rather than building it.
