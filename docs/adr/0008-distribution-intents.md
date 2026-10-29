# ADR 0008: Distribution intents

- **Status:** Proposed; exploratory. Not ready to accept: blocked on the delivery
  adapter contract (TODO Layer 2) and on world-contracts capabilities listed below.
- **Recorded:** 2026-10-28
- **Revised:** 2026-10-28 after architecture review (feasibility blockers, goods
  held until discharge, breach payouts, lister-set bonds, item identity)
- **Builds on:** [ADR 0004](0004-transfer-settlement-and-proofs.md) (delivery
  obligations and proofs), [ADR 0005](0005-endpoint-only-transport.md) (the path
  is not enforced), [ADR 0006](0006-agreement-primitive.md) (agreements) and
  [ADR 0007](0007-network-authority.md) (networks)
- **Relates to:** ADR 0006 open question 5 (partial performance and more than two
  parties)

## Context

### A Transfer prescribes the job

A Transfer says: take *this* stock, which I put in escrow, from source A to
destination B. That is the right shape for moving your own stock. It cannot
express what a lister often wants: "I need Q of K at depot A by T, and here is the
budget." Where the goods come from does not matter to that lister.

The [vision](../vision.md) positions haulers as solvers: the protocol fixes the end
state and the payment, and the hauler composes whatever movement, buying and
selling reaches it.

### What the world contracts allow today

Checked against world-contracts at the pinned revision `8eb197e`:

- **No on-chain stock level.** `storage_unit::item_quantity`, `has_inventory` and
  `inventory::item_quantity` / `used_capacity` are `#[test_only]`. A Move adapter
  cannot prove "the lister holds fewer than Q of K at A".
- **Items do not move between SSUs on chain.** Every deposit checks the item's
  parent is the same SSU. Goods reach a depot through the game, then move between
  inventories *inside* that SSU on chain.
- **Inventories are keyed by Character**, through the Character's owner cap, not by
  address.
- **An SSU has one extension slot** (`extension: Option<TypeName>`), which its
  owner can swap unless the configuration is frozen. Only the extension can move
  items into another Character's inventory or the SSU's open inventory.
- **No delivery certification exists yet.** `minehaul_world_v0` verifies SSUs
  only; Transfer delivery is certified by a localnet test adapter. ADR 0004 records
  the production adapter as pending.

### What an intent delivery would look like

A Minehaul adapter installed as a target SSU's extension can, in one transaction,
withdraw Q of item type K from the hauler Character's inventory at that SSU and
deposit it where the protocol says. It observes the item type, the quantity, the
source Character and the destination. It cannot tell whether the hauler carried
the goods there or bought them at the depot; for an intent that is acceptable,
because the source does not matter.

## Decision

### 1. An intent is an offer that creates fills; each fill is an agreement

An **intent** is a funded offer: "Q of item K at any of these depots by T". It is
not itself an agreement. Haulers take parts of it as **fills**, and each fill is an
ordinary two-party agreement on the ADR 0006 model between the lister and one
hauler.

| | Transfer | Intent fill |
|---|---|---|
| Lister supplies | goods and reward | budget only |
| Terms | source, destination, manifest | target depots, item type, quantity, deadline |
| Custody | the lister's manifest | the **hauler's** goods, once delivered (decision 3) |
| Performance | the manifest handed over | the fill's quantity delivered and held |

```move
public struct Intent has key {
    id: UID,
    network_id: ID,
    lister_character: ID,
    targets: vector<ID>,          // registered depots; a delivery to any counts
    item_type_id: u64,            // world item type, not a multicoin collection
    quantity: u64,
    reserved: u64,                // held by live fills
    min_fill: u64,
    bond_per_unit: u64,           // set by the lister (decision 5)
    price: PriceSchedule,         // decision 6
    reserve_ttl_ms: u64,          // a fill must deliver within this, or lapse
    deliver_by_ms: u64,
    // plus the remaining budget as a holding
}
```

A multicoin collection identifies one depot's receipts under warehouse receipts,
not an item. The item is the world `type_id`. The budget and bonds stay in the
network's reward asset.

### 2. Supply is certified against a core-issued request

Delivery follows ADR 0004's obligation pattern. Core issues a non-droppable
`SupplyRequest` bound to the intent, the fill, the network, its adapter registry,
the hauler's Character and the quantity still owed. The registered adapter
performs the item move itself and returns the request certified for at most that
quantity. A proof cannot be replayed, split across fills or minted by an adapter
another network registered.

The adapter must be the target SSU's extension. If the extension is swapped or the
SSU goes offline during a fill, the fill ends as `Void` (bond returned), not as a
breach.

[ADR 0009](0009-delivery-adapter-contract.md) proposes instead that depots run
warehouse receipts, frozen, and that delivery is handing over destination
receipts. A fill could then be certified the same way without the adapter
holding the extension slot; its open question 7 asks whether that settles this
decision.

### 3. Delivered goods stay held until the fill discharges

If goods went straight to the lister, the lister would hold them while payment
waits out the challenge window; a lister-side ruling could then keep both the goods
and the budget. So delivered goods are **custody owned by the hauler**: held at the
depot under the adapter's control (the SSU's open inventory, or warehouse receipts
held by the fill).

- **Discharge** moves the goods to the lister's Character inventory and pays the
  hauler.
- **A breach ruling** returns the goods to the hauler. ADR 0006's rule that custody
  is never redistributed then protects the hauler.

### 4. Breach payouts never pay the network

Today a loss sends the reward and the unslashed collateral to the treasury. For a
fill that would reward the authority that also approves listings and often judges
disputes. For fills:

- **Delivered units are paid** at the fill's price.
- **Unearned budget returns to the intent**, and is offered again if time remains.
- **The slashed bond goes to the lister.** Nothing goes to the treasury on a breach.

ADR 0006 default rulings are fixed shares chosen at formation, which cannot express
"pay what was delivered". Fills need a **computed default ruling**: a formula over
the terms and the delivered quantity, defined by the intent domain.

### 5. The lister sizes the bond; reservations expire

A bond sized as a share of the reward lets a hauler reserve the whole intent
cheaply. That is an option to walk away if prices move, and in a war it is a cheap
way to starve an enemy depot.

- **`bond_per_unit` is set by the lister**, sized to what a stock-out costs them.
- **`reserve_ttl_ms`** limits how long a fill may hold quantity without delivering;
  it then lapses, and its bond is slashed to the lister.
- **Spot fills** need no reservation or bond: a hauler who delivers in the same
  transaction as accepting is paid once the challenge window closes, like any
  other fill.
- **The last units can always be filled.** A fill may take
  `min(min_fill, quantity - reserved)`.

### 6. The price rises over time

A fixed price makes the lister guess: too low and nothing fills until the deadline
shows it; too high and the fastest filler keeps the overpayment. The price rises
from `start_unit` to `max_unit` over the intent's life, and a fill locks the price
at the moment it is accepted. Unspent budget returns to the lister.

### 7. A set of depots means "any of them"

`targets` lists registered depots of the intent's network, and a delivery to any of
them counts. Statements that need proportions are several intents. A per-depot cap
is an open question.

## Standing intents: not designed yet

"Always keep at least Q of K at A" needs a trustworthy stock level, which the world
contracts do not expose on chain. Three ways forward, none chosen:

1. **An oracle** that attests levels read off chain, trusted like an adapter.
2. **Protocol-held stock:** the lister's depot stock sits in a Minehaul object (for
   example as warehouse receipts), so the level is exact.
3. **A world-contracts change** that makes `item_quantity` public.

Whichever is chosen, the review found these rules are needed:

- **Count stock in transit:** a top-up's quantity must subtract units already
  reserved by open fills, or haulers overfill.
- **Prevent circular fills:** buying the lister's own goods at the depot, then
  delivering them back, must not count. With option 2 this is structural.
- **Resist jamming:** one hauler reserving every top-up and defaulting must cost
  more than it blocks (decision 5's bond and reservation timeout).
- **Pay triggers only on filled top-ups**, if triggers are paid at all.

## Consequences

**Positive**

- **Listers can ask for outcomes**, not just movements of their own stock.
- **Haulers can compete as solvers**, using markets where useful.
- **The agreement core stays two-party**, with partial fills as separate agreements.

**Negative**

- **Depends on the extension slot.** A depot used for intents must have the Minehaul
  adapter as its extension, which conflicts with another extension, such as
  warehouse receipts or a market, on the same SSU.
- **Fills need computed default rulings**, an extension to ADR 0006.
- **Every reservation writes the shared intent**, so popular intents see contention
  when fills are accepted (delivery writes only the fill).

**Neutral**

- **Transfer is unchanged.** It stays the job for moving the lister's own stock.
  Its own bond gap (collateral sized against the reward, not the cargo's value) is
  tracked separately.

## Open questions

1. **Treasury fee.** A fee on the unit price taxes the goods' value, not the hauling.
   Should the fee be flat per fill, or a share of a declared service component?
2. **Partial delivery rulings.** Is "pay delivered units, slash the bond pro rata"
   the right default?
3. **Per-depot caps** for "any of" targets, so all fills do not go to the cheapest
   depot.
4. **Baskets.** One intent for several item types, or several intents?
5. **Clear-out and ceilings.** "Get stock out of A" needs a destination or a sink.
6. **Is this ADR 0006's second instance?** Intents share Transfer's network and
   attestor family, so they test the agreement core's genericity less than an
   unrelated domain would.

## Prerequisites before this ADR can be accepted

- **The delivery adapter contract** (TODO Layer 2), including how the adapter
  becomes and stays an SSU's extension.
- **How Minehaul and other extensions share an SSU** (the single extension slot).
- **Warehouse receipts or another item representation** wired into the adapter.
- **For standing intents:** one of the three stock-level options above.

## Verification (planned)

- **Supply requests:** a certification for another intent, fill, network, item type,
  depot or Character is rejected; certifying more than the quantity owed aborts.
- **Custody:** goods reach the lister only at discharge; a breach ruling returns them
  to the hauler.
- **Budget conservation:** every unit of budget ends with a hauler, the lister or
  the intent; a breach pays the treasury nothing.
- **Reservations:** a fill that misses `reserve_ttl_ms` lapses and frees its quantity;
  the last units can always be filled.
- **Live scenarios:** two haulers fill one intent, one in full and one partially;
  an extension swap mid-fill voids the fill without slashing.
