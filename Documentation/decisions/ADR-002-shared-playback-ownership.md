# ADR-002: One Shared Playback Instance, Owned in One Place

## Status

Accepted (2026-09-18)

## Summary

Only one audio player should ever be running at a time in TrivaStream, and
only one part of the app should be responsible for it. If two screens each
created their own player, they could easily fall out of sync — for example, a
small "now playing" bar at the bottom of the screen showing different
information than the full player screen. We're preventing that by deciding,
up front, that there is exactly one player instance, created in one place,
and shared by whatever screens need it.

## Context

`AudioPlayer` (see [ADR-001](ADR-001-direct-audioplayer-injection.md))
represents one playback session — one thing playing, at one position, at a
time. TrivaStream's main player screen needs it. Later, a compact "now
playing" bar visible from other screens (a common pattern in media apps)
would also need it, showing the same state.

If each screen independently created its own `AudioPlayer`, they would each
be tracking a separate, independent playback session. Two screens could then
disagree about what's playing.

## Decision

TrivaStream creates exactly one `AudioPlayer` instance, at the app's startup
composition point, and shares that single instance with whichever screens
need to control or observe playback. No screen creates its own.

The precise way this instance is shared (held directly by the main player
screen's view model, versus a small dedicated service used by multiple
screens) is intentionally left open, and should be decided once a second
consumer — such as a "now playing" bar — actually exists. See
[ADR-004](ADR-004-trigger-conditions-for-new-abstractions.md) for the rule
that governs when to make that call.

## Alternatives Considered

**Each screen creates its own `AudioPlayer`.** Simple to write initially, but
guarantees the desync problem described above the moment a second screen
needs playback awareness.

**A global, app-wide singleton (e.g., a static shared instance reachable from
anywhere).** Also solves the sync problem, but makes it harder to control
where and how the player is created and replaced, which makes testing and
future changes harder.

## Rationale

The desync risk isn't hypothetical — it's the direct, predictable result of
letting two screens each construct their own player, and it's exactly the
kind of bug that's cheap to prevent now and expensive to debug after the
fact (inconsistent UI state that's hard to reproduce). A single instance,
created once, is the smallest change that prevents it.

We're rejecting the global-singleton alternative for the same reason we
avoid unnecessary abstractions elsewhere in this project: it solves the
immediate problem but forecloses flexibility (easy dependency injection in
tests, clear ownership) for no added benefit over a single instance created
at startup and passed down explicitly.

## Trade-offs

- **Advantages:** Playback state is always consistent across every screen
  that shows it. Ownership is explicit and traceable to one place in the
  code, not implicit or global.
- **Disadvantages:** Screens that need playback access must have the shared
  instance passed to them, rather than reaching for a global. This is a
  small amount of extra setup code, deliberately accepted for the clarity it
  buys.

## Consequences

- Any new screen that needs to read or control playback must receive the
  shared `AudioPlayer` instance rather than creating its own.
- When a second consumer of playback state is actually added (e.g., a
  "now playing" bar), that is the trigger to decide the exact sharing
  mechanism, per [ADR-004](ADR-004-trigger-conditions-for-new-abstractions.md).
