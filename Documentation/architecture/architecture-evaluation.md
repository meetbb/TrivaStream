# TrivaStream Architecture Evaluation

This document records the reasoning behind TrivaStream's architecture. It's
the analysis that the ADRs in [`../decisions/`](../decisions/) are built on
top of. If an ADR says "here's what we decided," this document is "here's
how we figured out what to decide."

## 1. The Question

TrivaStream is a consumer app for playing audio, built on top of
AudioStreamKit (our own framework that handles the actual audio playback).
Before writing much app code, we asked: what's the smallest, simplest way to
organize this app's code that will still hold up as features are added?

A well-known approach for this is called **Clean Architecture** — a pattern
that organizes an app into strict layers (typically: what the user sees,
business rules, data access, and framework integration), with rules about
which layers are allowed to depend on which. It's a respected, widely-used
pattern. The question we asked wasn't "is it good?" — it is — but "does
*this* app, with *these* features, actually need it?"

## 2. What TrivaStream Actually Needs to Solve

Looking at what TrivaStream actually does today, and what it's likely to do
next, the real problems are:

- Connecting AudioStreamKit's playback engine to the screens the user sees,
  without every screen needing to understand how playback works internally.
- Showing a list of content to play (a "catalog"), which today is likely to
  live in a small data file included in the app, but may later come from a
  server as the app grows.
- Handling normal app lifecycle events — the app going to the background, a
  phone call interrupting playback, the screen locking — gracefully.

Notably, a lot of what Clean Architecture is normally used to protect
against — complicated networking, caching, retry logic — already lives
inside AudioStreamKit, outside of TrivaStream entirely. TrivaStream doesn't
need to build protection around a problem it doesn't have.

## 3. Evaluating Clean Architecture for This App

Clean Architecture's biggest strength is keeping business logic independent
of any specific framework, database, or UI — valuable when an app has
substantial rules of its own and multiple real data sources. Applied
literally to TrivaStream today, it would mean four layers of code (screens,
business rules, data access, framework integration), each with its own
interfaces, for an app whose actual logic is close to: "show a list, tap an
item, play it."

That has a real cost: more files, more indirection, and more upfront
decisions to make correctly, for benefits — like swapping out an entire data
layer, or reusing business rules across unrelated apps — that TrivaStream
doesn't currently need and may never need.

**Conclusion:** full Clean Architecture is more structure than TrivaStream's
actual requirements call for today. Adopting it now would mean building for
a size of app we don't have yet, not the one in front of us.

## 4. Comparing the Realistic Options

We compared four practical options:

**MVVM** (Model-View-ViewModel) — each screen has a View (what the user
sees) and a ViewModel (holds that screen's state and logic). Simple, and a
natural fit for a small app. Risk: without any discipline, a ViewModel can
grow to do too much as features are added.

**MVVM + Repository** — same as above, plus one additional piece: a
"repository," a single place responsible for fetching data (see
[ADR-003](../decisions/ADR-003-content-repository-seam.md) for what this
looks like concretely in TrivaStream). This adds a small, deliberate amount
of structure exactly where TrivaStream already knows it needs it.

**Clean Architecture + MVVM** — the full four-layer structure, with MVVM
used inside the "screens" layer. Most powerful, but the most upfront
complexity, for benefits that don't apply yet (see §3).

**Feature-based structure** — organize code by feature (a folder for the
player screen, a folder for the library screen, etc.) rather than by layer.
Adding a new feature later means adding a new folder, not touching existing
ones.

**Conclusion:** MVVM + Repository, organized by feature, gives TrivaStream
real testability and a clear place for the one piece of genuine complexity
it has (content data access), without paying for structure it doesn't need
yet.

## 5. iOS-Specific Considerations

A few implementation-level decisions followed from the above and are worth
recording, even though they're not each a separate ADR:

- Screens (built with SwiftUI, Apple's UI framework) stay simple — they
  display state and forward taps; they don't talk to the network or to
  AudioStreamKit directly.
- Each screen's ViewModel is responsible for translating what AudioStreamKit
  reports (e.g., "buffering," "playing," "failed") into what the screen
  should show (e.g., a spinner, a play button, an error message).
- Playback control is asynchronous — actions like "play" or "load" take a
  moment to complete rather than happening instantly, which is normal for
  audio and is handled inside the ViewModel, not the screen.

## 6. What This Looks Like as TrivaStream Grows

We checked the proposed structure against features TrivaStream is likely to
add later: offline playback, downloads, search, playlists, sign-in,
multiple types of content, and usage analytics. In each case, the feature
fits in as a new screen (and, when it genuinely needs one, a new supporting
piece like a service or a second repository) rather than requiring the
whole app to be restructured.

The one rule that keeps this true over time — deciding *when* a new feature
actually earns a new piece of structure, versus fitting into what already
exists — is written up as
[ADR-004](../decisions/ADR-004-trigger-conditions-for-new-abstractions.md).

## 7. Final Recommendation

TrivaStream uses **feature-based MVVM**, with exactly two additional,
deliberate pieces of structure:

1. One repository for content data
   ([ADR-003](../decisions/ADR-003-content-repository-seam.md)).
2. One shared playback instance, owned in one place
   ([ADR-002](../decisions/ADR-002-shared-playback-ownership.md)).

AudioStreamKit's `AudioPlayer` is used directly, without an additional
wrapper ([ADR-001](../decisions/ADR-001-direct-audioplayer-injection.md)).

This is deliberately the smallest structure that keeps the app testable and
maintainable today, with an explicit, written-down rule
([ADR-004](../decisions/ADR-004-trigger-conditions-for-new-abstractions.md))
for adding more structure only when a real need for it shows up — not
before, and not by accident.
