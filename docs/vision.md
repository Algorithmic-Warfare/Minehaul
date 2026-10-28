# Vision: a protocol for distributing goods

Minehaul is a logistics protocol. It lets someone say where goods should be and
pay whoever makes it so. It does not set prices, match orders or route ships.
This note records the product position the ADRs build towards. Decisions live
in [the ADRs](adr/README.md); this page explains what they are for.

## Logistics is not trading

Today SSU inventories serve as both storage and market. Players who want goods
moved usually encode the movement as a trade: a sell order here and a buy order
there, with a spread wide enough that whoever takes both legs ends up carrying
the goods. The movement is a side effect of an arbitrage.

That works, but the intent is hidden in prices. Only someone who decodes the
spread can act on it, nothing commits them to finish, and nothing guarantees the
goods end up where the person who set the spread wanted them.

Minehaul separates the two concerns:

| | Trading | Logistics |
|---|---|---|
| Items are described by | price | quantity and volume |
| A venue is about | price discovery | distribution across depots |
| The commitment is | a fill, settled at once | an outcome, delivered later |
| Settlement | atomic (a contract) | escrowed and attested (an agreement, [ADR 0006](adr/0006-agreement-primitive.md)) |

A Minehaul job states the intent outright. The budget plays the part the spread
played, but the intent is readable, backed by the hauler's bond, and can be
disputed.

## Haulers are solvers

The protocol fixes the end state and the payment. The hauler decides how to
reach it: which ships, which path, and where the goods come from, including
buying them on a market such as Trinary Exchange in the same transaction.

This extends [ADR 0005](adr/0005-endpoint-only-transport.md). That ADR stopped
the protocol caring *how goods travel*. Outcome intents
([ADR 0008](adr/0008-distribution-intents.md)) stop it caring *where the goods
come from*. Markets become a tool haulers use, not something Minehaul models.

## Depots and networks

An SSU in Minehaul is a **depot**, not necessarily a trading hub. Depots differ
in how they are used:

- **Cold depots** see few transactions but large movements: bulk storage,
  staging, long-haul ends.
- **Hot depots** see many small, frequent transactions: front-line supply,
  refuelling, consumption points.

Temperature is a description of observed activity, so indexers derive it from
events. It informs haulers' choices and the UI. No protocol rule depends on it
yet, so it is not stored on chain.

A **network** is a set of depots with shared policy: who may list, who may
haul, which delivery adapters are trusted, and how disputes are judged. Grouping
depots is a logistics concept in its own right, because many statements are
about a set ("keep K stocked anywhere in this set"). Minehaul therefore owns the
network. Who governs it is pluggable
([ADR 0007](adr/0007-network-authority.md)): an armature DAO or organisational
unit is one authority, a single owner or a multisig are others.

## What a logistics statement says

Every statement combines four things:

- **What:** an item (multicoin collection and asset) and a quantity.
- **Where:** one depot, or a set of depots.
- **When:** by a deadline, over a recurring period, or always.
- **Whose goods:** the lister's own stock, or any source the hauler chooses.

Most useful statements are built from three blocks:

1. **Reach a target by a date.** "At least Q of K at A by T."
2. **Stay within a range over time.** "Always at least Q at A", "never more
   than Q at A", or both.
3. **Sustain a rate.** "R units per period into A."

| Family | Example | Built from | Whose goods |
|---|---|---|---|
| Move | "Move this stock from A to B" | target | lister's |
| Deliver | "At least Q of K at A by T, budget X" | target | any |
| Clear out | "Get stock out of A by T" (a lease is ending) | target (at most) | lister's |
| Stay stocked | "Always at least Q at A" | range (floor) | any |
| Stay in a range | "Keep A between min and max" | range | either |
| Steady supply | "R units per period into A" | rate | any |
| Gather | "From any depots in N into A" | target | lister's |
| Spread | "From A across N, in these proportions" | several targets | lister's |
| Ordered | "Fill B only after A is satisfied" | targets with a dependency | either |

Out of scope:

- **Route rules** such as "avoid system X". ADR 0005 already rejects enforcing
  the path, and no statement above needs it.
- **Prices.** A statement carries a budget. Whether that budget is attractive is
  for haulers to judge.

## What exists and what is planned

| Statement | State |
|---|---|
| Move (Transfer) | Implemented: endpoint-only Transfer ([ADR 0004](adr/0004-transfer-settlement-and-proofs.md), [ADR 0005](adr/0005-endpoint-only-transport.md)) |
| Deliver, Gather | Proposed: [ADR 0008](adr/0008-distribution-intents.md) |
| Stay stocked | Proposed: standing intents in [ADR 0008](adr/0008-distribution-intents.md) |
| Clear out, Stay in a range, Steady supply, Spread, Ordered | Not designed yet |

Every statement is an agreement in the sense of ADR 0006: an obligation that
outlives the transaction that creates it, with stakes escrowed on chain,
performance attested, and breaches judged by a resolver both sides accepted.
