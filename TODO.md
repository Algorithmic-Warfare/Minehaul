# Minehaul TODO

This plan starts from the working endpoint-only Transfer implementation and its
repeatable local game environment. Work is ordered so that each layer stabilizes
the boundary needed by the next one.

## Baseline

- [x] Model Transfer jobs by source and destination SSU without prescribing a route.
- [x] Fund cargo and reward at listing and collateral at claim.
- [x] Support claim, collection, atomic delivery handoff, settlement, cancellation,
  expiry, dispute, and governed resolution in core.
- [x] Register endpoints and adapter authorizations through governance.
- [x] Seed characters, SSUs, ownership capabilities, and inventory on a disposable
  local chain.
- [x] Publish address-aligned Minehaul packages locally.
- [x] Execute a governed `list -> claim -> collect -> deliver -> settle` flow with
  separate actors and real local transactions.
- [x] Reject forged permits and discarded delivery obligations/proofs with compiler
  probes.

## Layer 1: Local acceptance matrix

**Goal:** make the local environment the executable specification for every
Transfer lifecycle outcome.

### Scenario format and runner

- [x] Extend `integration/game/scenarios/*.json` to describe protocol inputs:
  reward, cargo amount, collateral, payout split, deadlines, dispute window,
  actors, lifecycle steps, and expected outcome.
- [x] Remove fixed amounts and lifecycle choices from the local Move bridge and
  shell runner.
- [x] Give every flow its own output directory so scenarios can run in one local
  environment without overwriting transaction evidence.
- [x] Add a command that runs one named lifecycle scenario.
- [x] Add a command that runs the full acceptance matrix from fresh genesis.
- [x] Record package IDs, object IDs, transaction digests, events, balances, and
  final action state in each result manifest.

### Live transaction scenarios

- [x] Successful delivery and permissionless settlement.
- [x] Governance cancellation before claim.
- [x] Permissionless expiry of an unclaimed listing.
- [x] Deadline expiry after claim.
- [x] Deadline expiry after collection.
- [x] Participant dispute after collection.
- [x] Participant dispute during the post-delivery window.
- [x] Resolution favoring the hauler.
- [x] Resolution favoring the lister with partial collateral slashing.
- [x] Adapter revocation before delivery.
- [x] Admission rejection while the network is paused.
- [x] Completion of an existing haul while the network is paused.
- [x] Rejection of live wrong-destination and wrong-hauler delivery attempts; the
  non-constructible action, network, registry, and manifest proof boundaries remain
  covered by core checks and compiler probes.
- [x] Competing claims by two haulers, with exactly one successful claim.
- [x] Rejection of repeated atomic delivery, settlement, expiry, and resolution.

### Assertions for every scenario

- [x] Assert the exact final `ActionStatus` and emitted lifecycle events.
- [x] Assert reward, collateral, and cargo ownership after the final transaction.
- [x] Assert escrow conservation and an empty escrow after a terminal payout.
- [x] Assert that the cargo manifest cannot be partially delivered.
- [x] Assert that no terminal action can pay out twice.
- [x] Assert expected abort codes for rejected transitions.

### CI

- [x] Run the complete matrix from fresh genesis in pull requests.
- [x] Upload deployment, scenario, transaction, event, and local-node logs when a
  scenario fails.
- [x] Document the expected Sui version and enforce it in the test command.

**Exit condition:** every supported Transfer state transition has at least one live
local-chain scenario, all asset flows are asserted, and the matrix passes from a
clean checkout with one command.

## Layer 2: Delivery adapter contract

**Goal:** stabilize the endpoint delivery boundary without adding route or gate
semantics to Minehaul.

- [ ] Write an ADR for the delivery receipt and adapter versioning model.
- [ ] Specify the facts a delivery adapter must verify: action, network, registry,
  destination, hauler, complete manifest hash, and delivery time.
- [ ] Decide whether an external receipt/reference belongs on-chain, in an event,
  or only in the adapter's audit log.
- [ ] Define replay protection, receipt uniqueness, freshness, and retry behavior.
- [ ] Define adapter upgrade, revocation, and emergency response procedures.
- [ ] Define what evidence governance needs to resolve a disputed delivery.
- [ ] Make the local bridge implement the finalized interface exactly.
- [ ] Add conformance scenarios that any delivery adapter can run locally.
- [ ] Add a live conformance case with multiple distinct cargo asset lines.
- [ ] Remove superseded route and gate material from current-facing architecture
  documentation while retaining the historical ADR decisions.

**Exit condition:** a new adapter can be implemented from the specification and can
prove conformance without changing `minehaul_core`.

## Layer 3: Client and read model

**Goal:** make the protocol usable without manually assembling Sui transactions or
scanning raw events.

### TypeScript SDK and CLI

- [ ] Generate or maintain typed bindings for published Minehaul packages.
- [ ] Build transaction helpers for configure, register endpoint, list, claim,
  collect, deliver, cancel, expire, dispute, resolve, and settle.
- [ ] Validate manifests, amounts, deadlines, and object ownership before submission.
- [ ] Return transaction effects and created object IDs in stable result types.
- [ ] Add CLI commands for each lifecycle operation and common queries.
- [ ] Run SDK integration tests against the local acceptance environment.

### Indexer/read model

- [ ] Define views for networks, registered endpoints, open jobs, active hauls,
  deadlines, disputes, and terminal payouts.
- [ ] Consume events idempotently and retain the transaction cursor.
- [ ] Reconcile indexed state with on-chain objects after restarts or missed events.
- [ ] Distinguish delivery from settlement in metrics and user-facing status.
- [ ] Expose a small query API for clients and automation.

**Exit condition:** a client can discover and complete a haul using the SDK while
reading status from the indexed model, with the local chain as the test backend.

## Layer 4: Production game adapter

**Goal:** replace simulated delivery with evidence from the real game/server cargo
movement boundary.

- [ ] Confirm the supported game integration surface and ownership model with the
  game platform.
- [ ] Map game cargo identifiers and quantities to the on-chain manifest hash.
- [ ] Verify destination receipt without exposing obfuscated location or route data.
- [ ] Bind each attestation to the action, destination, hauler, and registered
  adapter authorization.
- [ ] Keep credentials and signing authority outside public client applications.
- [ ] Make retries idempotent across game-server and chain failures.
- [ ] Persist an audit record that governance can use during disputes.
- [ ] Run the adapter conformance suite and the full acceptance matrix.
- [ ] Exercise adapter revocation and replacement on a staging deployment.

**Exit condition:** a real cargo movement can settle through the same endpoint-only
contract used by the local simulator, including restart, retry, and revocation tests.

## Layer 5: Security and release readiness

**Goal:** prepare a versioned deployment that operators and integrators can safely
adopt.

- [ ] Resolve all findings from an independent Move/security review.
- [ ] Add property or invariant testing for escrow conservation and terminal-state
  exclusivity where it provides coverage beyond scenario tests.
- [ ] Review shared-object contention, transaction size, and gas costs at expected
  cargo-line and marketplace volumes.
- [ ] Define package upgrade policy and object-layout compatibility rules.
- [ ] Produce reproducible deployment manifests for staging and production.
- [ ] Document operator runbooks for pause, adapter revocation, dispute resolution,
  indexer recovery, and incident response.
- [ ] Version the SDK, event schema, adapter contract, and package deployment together.

**Exit condition:** the release has a reviewed threat model, passing acceptance and
adapter suites, reproducible deployment evidence, and tested operator procedures.

## Deferred scope

- [ ] Define product requirements and custody semantics for Inject actions.
- [ ] Define product requirements and custody semantics for Extract actions.
- [ ] Implement Inject/Extract only after the Transfer adapter boundary is stable.
- [ ] Revisit leased and vaulted SSU custody enforcement when the external capability
  and lease contracts are available.

## Review order

When reviewing this plan, decide these points first:

1. Are the Layer 1 lifecycle scenarios complete enough to freeze Transfer behavior?
2. What delivery evidence can the real game integration provide without revealing
   routes or locations?
3. Does the adapter need an on-chain external receipt identifier, or is an emitted
   commitment plus an off-chain audit record sufficient?
4. Which actor will operate the adapter and which governance process can revoke it?
5. Is the first usable client a CLI, a service API, or both?
