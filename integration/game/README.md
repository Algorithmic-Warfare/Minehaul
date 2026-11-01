# Local game environment

This harness runs the EVE Frontier world package that Minehaul currently imports,
seeds a deterministic logistics fixture, publishes Minehaul to the live local chain,
executes scenario-defined Transfer lifecycles, and runs the package and security tests.

The default scenario creates three characters, one fueled and online network node,
two online Smart Storage Units, cargo in the source SSU and delivery stock in the
destination SSU. The two SSUs are the smart assemblies Minehaul uses as its source
and destination endpoints. After publication, both become depots in the sense of
[ADR 0009](../../docs/adr/0009-delivery-adapter-contract.md) (see below).

## Commands

```bash
# Run Move/security tests, rebuild from genesis, and execute all acceptance cases.
./scripts/game-env.sh test

# Publish only, or execute the default successful case against the running chain.
./scripts/game-env.sh publish
./scripts/game-env.sh flow

# List cases, run one named case, or run the fresh-genesis matrix.
./scripts/game-env.sh cases
./scripts/game-env.sh flow integration/game/scenarios/full-flow.json resolve-for-lister
./scripts/game-env.sh matrix

# Keep the environment running and inspect it.
./scripts/game-env.sh status
./scripts/game-env.sh manifest
./scripts/game-env.sh logs

# Stop without deleting chain state, or rebuild from genesis.
./scripts/game-env.sh down
./scripts/game-env.sh reset

# Use another checked-in scenario.
./scripts/game-env.sh test integration/game/scenarios/full-flow.json
```

To add a fixture and acceptance plan, copy `scenarios/full-flow.json`, assign globally
unique game/item IDs, and pass the new path to `seed`, `verify`, `flow`, `matrix`, or
`test`. Scenario schema v2 maps the three actor roles expected by the upstream scripts,
declares protocol amounts and timing, and lists ordered lifecycle steps with expected
state, events, abort codes, escrow, and recipient balances. It supports one network node,
exactly two SSUs, zero or more inventory item types, and either zero or two optional
environmental gates. Gates can make a local world fixture more game-like, but Minehaul
does not register them or use them to constrain travel. The pinned
game-to-chain helper fixes each seeded item entry at quantity `10` and volume `10`, so
the validator rejects other values instead of pretending they are configurable.
An item may name a `receiptHolder` (`lister`, `hauler` or `arbiter`); its units are
then deposited for warehouse receipts and the receipts sent to that actor.

Generated chain state, keys, the pinned upstream checkout, deployment output, and
logs live under `.minehaul/game/` and are ignored by Git. `reset` deletes only that
directory. Never reuse the generated keys outside this disposable local network.
The defaults are RPC port `19000` and faucet port `19123`; override them with
`MINEHAUL_RPC_PORT` and `MINEHAUL_FAUCET_PORT` when needed.

The harness pins `evefrontier/world-contracts` at `d33ff232`, the revision
`minehaul_world_v0` and `loash-industries/warehouse-receipts` both link. That commit
is untagged, so the harness fetches it by SHA. Change `WORLD_CONTRACTS_COMMIT` only
when intentionally testing an adapter migration, and keep it equal to the world rev
in the Move manifests.

## Live protocol flow

`publish` creates an ephemeral publication map for the local chain and publishes
multicoin, armature, Minehaul core, Minehaul governance, the world adapter, and the
local bridge in dependency order. This keeps every Move type aligned with the package
IDs deployed on that genesis. If protocol sources change after publication, reset the
environment before publishing again.

`flow` creates a single-member local DAO, explicitly enables Minehaul's configuration,
listing, cancellation, and resolution types through armature's external-execution
governance path, and registers
both seeded SSUs using their real child-owned `OwnerCap<StorageUnit>` objects. It then
uses separate lister, hauler, and arbiter accounts to execute the named case. The
default remains:

```text
list → claim (400 collateral) → collect → deliver (25 cargo) → settle
```

Every run gets an immutable directory under `.minehaul/game/runtime/flows/<case>/`.
Its result records the DAO, registry, collection, action, transaction digests, parsed
events, expected failures, asserted recipient balances, and final state. The runner
also verifies that escrow's cached counters match its live reward, collateral, and
cargo dynamic objects. Running `flow` again creates another independent run directory.

`matrix` deletes disposable chain state first, executes all 15 cases in declaration
order, and writes `.minehaul/game/runtime/acceptance-matrix.json`. Every case creates
and governs its own local delivery authorization, so revoking it in one run cannot
affect another. `test` runs the package and compiler-boundary
tests before invoking this matrix. CI uploads the runtime directory and Sui log as
failure evidence.

The checked-in `minehaul_local` package is a bridge simulator for this disposable
environment. It consumes the same non-droppable delivery request as a production
adapter, transfers the entire tokenized manifest to the configured receiver, and only
then certifies destination delivery. The official game-to-chain fixture separately
proves that source inventory exists. A local chain cannot reproduce the proprietary
game-server operation that moves that inventory between SSUs, so this simulator does
not claim to be a production game bridge.

## Warehouse-receipts depots

`publish` also publishes `warehouse_receipts` (pinned at `fe73b95a`) and turns both
SSUs into depots. For each SSU it:

1. creates the vault (`VaultConfig` and its multicoin `Collection`);
2. installs warehouse receipts as the SSU's extension and freezes the configuration;
3. deposits every item that names a `receiptHolder` and sends the receipts to that
   actor.

The default scenario gives the lister 10 source receipts (the goods to be moved) and
the hauler 10 destination receipts of the same item type. The second set stands in
for stock the hauler already holds or bought at the destination, which exchange-mode
delivery requires. The helpers live in `minehaul_local::receipts`.

`publish` then checks each depot on chain: the extension is `receipt::VaultAuth`,
the freeze marker is present, the vault is bound to that SSU, and each receipt is
owned by its holder with the expected collection, type and amount. The records are
under `depots` in `protocol-deployment.json`.

The acceptance cases do not use these receipts yet. Their cargo is still a separate
token collection delivered by `deliver`. Moving cargo onto receipts and replacing the
simulator with the receipt delivery adapter is the next step of ADR 0009.
