# ADR 0003: Haul actions never write network state

- **Status:** Proposed
- **Proposed:** 2026-09-27
- **Relates to:** ADR 0002 (gap 2), issue #11

## Context

The `LogisticNetwork` is stored as a dynamic field on the DAO, under the key
`ConfigureLogisticNetwork` (ADR 0002, decision 1). armature only allows writes
to it with an `ExecutionRequest<ConfigureLogisticNetwork>`. Tests on armature
`4bd6fbae`, `cycle-7` and armature#168 confirm that a request for any other proposal
type aborts (ADR 0002, gap 2).

The haul lifecycle (#11) adds proposal types that aren't
`ConfigureLogisticNetwork`: `ListHaulAction` (bypass, no vote) and
`ResolveDispute` (voted). It also adds direct entry points with no proposal at
all: `claim_action`, `start_haul`, `record_hop`, `complete_action`,
`expire_action`, `dispute_action`. The current `LogisticNetwork` has
`actions_open` / `actions_completed` counters that this lifecycle would have
to update.

The scaffold in `action.move` doesn't support this yet:
- `create_action`, `cancel_action` and `resolve_dispute` are
  `public(package)`, so `minehaul_armature` can't call them.
- `create_action` takes `&mut DAO` and a ready-made `Route`, which only core
  can construct (ADR 0002, gap 3).

Four facts decide how:

1. **The other request types can't write the network.** Any write from the
   haul path would need a second storage slot or a redesign of how the network
   is stored.
2. **armature `cycle-7` added read-only ticket paths (ARMATURE-10).**
   `ticket_from_cap_readonly` lets a type with no cooldown issue its ticket
   against `&DAO`. The DAO is then an immutable shared input: never versioned,
   rewritten or locked. That only helps if nothing else in the transaction
   needs `&mut DAO`.
3. **ADR 0002 wants hauls to run in parallel.** If listing or completing a haul
   wrote to the DAO, every haul in the network would queue on the DAO's write
   lock, and so would every unrelated DAO transaction.
4. **Governed entry points must be callable from `minehaul_armature`.** The
   `network.move` writers already do this: they are `public` and gated on an
   `ExecutionRequest<P>` for the same DAO. From armature#168 on, only the
   module that defines `P` can extract that request from a ticket.

## Decision

1. **Every haul-lifecycle function takes `&DAO`, never `&mut DAO`.** It reads
   the network with `network::borrow<K>(dao)` and writes only to the
   `HaulAction` object and its dynamic fields.
2. **Core names the network's key as a type parameter.** Core can't name
   `ConfigureLogisticNetwork` (that would be a dependency cycle), so lifecycle
   entry points take it as a type parameter `K`, e.g. `create_action<P, K>`:
   - `P` is the request's proposal type;
   - `K` is the network's key.

   `minehaul_armature` fixes `K = ConfigureLogisticNetwork` when it calls
   `create_action`. The `HaulAction` records
   `type_name::with_defining_ids<K>()`, and every later direct call asserts that
   its `K` matches. Without this, a caller could point a haul at a second
   `LogisticNetwork` if a DAO ever had one under another key.
3. **Governed entry points are `public` and gated on `ExecutionRequest<P>`.**
   `create_action`, `cancel_action` and `resolve_dispute` change from
   `public(package)` to `public`. Each asserts `req_dao_id(req) == dao.id()`,
   as the `network.move` writers do. An `ExecutionRequest<P>` only exists for a
   proposal type the DAO voted to enable, so making these `public` doesn't let
   arbitrary callers in.
4. **`create_action` builds its own route.** It takes `vector<VerifiedGate>`
   instead of a `Route` and calls `route::new_from_verified`, with
   `max_route_len` from the network config. An empty vector means no transit
   and uses `route::new_empty`. The route constructors stay
   `public(package)`, so a `Route` can still only come from verified gates.
5. **Remove `actions_open` and `actions_completed` from `LogisticNetwork`.**
   Counts come from events (`ActionListed`, `ActionDelivered`,
   `ActionCancelled`, `ActionExpired`, `ActionResolved`), which ADR 0002
   already treats as the history.
6. **List hauls on the read-only bypass path.** Enable `ListHaulAction` with
   `cooldown_ms = 0` and call `external_execution::ticket_from_cap_readonly`.
7. **Network changes stay governance-only.** Any future need to change the
   network because of hauling activity goes through a
   `ConfigureLogisticNetwork` proposal.

## Consequences

**Positive**

- Listing, claiming, hopping and completing never lock or rewrite the DAO.
  Hauls in one network run in parallel with each other and with unrelated DAO
  activity.
- The storage-key problem goes away without a second storage slot or a
  redesign of the network's storage.
- Works the same on the current armature pin and after the `cycle-7`
  redeploy.

**Negative**

- There are no on-chain counts of open or completed actions; an indexer has to
  provide them.
- Network-wide limits (e.g. "at most N open actions") can't be enforced
  on-chain. If one is ever needed, keep the counter in a separate shared object
  owned by the network, not in DAO type-state, so it doesn't bring back the DAO
  lock.
- Every lifecycle function carries an extra type parameter `K`, and clients
  must pass it.
- Core exposes more `public` functions. Any proposal type a DAO enables could
  create, cancel or resolve hauls, so an `EnableProposalType` vote for a
  foreign type is also a vote on its handler's use of these entry points.

## Alternatives considered

- **A writable slot for each haul proposal type.** Hard to extend to direct
  calls, which carry no request, and it still needs `&mut DAO`, which rules out
  the read-only path. Rejected.
- **Keep the counters and accept `&mut DAO`.** Every haul transaction would
  queue on the DAO. Rejected.
- **Move `LogisticNetwork` into its own shared object.** Removes the DAO lock
  even for governance writes. But armature's check that "only type `P` can
  write `P`'s state" would have to be rebuilt by hand. Worth revisiting only if
  governance writes become a bottleneck.

## Verification

The tests that confirmed gap 2 (a probe module run against all three armature
revs) aren't in the repo yet. When #11 lands, add them to `minehaul_armature`'s
tests as regression tests, alongside a test that a full list → claim → deliver
cycle passes the DAO only as `&DAO`.
