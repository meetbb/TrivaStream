# ADR-001: Use AudioStreamKit's `AudioPlayer` Directly, Without a Wrapper

## Status

Accepted (2026-09-18)

## Summary

TrivaStream plays audio using `AudioPlayer`, a component provided by our own
AudioStreamKit framework. We could add a layer of our own code between
TrivaStream and `AudioPlayer` — mainly to make automated testing easier — but
we decided not to. `AudioPlayer` is already built to be used this way, and
adding an extra layer would mean more code to maintain for no real benefit.

## Context

TrivaStream needs to control audio playback: load a track, play, pause, seek.
AudioStreamKit already provides this through a single, well-defined entry
point called `AudioPlayer`.

A common practice in iOS apps is to hide a dependency like `AudioPlayer`
behind an interface we define ourselves (in Swift, a "protocol"). The usual
reason is testing: it lets you substitute a fake player in automated tests
instead of a real one.

The question is whether TrivaStream should do that here, or use `AudioPlayer`
directly.

## Decision

TrivaStream uses `AudioPlayer` directly, wherever playback is needed. We are
not creating an additional interface or wrapper around it.

## Alternatives Considered

**Wrap `AudioPlayer` in a TrivaStream-defined interface.** Define our own
protocol that mirrors `AudioPlayer`'s methods, and have the rest of the app
depend on that instead of on `AudioPlayer` directly. A fake version of the
interface could then be used in tests.

## Rationale

AudioStreamKit's own design already decided this question, and decided it
the other way: `AudioPlayer` is documented as the intended point of
integration for apps like TrivaStream, specifically so that apps don't need
to wrap it. Adding our own interface on top would duplicate a decision
AudioStreamKit already made deliberately, for a benefit (swappable fakes)
that doesn't apply — there will only ever be one real implementation of
audio playback in this app.

This also follows a rule we're holding ourselves to throughout TrivaStream:
don't add an abstraction unless it has a clear, current reason to exist. "We
might want to swap it out later" is not, by itself, a reason — nothing in
TrivaStream's plans calls for a second playback implementation.

## Trade-offs

- **Advantages:** Less code to write and maintain. The rest of the app talks
  to the same thing AudioStreamKit intends it to talk to, with nothing lost
  in translation. Matches how AudioStreamKit itself expects to be used.
- **Disadvantages:** If a screen's logic needs to be tested without triggering
  real audio playback, we can't hand it a simple fake player. Instead, tests
  must use the same test-only approach AudioStreamKit itself uses internally.
  This is a real cost, but a small and already-solved one.

## Consequences

- Any code that needs to control playback takes `AudioPlayer` as a direct
  dependency — no in-between interface to keep in sync.
- If testing needs outgrow what AudioStreamKit's existing test approach
  supports, that would be a reason to revisit this decision — and it should
  be written up as a new ADR that explicitly supersedes this one, not
  changed quietly.

## References

- AudioStreamKit `Documentation/architecture/public-api.md` §7 — the decision,
  made inside AudioStreamKit itself, not to expose a public protocol for
  mocking `AudioPlayer`.
