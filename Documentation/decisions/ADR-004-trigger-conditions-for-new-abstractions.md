# ADR-004: Rules for Adding New Architecture Later

## Status

Accepted (2026-09-18)

## Summary

As TrivaStream grows — new screens, new features — it will be tempting to
either over-build (adding layers of structure "just in case") or under-build
(bolting on quick fixes with no structure at all, because a decision was
never written down). This document sets simple ground rules for when it's
actually time to add new structure to the app, so that decision is made
deliberately each time, not by accident or under deadline pressure.

## Context

TrivaStream is deliberately starting with a small amount of structure: view
models for each screen, one shared playback instance
([ADR-002](ADR-002-shared-playback-ownership.md)), and one repository for
content data ([ADR-003](ADR-003-content-repository-seam.md)). This was a
deliberate choice, not an oversight — see the project's architecture
analysis for the reasoning against adopting a larger structure (such as
full Clean Architecture) upfront.

That analysis identified several features TrivaStream is likely to grow
into: offline downloads, search, playlists, sign-in, multiple types of
content, and usage analytics. Each of these will raise the same question:
does this need new structure, or does it fit into what already exists?
Without an answer written down in advance, that question tends to get
decided inconsistently — sometimes over-engineered, sometimes rushed.

## Decision

New architectural structure (a new repository, a new shared service, a new
protocol, or anything comparable) should only be added when one of these is
true:

1. **A second, genuinely different real-world case already exists** — not a
   hypothetical one. Example: a second data source that doesn't fit the
   existing content repository (offline downloads have different storage
   and lifecycle needs than the catalog) is a real trigger. "We might want
   to support downloads eventually" is not, on its own.
2. **A second consumer of shared state actually exists.** Example: a second
   screen that needs to observe playback state, as referenced in
   [ADR-002](ADR-002-shared-playback-ownership.md), is the trigger to decide
   how playback state is shared — not before.
3. **Logic that doesn't belong to any single screen starts appearing in
   more than one place.** If the same non-trivial rule (not simple
   formatting or display logic) is being written into two different view
   models, that's a sign it needs a shared home, rather than being copied a
   third time.

Each time one of these triggers is hit, the resulting decision should be
written up as its own ADR, referencing this one.

## In Practice

Think of this like **renovating a house one room at a time**, instead of two
opposite bad habits: building rooms nobody's moving into yet, or nailing up
plywood patches and never writing down why.

A few concrete examples of how the three triggers play out:

- **Downloads (trigger 1 — a second, genuinely different real case).**
  Offline downloads need to store files on disk and track download
  progress — nothing like fetching a catalog list. That's a real, different
  case, so when Downloads is actually built, it's correct to add a new
  piece of structure for it (its own service, separate from
  [`ContentRepository`](ADR-003-content-repository-seam.md)). Deciding to
  add that structure *today*, before Downloads exists, would be building the
  room before anyone's moving in.

- **A "now playing" mini-player (trigger 2 — a second consumer of shared
  state).** Right now, only the main Player screen watches playback state.
  The moment a second screen — say, a small "now playing" bar visible while
  browsing — also needs to watch it, that's the signal to decide how
  playback state gets shared between them (see
  [ADR-002](ADR-002-shared-playback-ownership.md)). Before that second
  screen exists, there's nothing real to share yet.

- **Search filtering logic (trigger 3 — repeated logic with no home).** If
  the Library screen and the Search screen both end up writing the same
  rule for, say, deciding which items count as "available to play," that
  rule showing up twice is the signal to give it one shared home instead of
  copying it a third time when the next screen needs it too.

In each case, the trigger is something that has *already happened*, not
something we're predicting might happen.

## Alternatives Considered

**No explicit rule — decide case by case as features are built.** This is
what most small projects do by default. It tends to drift in one of two
directions under pressure: either copying structure from the last decision
without checking if it still applies, or skipping structure entirely to
move fast, both of which create inconsistency over time.

**Decide the full structure for all anticipated features now**, before any
of them are built. This is essentially adopting a larger architecture (like
full Clean Architecture) upfront, which the project's architecture analysis
already found to be more structure than TrivaStream currently needs.

## Rationale

Both alternatives were already effectively rejected by the reasoning behind
TrivaStream's current architecture: build the smallest structure that fits
what's real today, and grow it deliberately. This ADR exists to make sure
that principle survives beyond the current conversation — as new
contributors join and new features get built, this document is what tells
them how to make that call consistently, instead of relying on everyone
remembering, or re-deriving, the same reasoning each time.

## Trade-offs

- **Advantages:** New structure only gets added when there's a concrete
  reason for it, and that reason is written down for anyone reviewing the
  change later. Reduces the chance of both over-engineering and
  undocumented, ad hoc special-casing.
- **Disadvantages:** Requires discipline to actually check against these
  triggers, and to write the follow-up ADR, rather than just writing code
  when a new feature is requested.

## Consequences

- Any pull request that introduces a new protocol, repository, service, or
  similar structural piece should be able to point to which trigger above
  justified it.
- This ADR should be revisited if the rules above turn out to be too strict
  or too loose in practice — like any decision here, that revision should
  itself be written up rather than quietly ignored.

## References

- [`../architecture/architecture-evaluation.md`](../architecture/architecture-evaluation.md) —
  the full analysis comparing Clean Architecture, MVVM, MVVM + Repository,
  and feature-based MVVM for TrivaStream, and why the current structure was
  chosen.
