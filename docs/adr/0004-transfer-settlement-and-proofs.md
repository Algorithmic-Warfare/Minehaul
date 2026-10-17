# ADR 0004: Transfer settlement and proof boundaries

- **Status:** Accepted (implemented for core Transfer; route-bound terms superseded by [ADR 0005](0005-endpoint-only-transport.md); physical delivery adapter pending)
- **Recorded:** 2026-10-05
- **Supersedes:** ADR 0002's immediate delivery payout and witness-consumption claims
- **Implements:** ADR 0003's immutable DAO lifecycle reads and network-key binding

## Context

The lifecycle scaffold paid out reward and collateral at delivery while allowing
post-delivery disputes. That left no funds to slash. It also allowed cargo withdrawal
without an obligation to complete delivery and treated SSU authorization as delivery
proof. These are separate facts.

The pinned world contracts require a withdrawn Item's parent ID to match the SSU
receiving it. Thus a direct on-chain source-to-destination Item deposit is not a
physical-hauling integration. The game/server bridge, or a carefully validated
warehouse-receipt exchange at the destination, needs its own adapter contract.

Public witness factories previously trusted possession of an AdapterAuth alone.
The pinned armature also exposes ticket requests publicly, so relying only on a
request would allow callers to bypass a proposal handler's payload checks.

## Decision

1. **Deliver first, settle later.** Delivered jobs retain reward and collateral.
   At `elapsed >= dispute_window_ms`, permissionless finalization pays fixed
   recipients and enters `Settled`. Disputes are accepted at `elapsed < window`.
   `Resolved` is a separate terminal outcome for a governance decision. No terminal
   state can pay again. A zero window permits immediate finalization and no
   post-delivery dispute.
2. **Use a non-droppable delivery obligation.** Withdrawing the whole manifest
   returns balances and a `DeliveryRequest` binding action, network, canonical
   registry, destination, hauler and manifest hash. Only a registered adapter's
   defining module can certify it. Completion consumes `VerifiedDelivery` and
   checks those bindings. The transient `Delivering` state cannot persist unless
   completion consumes the proof in the same transaction. SSU/gate/permit witnesses
   retain `drop`; they are transaction-local proofs, not must-consume obligations.
3. **Bind minting to code as well as capability custody.** AdapterAuth records
   `type_name::with_defining_ids<A>()`; factories require `std::internal::Permit<A>`
   and compare the type, exact authorization object ID and revocation flag. The
   world adapter's marker lives in its adapter module, whose SSU mint helper is
   package-private. Physical delivery certification is intentionally absent there.
4. **Governance handlers supply compiler permits too.** Network writers and governed
   job operations require `Permit<P>` alongside the matching `ExecutionRequest<P>`.
   Registry writes check DAO identity and the network's governance marker. Network
   initialization creates and records one canonical registry for that storage slot.
   Listing, cancellation and resolution use separate proposal types; possession of
   a listing bypass capability must not authorize a dispute resolution handler.
5. **Fix job terms at listing.** Snapshot treasury, collateral ratio, dispute window
   and haul duration. The approved payload fixes lister, route, cargo, reward and
   payout split. The transaction executor cannot choose refund recipients, and the
   hauler cannot choose an unlimited deadline at claim time. Collateral uses the
   reward asset, with a rounded-up ratio against reward quantity. No cargo valuation
   or oracle is introduced.
6. **Keep the DAO read-only during core lifecycle transitions.** Store and check
   the network key type on every job. Remove network action counters. HaulerCap
   has `store` but no `key`, so it lives in a dynamic field, not a dynamic object
   field. Cargo, reward and collateral balances remain dynamic object fields.
7. **Bound the milestone to Transfer.** Inject/Extract listing explicitly aborts.
   The world package verifies SSUs; no production gate or delivery adapter is
   claimed. Integration tests use a visibly test-only delivery adapter. The existing
   armature pin lacks `ticket_from_cap_readonly`, so ticket issuance itself retains
   that upstream limitation even though Minehaul's handlers only read the DAO.

## Consequences

- Disputes after delivery have enforceable collateral, at the cost of delayed payment.
- Atomic handoff prevents leaving a successful transaction with freely withdrawn
  cargo and an unfinished job. It does not make a dishonest registered adapter safe.
- An unfinished physical adapter cannot be replaced by an SSU existence check.
- Cancellation and pre-claim expiry return all funded cargo and reward. A claimed
  timeout retains assets pending governance; resolution refunds any still-held cargo.
- Existing payout policy is retained: on a loss, lister receives slashed collateral;
  treasury receives remaining collateral plus reward. Governance may award a hauler
  even without completed delivery, returning untransferred cargo to the lister.
- `ActionDelivered` has zero payouts; `ActionSettled` emits actual successful payout
  amounts. Indexers must treat these as distinct phases of the same job.
- API signatures and stored object layouts change. A previously published package
  would need an explicit compatibility/migration plan; this change does not deploy it.

## Verification

- Governance/core tests cover listing through settlement, cancellation, unclaimed
  and in-flight expiry, both dispute outcomes, post-delivery slashing, fixed
  recipients and configuration snapshots.
- Negative tests cover payload mismatch, malformed manifests, wrong DAO/key/sender,
  deadline boundaries, incomplete routes, outsider disputes, wrong adapter markers,
  revoked adapters, early settlement and double settlement.
- The world-object test verifies and registers a real SSU with its actual OwnerCap.
  The character-cap metadata remains explicitly advisory.
- `scripts/check-security-boundaries.sh` compiles hostile modules in temporary
  package copies and expects compiler rejection of forged permits and discarded
  delivery obligations/proofs. Existing route tests pin hashing and hop validation.

## Remaining integration decision

A production adapter must verify the complete destination delivery before calling
`certify_delivery`. Destination warehouse receipts are one candidate, but source and
destination collection mapping, exact quantities, custody and redemption all need
validation. This is deliberately left pending rather than inferred from SSU access.
