# Architecture Decision Records (ADRs)

An ADR is a short document that records one architectural decision: the
problem it addresses, the options we considered, what we chose, and what it
costs. We write them so that six months from now — or on day one for someone
new to the project — the *reasoning* behind the code is still available, not
just the code itself.

## Index

| ADR | Title | Status |
|---|---|---|
| [ADR-001](ADR-001-direct-audioplayer-injection.md) | Use AudioStreamKit's `AudioPlayer` Directly, Without a Wrapper | Accepted |
| [ADR-002](ADR-002-shared-playback-ownership.md) | One Shared Playback Instance, Owned in One Place | Accepted |
| [ADR-003](ADR-003-content-repository-seam.md) | One Repository for Content Data | Accepted |
| [ADR-004](ADR-004-trigger-conditions-for-new-abstractions.md) | Rules for Adding New Architecture Later | Accepted |

## How to read these

Each ADR follows the same structure:

- **Summary** — plain-language version, no jargon. Start here.
- **Context** — the situation that forced a decision.
- **Decision** — what we chose.
- **Alternatives Considered** — what else we looked at, and why it lost.
- **Trade-offs** — what we gained and what it costs, stated honestly.
- **Consequences** — what this means for the codebase going forward.

## Adding a new ADR

Use the next sequential number. If a new decision replaces an old one, mark
the old ADR's status as "Superseded by ADR-00X" rather than deleting it — the
history of *why* we changed direction is as valuable as the decision itself.
