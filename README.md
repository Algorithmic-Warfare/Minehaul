# Minehaul

Minehaul is a Move framework for DAO-managed logistics networks on EVE Frontier
assembly infrastructure. A network registers Smart Storage Units (SSUs); haulers
claim funded jobs, post collateral, collect at the source, and settle after delivery
to the destination. The protocol does not prescribe or attest the travel path.

## Current status

**Experimental, core-first Transfer implementation.** The protocol and governance
handlers are tested together. Physical cargo movement between SSUs is not integrated:
the pinned world contracts bind on-chain items to their source SSU, and moving goods
between SSUs involves the game/server bridge. There is no production delivery-proof
or production delivery adapter yet. Passing an SSU ownership witness is not proof
of delivery.

Implemented:

- Network configuration, endpoint SSU registration, pause control, and adapter
  registration/revocation through approved governance payloads.
- Funded Transfer listing, claim, source collection confirmation, atomic destination
  delivery handoff, delayed settlement, cancellation, expiry, and disputes.
- Cargo/manifest validation, fixed payout recipients, reward-asset collateral,
  and arithmetic safe across the `u64` amount range.
- Adapter and governance entry points restricted by compiler-issued type permits.
- A real-world-object SSU verification/registration test and full protocol tests
  using an explicitly test-only delivery adapter.

Still pending: a physical-delivery adapter (for example, one based on destination
warehouse receipts), Inject/Extract operations, production deployment dependency
alignment, and client/indexer integration. Inject/Extract constructors remain available
for the domain model, but listing those kinds aborts with `unsupported_action`.

## Packages

| Package | Responsibility |
| --- | --- |
| `minehaul_core` | Network state, endpoint-based jobs, escrow, adapter proofs and events |
| `minehaul_armature` | Governance payloads and handlers for configuration, listing, cancellation and resolution |
| `minehaul_world_v0` | Verification against the pinned EVE Frontier world contracts |

Core has no dependency on world contracts. The governance and world packages do not
depend on each other. Each job is a separate shared object; lifecycle functions only
borrow the DAO immutably. Ticket creation in the currently pinned armature release
still requires mutable DAO access; its later read-only bypass API is not available here.

## Transfer lifecycle

1. Configure a network. Initialization also creates its shared adapter registry.
2. Register source/destination SSUs and the exact adapter authorization object through governance.
3. Execute a `ListHaulAction` ticket with its approved endpoints, cargo manifest, reward,
   payout split, lister, listing lifetime and haul duration. Fund cargo and reward.
4. An eligible hauler claims the job with collateral in the reward's collection/asset.
   The minimum ratio is measured against the reward amount, rounded up. It is **not**
   a valuation of the cargo. Collateral must be nonzero even if the ratio is zero.
5. The hauler confirms collection. Travel and collection evidence remain outside the protocol.
6. Withdraw the complete cargo manifest together with a destination-bound
   `DeliveryRequest`. A trusted
   adapter must verify actual delivery and certify the request. `complete_action`
   must consume its `VerifiedDelivery` in the same transaction. Neither obligation
   nor proof can be dropped or stored; an unfinished handoff cannot commit.
7. Delivery starts the dispute window while reward and collateral remain escrowed.
   After the window, anyone can call `finalize_action`; funds go to the fixed hauler
   and treasury addresses. Governance can resolve a disputed job instead.

Cancellation and unclaimed expiry refund both reward and cargo to the approved
lister. Expiry after claim opens a dispute. A resolution favoring the hauler pays
the reward split and returns collateral. A resolution against the hauler pays the
specified collateral fraction to the lister and routes remaining collateral plus
reward to treasury. Any cargo still held by the action returns to the lister.

The treasury, payout split, collateral ratio, haul duration and dispute window are
fixed for an existing listing. Admission checks use current network membership and
pause state, SSU registration and lease expiry at claim time; pausing does not prevent an existing haul from finishing
or its participants from recovering funds through settlement/dispute resolution.

`ActionDelivered` records delivery with zero payout amounts. `ActionSettled` records
actual success payouts; `ActionResolved` records governance resolution. Consumers
must distinguish delivery from settlement and must not count both as separate jobs.

## Build and test

Validated with **Sui CLI 1.72.2**. Git and network access are needed to fetch the pinned
Move dependencies on the first build.

```bash
set -e
for package in packages/*; do
  sui move build --path "$package" -e testnet
  SUI_SKIP_SHARED_OBJECTS_VERSION_CHECK=1 \
    sui move test --path "$package" -e testnet -i 100000000
done
bash scripts/check-security-boundaries.sh
```

For a repeatable local chain with the compatible EVE Frontier world contracts,
three game characters, two endpoint SSUs, cargo, published Minehaul packages,
and the complete Transfer acceptance matrix, run:

```bash
./scripts/game-env.sh test
```

The command runs the Move and compiler-boundary tests, then creates a fresh genesis
and executes 15 live lifecycle cases under separate lister, hauler and arbiter
accounts. The cases cover success, cancellation, expiry, disputes, both resolution
outcomes, pause behavior, rejected claims and deliveries, terminal-state replay, and
adapter revocation. The environment is isolated under `.minehaul/game/` and can be
reused with `status`, `seed`, `publish`, `flow`, and `verify`, or rebuilt with
`matrix` or `reset`. See the
[local game environment guide](integration/game/README.md) for the scenario format,
generated manifest, and local delivery-bridge semantics.

The test suites cover escrow boundaries, endpoint checks, governance intent, cross-DAO
and proposal-type isolation, lifecycle outcomes, payout recipients, configuration
snapshots, and rejected transitions. Compiler probes reject forged handler permits
and discarded delivery obligations/proofs. The world test uses real `StorageUnit`,
`Character` and `OwnerCap` objects, while the live flow uses the seeded versions of
those objects and production governance authorization.

## Integration constraints

- Registered adapters remain trusted to verify world facts correctly. Minting needs
  both their authorization object and a permit from their marker's defining module.
  `adapter_pkg` is descriptive metadata; the recorded adapter type is the enforced identity.
- Governance revocation removes an adapter from that network's registry only; any
  network can register a shared authorization, so it cannot disable it elsewhere.
  Global, permanent retirement (`witnesses::retire_auth`) needs the adapter's own
  marker permit; the v0 world adapter exposes no retirement path.
- The v0 SSU verifier checks capability authorization. Its character-cap ID field is
  advisory metadata, not an enforced character ownership binding or delivery evidence.
- Vaulted/leased SSU modes record governance intent; this milestone does not verify
  custody in an external capability vault or implement a lease contract.
- External publication/type identities must align before deployment. Dependencies
  are pinned; see ADR 0001's historical compatibility findings.
- The added network/job/auth fields and function signatures change the prototype's
  public interface and object layout. Do not assume compatibility with existing published objects.

See [architecture decisions](docs/adr/README.md), especially
[endpoint-only transport](docs/adr/0005-endpoint-only-transport.md) and
[Transfer settlement and proof boundaries](docs/adr/0004-transfer-settlement-and-proofs.md).
The staged implementation and release work is tracked in [TODO.md](TODO.md).
