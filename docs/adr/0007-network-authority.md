# ADR 0007: Networks are Minehaul objects with a pluggable authority

- **Status:** Proposed
- **Recorded:** 2026-10-28
- **Revised:** 2026-10-28 after architecture review (role bindings, network-named
  payloads, no handover, upgrade trust, registry checks in core)
- **Builds on:** [ADR 0006](0006-agreement-primitive.md) (bindings of a marker
  type and an instance, gated by `Permit<T>`)
- **Would supersede, once accepted:**
  - [ADR 0001](0001-dependency-structure.md): the `minehaul_core → armature` edge
  - [ADR 0002](0002-logistic-network-architecture.md): decision 1 (the network is
    DAO type-state) and decision 5 (who may haul); decision 4's meaning of `Vaulted`
  - [ADR 0003](0003-haul-actions-read-only-network.md): decision 2 (the `K` type
    parameter). Decision 1 is kept, with `&Network` in place of `&DAO`
  - [ADR 0004](0004-transfer-settlement-and-proofs.md): the registry's cached
    `governance_type` and the network key stored on each job
- **Keeps:** ADR 0002 decision 2's single voter-visible payload for network changes
  (now naming its network), and ADR 0004 decision 4's rule that one operation's
  authorisation cannot be used for another

## Context

### Minehaul's position

Minehaul is a logistics protocol: it is about where goods are, not what they
cost ([vision](../vision.md)). A **network** is a set of depots (SSUs) with
shared policy, and many logistics statements are about such a set. Grouping
depots is part of Minehaul's own model.

### Networks are armature DAO state today

ADR 0002 decision 1 stores `LogisticNetwork` inside an armature DAO as type-state,
keyed by the proposal marker `ConfigureLogisticNetwork`. Core's governed entry
points take both a compiler-issued `Permit<P>` and an armature
`ExecutionRequest<P>`, where `P` is a specific proposal type. Armature touches core
in these places:

| Where | What armature provides |
|---|---|
| `network::init_network`, `set_config`, `set_paused`, `register_ssu`, `unregister_ssu`, `add_auxiliary_hauler`, `remove_auxiliary_hauler` | Storage (`dao::borrow_type_state_mut`) and authorisation (`ExecutionRequest<P>` for the same DAO) |
| `network::assert_can_haul` | `dao::is_governance_member`, one of three ways to be allowed to claim |
| `witnesses::new_registry` (`public(package)`, called by `init_network`), `register_adapter`, `revoke_adapter` | Authorisation of adapter trust; the registry caches the proposal type as `governance_type` |
| `action::create_action`, `cancel_action` | Authorisation of listing and cancelling, each by its own proposal type |
| `action::dispute_action` | `dao::is_governance_member`, as one way to be allowed to dispute |
| `action::resolve_dispute` | The judge; ADR 0006 moves this behind a resolver binding |
| Lifecycle type parameter `K` (ADR 0003 decision 2) | Names the DAO type-state slot the network lives in |

Some checks sit in `minehaul_armature`, not core: each handler asserts
`dao.id() == ticket.ticket_dao_id()`, and the adapter handlers check that the
registry is the network's (`configure_network.move:160, 175`).
`minehaul_world_v0/Move.toml` also declares armature, though no source uses it.

### The proposal to group depots by organisational unit

It has been proposed to organise networks around armature organisational units
(OUs): an OU groups a set of SSUs, and the SSUs' transponder codes are gated by
the OU's role in armature's keyspace. The grouping and the access control are both
useful. Building them into core would make an armature DAO, and later an OU, a
precondition for using Minehaul at all.

ADR 0003's alternatives already rejected a separate network object, because the
write check that armature's type-state gives for free "would have to be rebuilt by
hand". This ADR accepts that cost and rebuilds the check explicitly (decisions 2
and 3).

### Constraints that still hold

- **Hauls must not write network state** (ADR 0003 decision 1).
- **Voter-visible intent stays binding.** An approved payload cannot be applied to
  anything other than what voters saw (ADR 0002, ADR 0004 decision 5).
- **Authorisations do not transfer between operations.** A listing that bypasses a
  vote must not be able to configure a network or resolve a dispute (ADR 0004
  decision 4).
- **Adapter revocation stays per network** (`90eb2df`).
- **No dynamic dispatch.** Plug points are bindings checked against
  compiler-issued permits, as in ADR 0004 and ADR 0006.

## Decision

### 1. The network is a shared object owned by Minehaul

`LogisticNetwork` is replaced by `minehaul_core::network::Network`, a shared
object. Its object ID is the network ID.

```move
public struct Network has key {
    id: UID,
    roles: Roles,
    config: NetworkConfig,
    registered_ssus: VecMap<ID, RegisteredSsu>,
    auxiliary_haulers: VecSet<address>,
    paused: bool,
    registry_id: ID,
}
```

A DAO, an OU or a single owner may govern any number of networks.

### 2. Authority is a set of role bindings, one per kind of operation

One permit type for every operation would let a weak authorisation (a listing
that bypasses a vote) reach a strong one (reconfiguring the network). Core
therefore keeps operations apart, as today, by binding each role separately:

```move
public struct Roles has store, copy, drop {
    admin: Binding,              // config, pause, depots, adapters, allowlist
    lister: Binding,             // create_action
    canceller: Binding,          // cancel_action
    member: Option<Binding>,     // proves membership for claim and dispute policy
}
```

- **Each governed call takes the permit for its role.** Core asserts the permit's
  type and the claimed instance match that role's binding:

  ```move
  public fun set_config<A>(_permit: Permit<A>, net: &mut Network, instance: ID, config: NetworkConfig);
  public fun register_ssu<A>(_permit: Permit<A>, net: &mut Network, instance: ID, vssu: VerifiedSsu, mode: OwnershipMode);
  public fun create_action<A>(_permit: Permit<A>, net: &Network, instance: ID, /* terms */);
  public fun cancel_action<A>(_permit: Permit<A>, action: &mut HaulAction, net: &Network, instance: ID);
  ```

- **One authority, one family.** All roles of a network share one instance, and
  every role's marker type is defined in the same package as the admin role's.
  Core checks both when the network is created. A network cannot pair, say, an
  owner-cap admin with a victim DAO's listing role.
- **Bindings are fixed when the network is created.** There is no handover
  (decision 8).

### 3. Approved payloads name their network

Every payload an authority approves names the network it applies to, and the
authority module asserts `object::id(net) == payload.network_id` before calling
core. For armature this means `NetworkOp`, `ListHaulAction` and `CancelHaulAction`
gain a `network_id`. Today's payloads have none, which was safe only while a DAO
had one network.

### 4. Who may claim and dispute are policies in the config

```move
public struct ClaimPolicy has store, copy, drop {
    members: bool,    // holders of the member role's permit
    allowlist: bool,  // addresses in auxiliary_haulers
    open: bool,       // anyone
}

public struct DisputePolicy has store, copy, drop {
    members: bool,    // members may dispute, besides the two parties
}
```

The claim policy is a set of flags, not a choice of one, so today's rule
(member, auxiliary hauler or open marketplace) stays expressible. A member claims
or disputes through the authority's module, which checks its own membership rule
and calls core with the member role's permit. Grouping depots by OU and gating
access by keyspace role become membership rules of the armature authority.

### 5. Adapter trust is checked in core against the network

`register_adapter` and `revoke_adapter` take `&Network` and the admin role's
permit. Core asserts `registry.network_id == object::id(net)` and
`net.registry_id == object::id(registry)`; the checks in
`configure_network.move` move into core. The cached `governance_type` is removed.
Each network gets exactly one registry, created with the network.

### 6. Haul lifecycle calls read `&Network`

Every lifecycle function takes `&Network` instead of `&DAO`, so hauls still never
write network state. The type parameter `K` is removed: a job records its
network's object ID at listing, and every later call asserts it.

**Open jobs follow the network's live state**, as today: its paused flag, depot
registrations, claim policy and adapter registry. Because authority bindings
cannot change (decision 8), the parties to a job always face the same authority.

### 7. Ownership modes are attested labels

`OwnerCap<StorageUnit>` has `key` only, and armature's `CapabilityVault` requires
`key + store`, so a DAO vault can never hold an SSU's owner cap. Core never
checked custody either: `cap_id` is supplied by the caller.

`Vaulted { cap_id }` and `Leased { lease_id, expires_at_ms }` therefore record
what the network's admin attested at registration, nothing more. `VerifiedSsu`
should carry the ID of the owner cap the adapter actually checked, and
`register_ssu` should compare it with `cap_id` (with #14).

### 8. No authority handover

A network's roles are fixed for its lifetime. Moving a network to another authority
means creating a new network under it and registering the depots there; the old
network winds down as its jobs finish.

A mutable authority would let an attacker build a network with their own adapter
and then hand it to a victim DAO's authority so it looks legitimate. A mistaken
binding would also freeze pausing and adapter revocation for good. A safe handover
needs the incoming authority to accept, and a rule for open jobs; both can come in
a later ADR if there is demand.

### 9. Authorities shipped with Minehaul

- **Armature** in `minehaul_armature`. Role marker types are the existing proposal
  types: `ConfigureLogisticNetwork` for admin, `ListHaulAction` for lister,
  `CancelHaulAction` for canceller, plus a member marker whose module checks DAO
  governance membership. Each handler accepts only its own concrete
  `ExecutionRequest<P>`, checks `ticket_dao_id()` against the instance (the DAO's
  ID) and the payload's `network_id` against the network, then calls core with
  `Permit<P>`. Creating an armature-governed network requires an approved
  `ConfigureLogisticNetwork` ticket.
- **Owner** in `minehaul_core`. One marker type serves every role; the instance is
  the ID of a `NetworkOwnerCap`. Whoever holds the cap governs the network, and
  transferring the cap transfers control. This lets a network run without a
  governance framework, and lets tests run without a DAO.

OU-scoped networks use an OU's identity as the instance once armature's OU API
exists.

### 10. Authority packages are trusted code, including their upgrades

Whoever can upgrade an authority's package can add a module that issues its
permits, and so control every network bound to it. Today that risk is smaller:
armature alone can create an `ExecutionRequest`, so even an upgraded
`minehaul_armature` needs a real DAO ticket.

Before testnet stage A, `minehaul_armature`'s `UpgradeCap` is either placed under
armature governance with a timelock or the package is made immutable. The README
records which. The same question must be answered for any third-party authority,
and clients should show a network's authority package and its upgrade policy.

### 11. Core stops importing armature

With ADR 0006 moving the judge and this ADR moving party authority, no module in
`minehaul_core` imports armature, and the armature dependency is removed from
`minehaul_core/Move.toml` and `minehaul_world_v0/Move.toml`.

```mermaid
flowchart LR
    A2["minehaul_armature<br>(armature authority, ArmatureResolver, handlers)"] --> C2["minehaul_core<br>(networks, haul terms, owner authority)"]
    A2 --> X2[("armature")]
    W2["minehaul_world_v0"] --> C2
    W2 --> WC2[("world-contracts")]
    C2 --> AGR["agreement<br>(after ADR 0006 phase 2)"]
    AGR --> M2[("multicoin")]
    C2 --> M2
```

The edges that must never exist are `minehaul_core → armature` and
`agreement → armature`.

### 12. Implemented before ADR 0006 phase 1

This change is mechanical and touches every governed entry point; ADR 0006 phase 1
then changes the dispute path on top of it. Doing this first means the resolver
binding is added once, to the new `Network`, and the acceptance matrix is reworked
once for both.

## Events, indexers and migration

- **`network_id` changes meaning** from the DAO's ID to the `Network` object's ID in
  `NetworkConfigured`, `ActionListed`, `VerifiedSsu`, `DeliveryRequest` and the
  registry.
- **New event:** `NetworkCreated { network_id, roles }`, so indexers can find
  networks and show their authority.
- **Indexers** read network state from `Network` objects instead of DAO dynamic
  fields.
- **Nothing is deployed**, so there is no on-chain migration. The cost is churn:
  the localnet scenario (`integration/game/move/sources/scenario.move`),
  `scripts/game-env.sh` and the acceptance scenarios change. No SDK exists yet
  (TODO Layer 3), so landing this first avoids an SDK rewrite.

## Consequences

**Positive**

- **Minehaul stands on its own.** A network needs a Minehaul object and an
  authority, not an armature DAO.
- **Organisations can run several networks**, for example one per OU or region.
- **The OU proposal still works**, as a membership rule of the armature authority.
- **Simpler signatures.** `K` disappears, and governance writes touch the network
  instead of the DAO.

**Negative**

- **Governance is no longer free.** Each authority module must authenticate its
  caller, check the payload's network, and be tested for both.
- **Authority upgrades are a trust root** (decision 10).
- **No handover.** Changing authority means a new network and re-registered depots.
- **More shared objects per governance transaction.** An armature-governed write
  takes the DAO (to consume the ticket) and the network.

**Neutral**

- **Delivery and adapters are unchanged** apart from where registry writes are
  checked.
- **Per-network adapter revocation is kept.**

## Alternatives considered

- **Keep the network as DAO type-state** (ADR 0002). Rejected: it keeps armature as
  a precondition for using Minehaul.
- **Keep the armature import but isolate it in one core module.** Cheaper, and
  enough while armature is the only authority. Rejected because it leaves
  armature's API in core's public signatures, and the role and payload fixes
  above are needed either way.
- **Group depots by armature OU inside core.** Rejected: it ties core to an armature
  API that does not exist yet.
- **One permit type for every operation.** Rejected: it erases ADR 0004 decision 4's
  separation between operations.
- **A mutable authority with a handover.** Deferred (decision 8).
- **Make the authority a type parameter, `Network<phantom A>`.** Every job, event
  and client call would carry the authority type. Runtime role bindings match
  ADR 0006.

## Open questions

1. **OU identity.** What ID does an armature OU expose for use as an instance, and
   can the armature authority verify it from a read-only DAO? This depends on the
   same upstream API as ADR 0006 open question 7.
2. **Overlapping networks.** May one SSU be registered in several networks? Nothing
   in core forbids it today.
3. **Snapshotting adapters.** Should a job snapshot the adapter set at listing, so a
   later registration cannot certify it? Today it reads the live registry.
4. **Allowlist placement.** Should `auxiliary_haulers` stay in core, or move into
   the authorities that need it?
5. **Re-verification.** Should registrations expire on owner-governed networks, so
   a stale registration does not outlive the owner cap changing hands (#14)?

## Verification (planned)

- **Role separation:** a lister or canceller permit cannot configure the network,
  manage adapters or create a network; compile probes in
  `scripts/check-security-boundaries.sh` show a `ListHaulAction` path cannot reach
  admin calls.
- **Payload binding:** an armature ticket approved for one network aborts against
  another network of the same DAO.
- **Family check:** creating a network whose roles span two packages or two
  instances aborts.
- **Registry checks:** a registry from another network is rejected by core.
- **Owner authority:** only the `NetworkOwnerCap` holder can make governed calls.
- **Live scenarios:** the full acceptance matrix on an armature-governed network,
  and a smoke run of the Transfer lifecycle on an owner-governed one.
- **Dependency check:** CI fails if any `minehaul_core` source or `Move.toml`
  references armature.
