# ADR-003: One Repository for Content Data

## Status

Accepted (2026-09-18)

## Summary

TrivaStream needs a list of things you can listen to — its content catalog.
Today that list probably comes from data bundled inside the app, but it will
likely move to a server at some point as the app grows. Rather than writing
"get the content list" logic separately in every screen that needs it, we're
putting that logic in exactly one place, called a repository, that every
screen goes through. This is the one piece of extra structure we're adding
deliberately, because we can already see it will be needed more than once.

## Context

More than one screen needs access to TrivaStream's content catalog — at
minimum the main library/browse screen, and, based on the app's planned
direction, a future search screen as well. The source of that data may also
change over time: starting as data bundled with the app, and potentially
moving to a remote server later.

Elsewhere in this project we've deliberately avoided adding abstractions
"just in case" (see [ADR-001](ADR-001-direct-audioplayer-injection.md)).
This case is different: we already know, today, that more than one screen
needs the same content data, and that its source is likely to change. That's
not a hypothetical future — it's the situation we're already in.

## Decision

TrivaStream defines one interface — a "content repository" — responsible for
providing catalog data, along with one implementation of it. Every screen
that needs content data goes through this repository rather than fetching or
loading data on its own.

## In Practice

Think of the repository like a **librarian**. When you want a book, you ask
the librarian for it — you don't need to know whether it's on a shelf three
feet away or being pulled from a storage room in the basement. The librarian
handles that. If the library later moves its storage room to a different
building, you still just ask the librarian; nothing about how *you* ask
changes.

In TrivaStream, "asking the librarian" means a screen calling the
repository for the content list. Concretely:

- **Today:** the Library screen asks the repository for the catalog. Behind
  the scenes, the repository reads it from a file bundled inside the app.
- **Tomorrow, when Search is added:** the Search screen asks the *same*
  repository for the *same* catalog, to search through it. Search doesn't
  need its own copy of the loading logic — it reuses the librarian.
- **Later, if the catalog moves to a server:** only the repository's
  internals change (reading from a network request instead of a bundled
  file). The Library screen and the Search screen don't change at all —
  they were never talking to the file or the server directly, only to the
  repository.

That last point is the actual payoff: the screens never notice the change.

## Alternatives Considered

**No shared abstraction; each screen loads content directly.** Every screen
that needs the catalog implements its own loading logic (reading a bundled
file, or later, calling an API) directly.

**Multiple repositories from the start**, split up speculatively by future
feature (e.g., separate interfaces anticipating search, downloads, etc.,
before those features exist).

## Rationale

Without a shared repository, the same loading logic would end up duplicated
across every screen that needs content — and if the data source changes
later (bundled data to a remote API), that change would need to be made in
every one of those places instead of one. Both are concrete, foreseeable
costs given what we already know about TrivaStream's near-term plans, not
speculative ones.

Splitting into multiple repositories up front, before a second, genuinely
different kind of data access exists, would repeat the mistake we're
avoiding elsewhere: adding structure ahead of a real need. One repository,
covering the one real need we have today, is the right amount.

## Trade-offs

- **Advantages:** Content-loading logic exists in exactly one place. Changing
  the data source later — the most likely change TrivaStream will need to
  make — touches one file instead of every screen. Screens that use the
  repository can be tested with a fake version of it, without needing real
  data on disk or a real network call.
- **Disadvantages:** Adds one interface and one implementation that a
  single-screen version of the app wouldn't strictly need yet. We're
  accepting this small upfront cost because we already know it will pay for
  itself once a second screen (search) needs the same data.

## Consequences

- Any screen needing catalog data depends on the repository interface, not
  on file-loading or networking code directly.
- This repository is the only data-access abstraction TrivaStream introduces
  by default. A second one (for example, for offline downloads, which is a
  genuinely different kind of data access) should only be added when that
  need is real — see
  [ADR-004](ADR-004-trigger-conditions-for-new-abstractions.md).
