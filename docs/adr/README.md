# Architecture Decision Records

Short documents that record a significant design decision: the context it was
made in, what was decided, and what follows from it. They explain *why* the
code looks the way it does. For *what* it does, read the module doc comments.

| # | Title | Status |
|---|---|---|
| [0001](0001-dependency-structure.md) | Package and dependency structure | Accepted; routing portions superseded by 0005 |
| [0002](0002-logistic-network-architecture.md) | Logistic network architecture | Partially superseded by 0004 and 0005 |
| [0003](0003-haul-actions-read-only-network.md) | Haul actions never write network state | Implemented; routing decision superseded by 0005 |
| [0004](0004-transfer-settlement-and-proofs.md) | Transfer settlement and proof boundaries | Accepted; routing terms superseded by 0005 |
| [0005](0005-endpoint-only-transport.md) | Endpoint-only transport | Accepted |
| [0006](0006-agreement-primitive.md) | Agreement as the protocol primitive | Proposed |
| [0007](0007-network-authority.md) | Networks are Minehaul objects with a pluggable authority | Proposed |
| [0008](0008-distribution-intents.md) | Distribution intents | Proposed |

## Writing a new ADR

- Copy the section layout of an existing ADR: **Status**, **Context**,
  **Decision**, **Consequences**, and optionally **Open questions**.
- Number sequentially (`NNNN-short-slug.md`) and add it to the table above.
- Status is one of `Proposed`, `Accepted`, `Superseded by NNNN`, `Deprecated`.
- Don't rewrite an accepted ADR when the decision changes. Write a new one that
  supersedes it and update the old one's status line.
