#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export COREPACK_HOME="${COREPACK_HOME:-$HOME/.cache/node/corepack}"
STATE_DIR="${MINEHAUL_GAME_STATE_DIR:-$ROOT_DIR/.minehaul/game}"
WORLD_DIR="$STATE_DIR/world-contracts"
RUNTIME_DIR="$STATE_DIR/runtime"
HOME_DIR="$STATE_DIR/home"
NETWORK_DIR="$STATE_DIR/network"
PID_FILE="$STATE_DIR/sui.pid"
LOG_FILE="$STATE_DIR/sui.log"
ENV_FILE="$WORLD_DIR/.env"
MANIFEST_FILE="$RUNTIME_DIR/manifest.json"
SEED_MARKER="$RUNTIME_DIR/seed.sha256"
MOVE_DIR="$STATE_DIR/move"
LOCAL_PUBFILE="$RUNTIME_DIR/Pub.minehaul-local.toml"
PROTOCOL_DEPLOYMENT="$RUNTIME_DIR/protocol-deployment.json"
PROTOCOL_SOURCE_MARKER="$RUNTIME_DIR/protocol-source.sha256"
FLOW_RUNS_DIR="$RUNTIME_DIR/flows"
MATRIX_MANIFEST="$RUNTIME_DIR/acceptance-matrix.json"
DEFAULT_SCENARIO="$ROOT_DIR/integration/game/scenarios/full-flow.json"
WORLD_CONTRACTS_REPO="${WORLD_CONTRACTS_REPO:-https://github.com/evefrontier/world-contracts.git}"
WORLD_CONTRACTS_REF="${WORLD_CONTRACTS_REF:-v0.0.18}"
WORLD_CONTRACTS_COMMIT="${WORLD_CONTRACTS_COMMIT:-8eb197e4573275d6f45b0da2c69ee793487a49fd}"
EXPECTED_SUI_VERSION="${MINEHAUL_EXPECTED_SUI_VERSION:-1.72.2}"
RPC_HOST="${MINEHAUL_RPC_HOST:-127.0.0.1}"
RPC_PORT="${MINEHAUL_RPC_PORT:-19000}"
FAUCET_PORT="${MINEHAUL_FAUCET_PORT:-19123}"
RPC_URL="http://$RPC_HOST:$RPC_PORT"
FAUCET_URL="http://$RPC_HOST:$FAUCET_PORT/v2/gas"

say() { printf '%s\n' "$*"; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

need() {
    command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

with_home() {
    HOME="$HOME_DIR" "$@"
}

rpc_ready() {
    curl -fsS --max-time 2 -H 'Content-Type: application/json' \
        --data '{"jsonrpc":"2.0","id":1,"method":"sui_getLatestCheckpointSequenceNumber","params":[]}' \
        "$RPC_URL" 2>/dev/null | jq -e '.result != null' >/dev/null 2>&1
}

is_running() {
    [[ -f "$PID_FILE" ]] || return 1
    local pid
    pid="$(cat "$PID_FILE")"
    kill -0 "$pid" 2>/dev/null && rpc_ready
}

validate_scenario() {
    local scenario="$1"
    [[ -f "$scenario" ]] || fail "scenario not found: $scenario"
    jq -e '
      .schemaVersion == 2 and
      (.name | type == "string" and length > 0) and
      (.tenant | type == "string" and length > 0) and
      (.locationHash | test("^0x[0-9a-fA-F]{64}$")) and
      ([.characters.lister.gameCharacterId, .characters.hauler.gameCharacterId,
        .characters.arbiter.gameCharacterId, .networkNode.typeId,
        .networkNode.itemId] | all(type == "number" and . > 0)) and
      (.storageUnits | type == "array" and length == 2 and
        all(.[]; (.name | type == "string" and length > 0) and
                 (.typeId | type == "number" and . > 0) and
                 (.itemId | type == "number" and . > 0) and
                 (.items | type == "array") and
                 all(.items[]; (.typeId | type == "number" and . > 0) and
                                (.itemId | type == "number" and . > 0) and
                                .quantity == 10 and .volume == 10))) and
      (.gates | type == "array" and (length == 0 or length == 2) and
        (length == 0 or .[0].typeId == .[1].typeId) and
        all(.[]; (.name | type == "string" and length > 0) and
                 (.typeId | type == "number" and . > 0) and
                 (.itemId | type == "number" and . > 0))) and
      (.protocol | type == "object") and
      ([.protocol.rewardAmount, .protocol.cargoAmount, .protocol.collateralAmount,
        .protocol.listingTtlMs, .protocol.haulTtlMs] |
        all(type == "number" and floor == . and . > 0)) and
      ([.protocol.minCollateralRatioBps, .protocol.rewardToHaulerBps] |
        all(type == "number" and floor == . and . >= 0 and . <= 10000)) and
      (.protocol.disputeWindowMs | type == "number" and floor == . and . >= 0) and
      (.acceptanceScenarios | type == "array" and length > 0 and
        all(.[];
          (.name | type == "string" and test("^[a-z0-9]+(-[a-z0-9]+)*$")) and
          (.steps | type == "array" and length > 0 and all(.[]; .op | type == "string")) and
          (.expected.status | type == "string" and length > 0) and
          (.expected.events | type == "array"))) and
      ([.acceptanceScenarios[].name] | length == (unique | length))
    ' "$scenario" >/dev/null || fail "invalid scenario: $scenario"

    local all_ids duplicate_count
    all_ids="$(jq -r '[.characters[]?.gameCharacterId, .networkNode.itemId,
        .storageUnits[]?.itemId, .storageUnits[]?.items[]?.itemId, .gates[]?.itemId] | .[]' "$scenario")"
    duplicate_count="$(printf '%s\n' "$all_ids" | sort | uniq -d | wc -l)"
    [[ "$duplicate_count" -eq 0 ]] || fail "scenario contains duplicate character/item IDs"
}

seed_source_hash() {
    jq -cS '{schemaVersion, name, tenant, locationHash, characters, networkNode,
      storageUnits, gates}' "$1" | sha256sum | cut -d' ' -f1
}

doctor() {
    need bash
    need curl
    need git
    need jq
    need node
    need pnpm
    need sha256sum
    need setsid
    need sui
    validate_scenario "${1:-$DEFAULT_SCENARIO}"
    local sui_version
    sui_version="$(sui --version)"
    [[ "$sui_version" == "sui $EXPECTED_SUI_VERSION-"* ]] || \
        fail "Sui $EXPECTED_SUI_VERSION required, found: $sui_version"
    say "Sui: $sui_version"
    say "Node: $(node --version)"
    say "pnpm: $(pnpm --version)"
    say "World contracts: $WORLD_CONTRACTS_REF"
    say "World commit: $WORLD_CONTRACTS_COMMIT"
    say "RPC: $RPC_URL"
}

init_client() {
    mkdir -p "$HOME_DIR"
    if [[ ! -f "$HOME_DIR/.sui/sui_config/client.yaml" ]]; then
        with_home sui client -y addresses >/dev/null 2>&1 || true
    fi
    if ! with_home sui client envs --json 2>/dev/null | jq -e '.[0][] | select(.alias == "localnet")' >/dev/null; then
        with_home sui client new-env --alias localnet --rpc "$RPC_URL" >/dev/null
    fi
    with_home sui client switch --env localnet >/dev/null
}

create_actor() {
    local alias="$1"
    if with_home sui client addresses --json | jq -e --arg alias "$alias" '.addresses[]? | select(.[0] == $alias)' >/dev/null; then
        return
    fi
    with_home sui client new-address ed25519 "$alias" --json >/dev/null
}

actor_address() {
    with_home sui client addresses --json | jq -r --arg alias "$1" '.addresses[] | select(.[0] == $alias) | .[1]'
}

actor_key() {
    with_home sui keytool export --key-identity "$1" --json | jq -r '.exportedPrivateKey'
}

fund_actor() {
    local address="$1"
    local attempt
    for attempt in 1 2 3; do
        if with_home sui client faucet --address "$address" --url "$FAUCET_URL" >/dev/null 2>&1; then
            return
        fi
        sleep 1
    done
    fail "could not fund $address from $FAUCET_URL"
}

write_world_env() {
    local admin_addr player_a_addr player_b_addr player_c_addr
    admin_addr="$(actor_address minehaul-admin)"
    player_a_addr="$(actor_address minehaul-lister)"
    player_b_addr="$(actor_address minehaul-hauler)"
    player_c_addr="$(actor_address minehaul-arbiter)"
    umask 077
    {
        printf 'SUI_NETWORK=localnet\n'
        printf 'SUI_RPC_URL=%s\n' "$RPC_URL"
        printf 'GOVERNOR_PRIVATE_KEY=%s\n' "$(actor_key minehaul-admin)"
        printf 'ADMIN_ADDRESS=%s\n' "$admin_addr"
        printf 'SPONSOR_ADDRESSES=%s\n' "$admin_addr"
        printf 'ADMIN_PRIVATE_KEY=%s\n' "$(actor_key minehaul-admin)"
        printf 'PLAYER_A_PRIVATE_KEY=%s\n' "$(actor_key minehaul-lister)"
        printf 'PLAYER_B_PRIVATE_KEY=%s\n' "$(actor_key minehaul-hauler)"
        printf 'PLAYER_C_PRIVATE_KEY=%s\n' "$(actor_key minehaul-arbiter)"
        printf 'TENANT=%s\n' "$TENANT"
        printf 'FUEL_TYPE_IDS=78437,78515,78516,84868,88319,88335\n'
        printf 'FUEL_EFFICIENCIES=90,80,40,40,15,10\n'
        printf 'ASSEMBLY_TYPE_IDS=77917,84556,84955,87119,87120,88063,88064,88067,88068,88069,88070,88071,88082,88083,90184,91978,92279,92401,92404\n'
        printf 'ENERGY_REQUIRED_VALUES=500,10,950,50,250,100,200,100,200,100,200,300,50,100,1,100,10,20,40\n'
        printf 'GATE_TYPE_IDS=88086,84955\n'
        printf 'MAX_DISTANCES=520340175991902420,1040680351983804840\n'
    } > "$ENV_FILE"
}

up() {
    doctor "${1:-$DEFAULT_SCENARIO}" >/dev/null
    mkdir -p "$STATE_DIR" "$RUNTIME_DIR" "$HOME_DIR" "$NETWORK_DIR"
    if is_running; then
        say "local game chain already running at $RPC_URL"
        return
    fi
    [[ ! -f "$PID_FILE" ]] || rm -f "$PID_FILE"
    say "starting isolated Sui network at $RPC_URL"
    if [[ ! -f "$NETWORK_DIR/network.yaml" ]]; then
        env HOME="$HOME_DIR" sui genesis --force --with-faucet --working-dir "$NETWORK_DIR" \
            >"$LOG_FILE" 2>&1
    fi
    setsid env HOME="$HOME_DIR" sui start \
        --network.config "$NETWORK_DIR" \
        --with-faucet="$RPC_HOST:$FAUCET_PORT" \
        --fullnode-rpc-port "$RPC_PORT" \
        >"$LOG_FILE" 2>&1 &
    printf '%s\n' "$!" > "$PID_FILE"
    local attempt pid
    pid="$(cat "$PID_FILE")"
    for attempt in $(seq 1 90); do
        if ! kill -0 "$pid" 2>/dev/null; then
            tail -80 "$LOG_FILE" >&2 || true
            fail "local Sui process exited during startup"
        fi
        if rpc_ready; then
            init_client
            say "local game chain is ready"
            return
        fi
        sleep 1
    done
    tail -80 "$LOG_FILE" >&2 || true
    fail "local Sui network did not become ready"
}

clone_world() {
    if [[ -d "$WORLD_DIR/.git" ]]; then
        local current
        current="$(git -C "$WORLD_DIR" rev-parse HEAD)"
        [[ "$current" == "$WORLD_CONTRACTS_COMMIT" ]] || fail "world checkout is $current, expected $WORLD_CONTRACTS_COMMIT; run reset"
        return
    fi
    say "cloning world-contracts $WORLD_CONTRACTS_REF"
    git clone --quiet --depth=1 --branch "$WORLD_CONTRACTS_REF" "$WORLD_CONTRACTS_REPO" "$WORLD_DIR"
    [[ "$(git -C "$WORLD_DIR" rev-parse HEAD)" == "$WORLD_CONTRACTS_COMMIT" ]] || \
        fail "resolved $WORLD_CONTRACTS_REF to an unexpected commit"
}

prepare_actors() {
    init_client
    create_actor minehaul-admin
    create_actor minehaul-lister
    create_actor minehaul-hauler
    create_actor minehaul-arbiter
    local actor address
    for actor in minehaul-admin minehaul-lister minehaul-hauler minehaul-arbiter; do
        address="$(actor_address "$actor")"
        fund_actor "$address"
    done
    with_home sui client switch --address minehaul-admin >/dev/null
}

deploy_world() {
    local scenario="$1"
    up "$scenario"
    clone_world
    TENANT="$(jq -r '.tenant' "$scenario")"
    export TENANT
    prepare_actors
    write_world_env
    if [[ ! -s "$WORLD_DIR/deployments/localnet/extracted-object-ids.json" ]]; then
        say "installing pinned world-contract dependencies"
        if ! (cd "$WORLD_DIR" && pnpm install --frozen-lockfile); then
            (cd "$WORLD_DIR" && pnpm approve-builds --all && pnpm install --frozen-lockfile)
        fi
        say "publishing world contracts"
        (cd "$WORLD_DIR" && HOME="$HOME_DIR" pnpm deploy-world localnet)
        say "configuring world contracts"
        (cd "$WORLD_DIR" && HOME="$HOME_DIR" pnpm configure-world localnet)
    else
        say "world contracts already deployed"
    fi
}

write_resources() {
    local scenario="$1" storage_index="$2" item_index="$3" output="$4"
    jq --argjson storage "$storage_index" --argjson item "$item_index" '
      {
        locationHash: .locationHash,
        character: {
          gameCharacterId: .characters.lister.gameCharacterId,
          gameCharacterBId: .characters.hauler.gameCharacterId,
          gameCharacterCId: .characters.arbiter.gameCharacterId
        },
        networkNode: .networkNode,
        assembly: { typeId: 87119, itemId: 9999000005 },
        storageUnit: .storageUnits[$storage] | { typeId, itemId },
        gate: {
          typeId: (.gates[0].typeId // 88086),
          itemId1: (.gates[0].itemId // 90185),
          itemId2: (.gates[1].itemId // 90186)
        },
        turret: { typeId: 5555, itemId: 6001 },
        item: ((.storageUnits[$storage].items[$item] // {typeId: 446, itemId: 444000001}) | { typeId, itemId })
      }
    ' "$scenario" > "$output"
}

world_step() {
    local resources="$1" command="$2"
    (cd "$WORLD_DIR" && HOME="$HOME_DIR" TEST_RESOURCES_PATH="$resources" DELAY_MS=0 pnpm "$command")
}

derive_object_id() {
    local item_id="$1" resources="$2" registry package
    registry="$(jq -r '.world.objectRegistry' "$WORLD_DIR/deployments/localnet/extracted-object-ids.json")"
    package="$(jq -r '.world.packageId' "$WORLD_DIR/deployments/localnet/extracted-object-ids.json")"
    (cd "$WORLD_DIR" && HOME="$HOME_DIR" TEST_RESOURCES_PATH="$resources" \
        pnpm exec tsx -e "import { deriveObjectId } from './ts-scripts/utils/derive-object-id.ts'; console.log(deriveObjectId('$registry', BigInt('$item_id'), '$package'));" | tail -1)
}

build_manifest() {
    local scenario="$1" resources="$2" package registry
    package="$(jq -r '.world.packageId' "$WORLD_DIR/deployments/localnet/extracted-object-ids.json")"
    registry="$(jq -r '.world.objectRegistry' "$WORLD_DIR/deployments/localnet/extracted-object-ids.json")"
    jq -n \
      --arg scenario "$(jq -r '.name' "$scenario")" \
      --arg tenant "$(jq -r '.tenant' "$scenario")" \
      --arg rpc "$RPC_URL" \
      --arg package "$package" \
      --arg registry "$registry" \
      --arg admin "$(actor_address minehaul-admin)" \
      --arg lister "$(actor_address minehaul-lister)" \
      --arg hauler "$(actor_address minehaul-hauler)" \
      --arg arbiter "$(actor_address minehaul-arbiter)" \
      '{schemaVersion: 1, scenario: $scenario, tenant: $tenant, rpcUrl: $rpc,
        world: {packageId: $package, objectRegistry: $registry},
        actors: {admin: $admin, lister: $lister, hauler: $hauler, arbiter: $arbiter},
        objects: [], inventoryItems: []}' > "$MANIFEST_FILE"

    local kind name item_id object_id tmp
    tmp="$RUNTIME_DIR/manifest.tmp.json"
    while IFS=$'\t' read -r kind name item_id; do
        object_id="$(derive_object_id "$item_id" "$resources")"
        jq --arg kind "$kind" --arg name "$name" --argjson itemId "$item_id" --arg objectId "$object_id" \
          '.objects += [{kind: $kind, name: $name, itemId: $itemId, objectId: $objectId}]' \
          "$MANIFEST_FILE" > "$tmp"
        mv "$tmp" "$MANIFEST_FILE"
    done < <(jq -r '
      ([{kind:"character", name:"lister", itemId:.characters.lister.gameCharacterId},
        {kind:"character", name:"hauler", itemId:.characters.hauler.gameCharacterId},
        {kind:"character", name:"arbiter", itemId:.characters.arbiter.gameCharacterId},
        {kind:"network-node", name:"network-node", itemId:.networkNode.itemId}]
       + [.storageUnits[] | {kind:"storage-unit", name:.name, itemId:.itemId}]
       + [.gates[] | {kind:"gate", name:.name, itemId:.itemId}])[] |
      [.kind, .name, (.itemId|tostring)] | @tsv' "$scenario")

    jq --slurpfile scenario "$scenario" '
      . as $manifest |
      .inventoryItems = [
        $scenario[0].storageUnits[] as $storage |
        $storage.items[] |
        . as $item |
        {
          name: $item.name,
          storageUnit: $storage.name,
          storageObjectId: ($manifest.objects[] | select(.kind == "storage-unit" and .name == $storage.name) | .objectId),
          typeId: $item.typeId,
          itemId: $item.itemId,
          quantity: $item.quantity,
          volume: $item.volume
        }
      ]' "$MANIFEST_FILE" > "$tmp"
    mv "$tmp" "$MANIFEST_FILE"
}

seed() {
    local scenario="${1:-$DEFAULT_SCENARIO}"
    validate_scenario "$scenario"
    deploy_world "$scenario"
    local wanted_hash
    wanted_hash="$(seed_source_hash "$scenario")"
    if [[ -f "$SEED_MARKER" ]] && [[ "$(cat "$SEED_MARKER")" == "$wanted_hash" ]]; then
        say "scenario already seeded: $(jq -r '.name' "$scenario")"
        return
    fi
    [[ ! -f "$SEED_MARKER" ]] || fail "a different scenario is already seeded; run reset"

    say "seeding characters and network node"
    local base="$RUNTIME_DIR/resources-base.json"
    write_resources "$scenario" 0 0 "$base"
    world_step "$base" create-character
    world_step "$base" create-nwn
    world_step "$base" deposit-fuel
    world_step "$base" online-nwn

    local storage_count storage_index item_count item_index resources
    storage_count="$(jq '.storageUnits | length' "$scenario")"
    for ((storage_index=0; storage_index<storage_count; storage_index++)); do
        resources="$RUNTIME_DIR/resources-storage-$storage_index.json"
        write_resources "$scenario" "$storage_index" 0 "$resources"
        say "seeding SSU: $(jq -r ".storageUnits[$storage_index].name" "$scenario")"
        world_step "$resources" create-storage-unit
        world_step "$resources" ssu-online
        item_count="$(jq ".storageUnits[$storage_index].items | length" "$scenario")"
        for ((item_index=0; item_index<item_count; item_index++)); do
            write_resources "$scenario" "$storage_index" "$item_index" "$resources"
            world_step "$resources" game-item-to-chain
        done
    done

    if [[ "$(jq '.gates | length' "$scenario")" -eq 2 ]]; then
        say "seeding optional environmental gates"
        world_step "$base" create-gates
        world_step "$base" online-gates
        world_step "$base" link-gates
    fi
    build_manifest "$scenario" "$base"
    printf '%s\n' "$wanted_hash" > "$SEED_MARKER"
    say "scenario seeded; manifest: $MANIFEST_FILE"
}

verify() {
    local scenario="${1:-$DEFAULT_SCENARIO}"
    seed "$scenario"
    [[ -s "$MANIFEST_FILE" ]] || fail "manifest missing"
    local failed=0 kind name object_id object_json valid expected_link
    while IFS=$'\t' read -r kind name object_id; do
        valid=1
        object_json="$(with_home sui client object "$object_id" --json 2>/dev/null || true)"
        if ! jq -e '.objectId == $id' --arg id "$object_id" >/dev/null 2>&1 <<<"$object_json"; then
            valid=0
        elif [[ "$kind" != "character" ]] && \
          ! jq -e '.content.status.status["@variant"] == "ONLINE"' >/dev/null 2>&1 <<<"$object_json"; then
            say "invalid  $kind/$name is not online" >&2
            valid=0
        elif [[ "$kind" == "gate" ]]; then
            expected_link="$(jq -r --arg name "$name" '.objects[] | select(.kind == "gate" and .name != $name) | .objectId' "$MANIFEST_FILE")"
            if ! jq -e '.content.linked_gate_id == $id' --arg id "$expected_link" >/dev/null 2>&1 <<<"$object_json"; then
                say "invalid  gate/$name is not linked to $expected_link" >&2
                valid=0
            fi
        fi
        if [[ "$valid" -eq 1 ]]; then
            say "ok  $kind/$name  $object_id"
        else
            say "failed  $kind/$name  $object_id" >&2
            failed=1
        fi
    done < <(jq -r '.objects[] | [.kind, .name, .objectId] | @tsv' "$MANIFEST_FILE")
    local storage_id type_id item_id quantity
    while IFS=$'\t' read -r name storage_id type_id item_id quantity; do
        if with_home sui client dynamic-field "$storage_id" --json 2>/dev/null | \
          jq -e --argjson typeId "$type_id" --argjson itemId "$item_id" --argjson quantity "$quantity" '
            [.dynamicFields[].fieldObject.json.value.items.contents[]? |
             select((.key|tonumber) == $typeId and
                    (.value.item_id|tonumber) == $itemId and
                    (.value.quantity|tonumber) == $quantity)] | length > 0
          ' >/dev/null; then
            say "ok  inventory-item/$name  item=$item_id quantity=$quantity"
        else
            say "missing  inventory-item/$name  item=$item_id quantity=$quantity" >&2
            failed=1
        fi
    done < <(jq -r '.inventoryItems[] | [.name, .storageObjectId, .typeId, .itemId, .quantity] | @tsv' "$MANIFEST_FILE")
    [[ "$failed" -eq 0 ]] || fail "one or more seeded objects could not be read"
}

protocol_source_hash() {
    find "$ROOT_DIR/packages" "$ROOT_DIR/integration/game/move" -type f \
        \( -path '*/sources/*.move' -o -name 'Move.toml' \) \
        ! -path '*/build/*' -print0 | \
        sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1
}

write_local_move_manifest() {
    local package="$1"
    case "$package" in
        multicoin)
            cat > "$MOVE_DIR/$package/Move.toml" <<'EOF'
[package]
name = "multicoin"
edition = "2024"
version = "0.0.1"

[dependencies]
EOF
            ;;
        armature)
            cat > "$MOVE_DIR/$package/Move.toml" <<'EOF'
[package]
name = "armature"
edition = "2024"
version = "0.0.1"

[dependencies]
multicoin = { local = "../multicoin" }
EOF
            ;;
        minehaul_core)
            cat > "$MOVE_DIR/$package/Move.toml" <<'EOF'
[package]
name = "minehaul_core"
edition = "2024"
version = "0.0.1"

[dependencies]
armature = { local = "../armature" }
multicoin = { local = "../multicoin" }
EOF
            ;;
        minehaul_armature)
            cat > "$MOVE_DIR/$package/Move.toml" <<'EOF'
[package]
name = "minehaul_armature"
edition = "2024"
version = "0.0.1"

[dependencies]
minehaul_core = { local = "../minehaul_core" }
armature = { local = "../armature" }
multicoin = { local = "../multicoin" }
EOF
            ;;
        minehaul_world_v0)
            cat > "$MOVE_DIR/$package/Move.toml" <<EOF
[package]
name = "minehaul_world_v0"
edition = "2024"
version = "0.0.1"

[dependencies]
minehaul_core = { local = "../minehaul_core" }
armature = { local = "../armature" }
multicoin = { local = "../multicoin" }
world = { local = "$WORLD_DIR/contracts/world" }
EOF
            ;;
        minehaul_local)
            cat > "$MOVE_DIR/$package/Move.toml" <<EOF
[package]
name = "minehaul_local"
edition = "2024"
version = "0.0.1"

[dependencies]
minehaul_core = { local = "../minehaul_core" }
minehaul_armature = { local = "../minehaul_armature" }
minehaul_world_v0 = { local = "../minehaul_world_v0" }
armature = { local = "../armature" }
multicoin = { local = "../multicoin" }
world = { local = "$WORLD_DIR/contracts/world" }
EOF
            ;;
        *) fail "unknown generated Move package: $package" ;;
    esac
}

prepare_local_move_workspace() {
    # Resolve the pinned dependency sources into the isolated HOME first.
    with_home sui move build --path "$ROOT_DIR/packages/minehaul_core" -e testnet >/dev/null
    local armature_sources multicoin_sources
    armature_sources="$(find "$HOME_DIR/.move/git" -type d \
        -path '*4bd6fbaea43fab3967b0c1627b1bea679abc78c3/packages/armature_framework/sources' | head -1)"
    multicoin_sources="$(find "$HOME_DIR/.move/git" -type d \
        -path '*2772c26d24c02671726d39f167b8f772777875d9/packages/multicoin/sources' | head -1)"
    [[ -d "$armature_sources" ]] || fail "could not resolve pinned armature sources"
    [[ -d "$multicoin_sources" ]] || fail "could not resolve pinned multicoin sources"

    rm -rf "$MOVE_DIR"
    mkdir -p "$MOVE_DIR"
    mkdir -p "$MOVE_DIR/multicoin" "$MOVE_DIR/armature" \
        "$MOVE_DIR/minehaul_core" "$MOVE_DIR/minehaul_armature" \
        "$MOVE_DIR/minehaul_world_v0" "$MOVE_DIR/minehaul_local"
    cp -R "$multicoin_sources" "$MOVE_DIR/multicoin/sources"
    cp -R "$armature_sources" "$MOVE_DIR/armature/sources"
    cp -R "$ROOT_DIR/packages/minehaul_core/sources" "$MOVE_DIR/minehaul_core/sources"
    cp -R "$ROOT_DIR/packages/minehaul_armature/sources" "$MOVE_DIR/minehaul_armature/sources"
    cp -R "$ROOT_DIR/packages/minehaul_world_v0/sources" "$MOVE_DIR/minehaul_world_v0/sources"
    cp -R "$ROOT_DIR/integration/game/move/sources" "$MOVE_DIR/minehaul_local/sources"
    local package
    for package in multicoin armature minehaul_core minehaul_armature minehaul_world_v0 minehaul_local; do
        write_local_move_manifest "$package"
    done
    cp "$WORLD_DIR/contracts/world/Pub.localnet.toml" "$LOCAL_PUBFILE"
}

publish_local_package() {
    local package="$1"
    local output="$RUNTIME_DIR/publish-$package.json"
    say "publishing local package: $package"
    with_home sui client test-publish "$MOVE_DIR/$package" \
        --build-env testnet --pubfile-path "$LOCAL_PUBFILE" --json > "$output"
    jq -e '.effects.status.status == "success"' "$output" >/dev/null || \
        fail "local publication failed: $package"
    jq -r '.objectChanges[] | select(.type == "published") | .packageId' "$output"
}

publish_minehaul() {
    verify "${1:-$DEFAULT_SCENARIO}"
    local wanted_hash
    wanted_hash="$(protocol_source_hash)"
    if [[ -s "$PROTOCOL_DEPLOYMENT" ]]; then
        [[ -f "$PROTOCOL_SOURCE_MARKER" ]] || fail "local publication metadata is incomplete; run reset"
        [[ "$(cat "$PROTOCOL_SOURCE_MARKER")" == "$wanted_hash" ]] || \
            fail "Minehaul sources changed since local publication; run reset"
        say "Minehaul packages already published"
        return
    fi

    prepare_local_move_workspace
    with_home sui client switch --address minehaul-lister >/dev/null
    local multicoin_pkg armature_pkg core_pkg governance_pkg world_adapter_pkg local_pkg
    multicoin_pkg="$(publish_local_package multicoin | tail -1)"
    armature_pkg="$(publish_local_package armature | tail -1)"
    core_pkg="$(publish_local_package minehaul_core | tail -1)"
    governance_pkg="$(publish_local_package minehaul_armature | tail -1)"
    world_adapter_pkg="$(publish_local_package minehaul_world_v0 | tail -1)"
    local_pkg="$(publish_local_package minehaul_local | tail -1)"

    local world_auth local_auth
    world_auth="$(jq -r --arg core "$core_pkg" '.objectChanges[] |
        select(.type == "created" and .objectType == ($core + "::witnesses::AdapterAuth")) |
        .objectId' "$RUNTIME_DIR/publish-minehaul_world_v0.json")"
    local_auth="$(jq -r --arg core "$core_pkg" '.objectChanges[] |
        select(.type == "created" and .objectType == ($core + "::witnesses::AdapterAuth")) |
        .objectId' "$RUNTIME_DIR/publish-minehaul_local.json")"
    [[ -n "$world_auth" && -n "$local_auth" ]] || fail "adapter auth objects missing after publication"

    jq -n \
        --arg multicoin "$multicoin_pkg" --arg armature "$armature_pkg" \
        --arg core "$core_pkg" --arg governance "$governance_pkg" \
        --arg worldAdapter "$world_adapter_pkg" --arg local "$local_pkg" \
        --arg worldAuth "$world_auth" --arg localAuth "$local_auth" \
        '{packages: {multicoin: $multicoin, armature: $armature, core: $core,
          governance: $governance, worldAdapter: $worldAdapter, local: $local},
          adapters: {world: $worldAuth, localDelivery: $localAuth}}' > "$PROTOCOL_DEPLOYMENT"
    printf '%s\n' "$wanted_hash" > "$PROTOCOL_SOURCE_MARKER"
    say "Minehaul publication recorded: $PROTOCOL_DEPLOYMENT"
}

call_local() {
    local actor="$1" function="$2" output="$3"
    shift 3
    local package
    package="$(jq -r '.packages.local' "$PROTOCOL_DEPLOYMENT")"
    with_home sui client switch --address "$actor" >/dev/null
    if [[ "$#" -eq 0 ]]; then
        with_home sui client call --package "$package" --module scenario --function "$function" \
            --gas-budget 500000000 --json > "$output"
    else
        with_home sui client call --package "$package" --module scenario --function "$function" \
            --args "$@" --gas-budget 500000000 --json > "$output"
    fi
    jq -e '.effects.status.status == "success"' "$output" >/dev/null || \
        fail "local flow call failed: $function"
}

created_object() {
    local output="$1" suffix="$2"
    jq -r --arg suffix "$suffix" '.objectChanges[] |
        select(.type == "created" and (.objectType | endswith($suffix))) | .objectId' "$output" | head -1
}

find_balance() {
    local output="$1" asset="$2" amount="$3" object_id object_json
    while IFS= read -r object_id; do
        object_json="$(with_home sui client object "$object_id" --json)"
        if jq -e --argjson asset "$asset" --argjson amount "$amount" \
            '(.content.asset_id | tonumber) == $asset and (.content.amount | tonumber) == $amount' \
            >/dev/null <<<"$object_json"; then
            printf '%s\n' "$object_id"
            return
        fi
    done < <(jq -r '.objectChanges[] | select(.type == "created" and (.objectType | endswith("::multicoin::Balance"))) | .objectId' "$output")
    fail "balance asset=$asset amount=$amount not found"
}

find_owned_balance() {
    local output="$1" asset="$2" amount="$3" owner="$4" object_id object_json
    while IFS= read -r object_id; do
        object_json="$(with_home sui client object "$object_id" --json)"
        if jq -e --argjson asset "$asset" --argjson amount "$amount" \
            '(.content.asset_id | tonumber) == $asset and (.content.amount | tonumber) == $amount' \
            >/dev/null <<<"$object_json"; then
            printf '%s\n' "$object_id"
            return
        fi
    done < <(jq -r --arg owner "$owner" '.objectChanges[] |
        select((.type == "created" or .type == "mutated") and
               (.objectType | endswith("::multicoin::Balance")) and
               .owner.AddressOwner == $owner) | .objectId' "$output")
    fail "owned balance asset=$asset amount=$amount owner=$owner not found"
}

find_owner_cap() {
    local character_id="$1" endpoint_id="$2"
    with_home sui client objects "$character_id" --json | node -e '
      const fs = require("fs");
      const objects = JSON.parse(fs.readFileSync(0, "utf8"));
      const target = process.argv[1].replace(/^0x/, "").padStart(64, "0").toLowerCase();
      for (const object of objects) {
        const move = object.data && object.data.Move;
        const type = move && move.type_ && move.type_.Other;
        if (!type || type.module !== "access" || type.name !== "OwnerCap") continue;
        const bytes = move.contents || [];
        const authorized = Buffer.from(bytes.slice(32, 64)).toString("hex");
        if (authorized === target) {
          process.stdout.write("0x" + Buffer.from(bytes.slice(0, 32)).toString("hex"));
          process.exit(0);
        }
      }
      process.exit(1);
    ' "$endpoint_id"
}

call_local_expect_abort() {
    local actor="$1" function="$2" output="$3" expected_abort="$4"
    shift 4
    local package stderr stdout rc=0 combined
    package="$(jq -r '.packages.local' "$PROTOCOL_DEPLOYMENT")"
    stderr="${output%.json}.stderr"
    stdout="${output%.json}.stdout"
    with_home sui client switch --address "$actor" >/dev/null
    if [[ "$#" -eq 0 ]]; then
        with_home sui client call --package "$package" --module scenario --function "$function" \
            --gas-budget 500000000 --json >"$stdout" 2>"$stderr" || rc=$?
    else
        with_home sui client call --package "$package" --module scenario --function "$function" \
            --args "$@" --gas-budget 500000000 --json >"$stdout" 2>"$stderr" || rc=$?
    fi
    if [[ "$rc" -eq 0 ]] && jq -e '.effects.status.status == "success"' "$stdout" >/dev/null 2>&1; then
        fail "local flow call unexpectedly succeeded: $function (expected abort $expected_abort)"
    fi
    combined="$(cat "$stdout" "$stderr" 2>/dev/null || true)"
    if ! grep -Eq "abort_code[^0-9]*${expected_abort}([^0-9]|$)|with code ${expected_abort}([^0-9]|$)|[, ]${expected_abort}[)}]" <<<"$combined"; then
        say "$combined" >&2
        fail "local flow call $function failed without expected abort $expected_abort"
    fi
    jq -n --arg function "$function" --argjson expectedAbort "$expected_abort" \
        --arg error "$combined" \
        '{operation: $function, expectedAbort: $expectedAbort, rejected: true, error: $error}' >"$output"
}

role_address() {
    jq -r --arg role "$1" '.actors[$role]' "$MANIFEST_FILE"
}

clock_timestamp() {
    with_home sui client object 0x6 --json | jq -r '.content.timestamp_ms | tonumber'
}

wait_for_action_deadline() {
    local field="$1" target now attempt
    target="$(with_home sui client object "$FLOW_ACTION" --json | jq -r --arg field "$field" '.content[$field] | tonumber')"
    for attempt in $(seq 1 200); do
        now="$(clock_timestamp)"
        if [[ "$now" -ge "$target" ]]; then
            return
        fi
        sleep 0.05
    done
    fail "clock did not reach $field=$target"
}

sum_changed_balances() {
    local output="$1" owner="$2" asset="$3" object_id object_json sum=0 amount
    while IFS= read -r object_id; do
        [[ -n "$object_id" ]] || continue
        object_json="$(with_home sui client object "$object_id" --json 2>/dev/null || true)"
        if jq -e --argjson asset "$asset" '(.content.asset_id | tonumber) == $asset' \
            >/dev/null 2>&1 <<<"$object_json"; then
            amount="$(jq -r '.content.amount | tonumber' <<<"$object_json")"
            sum=$((sum + amount))
        fi
    done < <(jq -r --arg owner "$owner" '.objectChanges[]? |
        select((.type == "created" or .type == "mutated") and
               (.objectType | endswith("::multicoin::Balance")) and
               .owner.AddressOwner == $owner) | .objectId' "$output")
    printf '%s\n' "$sum"
}

declare -A FLOW_STEP_OUTPUTS=()
FLOW_DIR=""
FLOW_SPEC_FILE=""
FLOW_ACTION=""
FLOW_DAO=""
FLOW_VAULT=""
FLOW_FREEZE=""
FLOW_REGISTRY=""
FLOW_COLLECTION=""
FLOW_REWARD=""
FLOW_CARGO=""
FLOW_HAULER_COLLATERAL=""
FLOW_COMPETITOR_COLLATERAL=""
FLOW_SOURCE=""
FLOW_DESTINATION=""
FLOW_LOCAL_AUTH=""
FLOW_REJECTED_STEPS=0
LAST_FLOW_RESULT=""

execute_flow_step() {
    local step="$1" index="$2" op actor role receiver destination expect_abort out label
    op="$(jq -r '.op' <<<"$step")"
    role="$(jq -r '.actor // "lister"' <<<"$step")"
    actor="minehaul-$role"
    expect_abort="$(jq -r '.expectAbort // empty' <<<"$step")"
    printf -v label '%02d-%s' "$index" "$op"
    out="$FLOW_DIR/$label.json"

    if [[ "$op" == "wait-listing-deadline" ]]; then
        wait_for_action_deadline listing_expires_at_ms
        jq -n --arg op "$op" --argjson timestamp "$(clock_timestamp)" \
            '{operation: $op, observedClockMs: $timestamp}' >"$out"
        return
    elif [[ "$op" == "wait-haul-deadline" ]]; then
        wait_for_action_deadline haul_deadline_ms
        jq -n --arg op "$op" --argjson timestamp "$(clock_timestamp)" \
            '{operation: $op, observedClockMs: $timestamp}' >"$out"
        return
    fi

    local -a args=()
    local function="$op"
    case "$op" in
        list)
            args=("$FLOW_DAO" "$FLOW_VAULT" "$FLOW_FREEZE" "$FLOW_SOURCE" "$FLOW_DESTINATION"
                "$FLOW_CARGO" "$FLOW_REWARD"
                "$(jq -r '.config.rewardToHaulerBps' "$FLOW_SPEC_FILE")"
                "$(jq -r '.config.listingTtlMs' "$FLOW_SPEC_FILE")"
                "$(jq -r '.config.haulTtlMs' "$FLOW_SPEC_FILE")" 0x6)
            ;;
        claim)
            local collateral="$FLOW_HAULER_COLLATERAL"
            [[ "$role" != "arbiter" ]] || collateral="$FLOW_COMPETITOR_COLLATERAL"
            args=("$FLOW_ACTION" "$FLOW_DAO" "$collateral" 0x6)
            ;;
        collect|settle|expire|dispute)
            args=("$FLOW_ACTION" "$FLOW_DAO" 0x6)
            ;;
        deliver)
            receiver="$(jq -r '.receiver // "lister"' <<<"$step")"
            destination="$(jq -r '.destination // "destination"' <<<"$step")"
            local receiver_address expected_destination
            receiver_address="$(role_address "$receiver")"
            if [[ "$destination" == "source" ]]; then
                expected_destination="$FLOW_SOURCE"
            else
                expected_destination="$FLOW_DESTINATION"
            fi
            args=("$FLOW_ACTION" "$FLOW_DAO" "$FLOW_REGISTRY" "$FLOW_LOCAL_AUTH"
                "$receiver_address" "$expected_destination" 0x6)
            ;;
        cancel)
            args=("$FLOW_DAO" "$FLOW_VAULT" "$FLOW_FREEZE" "$FLOW_ACTION" 0x6)
            ;;
        resolve)
            args=("$FLOW_DAO" "$FLOW_VAULT" "$FLOW_FREEZE" "$FLOW_ACTION"
                "$(jq -r '.awardToHauler' <<<"$step")" "$(jq -r '.slashBps' <<<"$step")" 0x6)
            ;;
        revoke-delivery-adapter)
            function="revoke_delivery_adapter"
            args=("$FLOW_DAO" "$FLOW_VAULT" "$FLOW_FREEZE" "$FLOW_REGISTRY" "$FLOW_LOCAL_AUTH" 0x6)
            ;;
        pause)
            function="set_paused"
            args=("$FLOW_DAO" "$FLOW_VAULT" "$FLOW_FREEZE" "$(jq -r '.value' <<<"$step")" 0x6)
            ;;
        *) fail "unsupported acceptance operation: $op" ;;
    esac

    if [[ -n "$expect_abort" ]]; then
        call_local_expect_abort "$actor" "$function" "$out" "$expect_abort" "${args[@]}"
        FLOW_REJECTED_STEPS=$((FLOW_REJECTED_STEPS + 1))
        say "ok  $label  rejected/$expect_abort"
        return
    fi

    call_local "$actor" "$function" "$out" "${args[@]}"
    FLOW_STEP_OUTPUTS["$op"]="$out"
    if [[ "$op" == "list" ]]; then
        FLOW_ACTION="$(created_object "$out" '::action::HaulAction')"
        [[ -n "$FLOW_ACTION" ]] || fail "haul action missing"
    fi
    say "ok  $label"
}

assert_flow_result() {
    local expected_status actual_status expected_reward actual_reward expected_collateral actual_collateral
    local expected_cargo actual_cargo actual_dof_reward actual_dof_collateral
    local action_file="$FLOW_DIR/action.json" events_file="$FLOW_DIR/events.json"
    local dynamic_fields_file="$FLOW_DIR/dynamic-fields.json"
    with_home sui client object "$FLOW_ACTION" --json >"$action_file"
    expected_status="$(jq -r '.expected.status' "$FLOW_SPEC_FILE")"
    actual_status="$(jq -r '.content.status["@variant"]' "$action_file")"
    [[ "$actual_status" == "$expected_status" ]] || \
        fail "expected action status $expected_status, got $actual_status"

    expected_reward="$(jq -r '.expected.escrow.reward' "$FLOW_SPEC_FILE")"
    expected_collateral="$(jq -r '.expected.escrow.collateral' "$FLOW_SPEC_FILE")"
    actual_reward="$(jq -r '.content.escrow.reward_amount | tonumber' "$action_file")"
    actual_collateral="$(jq -r '.content.escrow.collateral_amount | tonumber' "$action_file")"
    [[ "$actual_reward" -eq "$expected_reward" && "$actual_collateral" -eq "$expected_collateral" ]] || \
        fail "unexpected escrow: reward=$actual_reward collateral=$actual_collateral"

    with_home sui client dynamic-field "$FLOW_ACTION" --json >"$dynamic_fields_file"
    actual_dof_reward="$(jq '[.dynamicFields[]? |
      select(.fieldObject.objectType | contains("::escrow::RewardKey")) |
      .childObject.json.amount | tonumber] | add // 0' "$dynamic_fields_file")"
    actual_dof_collateral="$(jq '[.dynamicFields[]? |
      select(.fieldObject.objectType | contains("::escrow::CollateralKey")) |
      .childObject.json.amount | tonumber] | add // 0' "$dynamic_fields_file")"
    actual_cargo="$(jq '[.dynamicFields[]? |
      select(.fieldObject.objectType | contains("::action::CargoKey")) |
      .childObject.json.amount | tonumber] | add // 0' "$dynamic_fields_file")"
    expected_cargo="$(jq -r '.expected.escrow.cargo' "$FLOW_SPEC_FILE")"
    [[ "$actual_dof_reward" -eq "$expected_reward" && \
       "$actual_dof_collateral" -eq "$expected_collateral" && \
       "$actual_cargo" -eq "$expected_cargo" ]] || \
        fail "unexpected action balances: reward=$actual_dof_reward collateral=$actual_dof_collateral cargo=$actual_cargo"

    local expected_award
    expected_award="$(jq -r '.expected.awardToHauler // empty' "$FLOW_SPEC_FILE")"
    if [[ -n "$expected_award" ]]; then
        jq -e --argjson award "$expected_award" '.content.status.award_to_hauler == $award' \
            "$action_file" >/dev/null || fail "unexpected dispute award"
    fi

    find "$FLOW_DIR" -maxdepth 1 -name '*.json' \
        ! -name 'action.json' ! -name 'events.json' ! -name 'result.json' -print0 | \
        sort -z | xargs -0 jq -s '[.[] | .events[]? |
          {name: (.type | split("::") | last), type, parsedJson}]' >"$events_file"

    local event expected_count actual_count
    while IFS= read -r event; do
        jq -e --arg event "$event" 'any(.[]; .name == $event)' "$events_file" >/dev/null || \
            fail "expected event missing: $event"
    done < <(jq -r '.expected.events[]' "$FLOW_SPEC_FILE")
    while IFS=$'\t' read -r event expected_count; do
        actual_count="$(jq --arg event "$event" '[.[] | select(.name == $event)] | length' "$events_file")"
        [[ "$actual_count" -eq "$expected_count" ]] || \
            fail "expected $expected_count $event events, got $actual_count"
    done < <(jq -r '.expected.eventCounts // {} | to_entries[] | [.key, .value] | @tsv' "$FLOW_SPEC_FILE")

    local expected_rejected
    expected_rejected="$(jq -r '.expected.rejectedSteps // 0' "$FLOW_SPEC_FILE")"
    [[ "$FLOW_REJECTED_STEPS" -eq "$expected_rejected" ]] || \
        fail "expected $expected_rejected rejected steps, got $FLOW_REJECTED_STEPS"

    local balance_assertions_file="$FLOW_DIR/balance-assertions.json" balance_tmp
    echo '[]' >"$balance_assertions_file"
    balance_tmp="$FLOW_DIR/balance-assertions.tmp.json"
    local step owner asset amount owner_address output actual
    while IFS=$'\t' read -r step owner asset amount; do
        output="${FLOW_STEP_OUTPUTS[$step]:-}"
        [[ -n "$output" ]] || fail "no successful output recorded for balance assertion step $step"
        owner_address="$(role_address "$owner")"
        actual="$(sum_changed_balances "$output" "$owner_address" "$asset")"
        [[ "$actual" -eq "$amount" ]] || \
            fail "balance assertion failed: step=$step owner=$owner asset=$asset expected=$amount got=$actual"
        jq --arg step "$step" --arg owner "$owner" --arg ownerAddress "$owner_address" \
            --argjson assetId "$asset" --argjson expected "$amount" --argjson actual "$actual" \
            '. + [{step: $step, owner: $owner, ownerAddress: $ownerAddress,
              assetId: $assetId, expected: $expected, actual: $actual}]' \
            "$balance_assertions_file" >"$balance_tmp"
        mv "$balance_tmp" "$balance_assertions_file"
    done < <(jq -r '.expected.balances[]? | [.step, .owner, .assetId, .amount] | @tsv' "$FLOW_SPEC_FILE")

    local transactions_file="$FLOW_DIR/transactions.json" file digest
    : >"$transactions_file.tmp"
    while IFS= read -r file; do
        digest="$(jq -r 'if type == "object" then (.digest // empty) else empty end' "$file")"
        [[ -n "$digest" ]] || continue
        jq -n --arg step "$(basename "$file" .json)" --arg digest "$digest" \
            '{step: $step, digest: $digest}' >>"$transactions_file.tmp"
    done < <(find "$FLOW_DIR" -maxdepth 1 -name '*.json' ! -name 'action.json' \
        ! -name 'events.json' ! -name 'result.json' ! -name 'transactions.json' | sort)
    jq -s '.' "$transactions_file.tmp" >"$transactions_file"
    rm -f "$transactions_file.tmp"

    LAST_FLOW_RESULT="$FLOW_DIR/result.json"
    jq -n --slurpfile spec "$FLOW_SPEC_FILE" --slurpfile events "$events_file" \
        --slurpfile transactions "$transactions_file" \
        --slurpfile balances "$balance_assertions_file" \
        --arg package "$(jq -r '.packages.local' "$PROTOCOL_DEPLOYMENT")" \
        --arg dao "$FLOW_DAO" --arg registry "$FLOW_REGISTRY" \
        --arg collection "$FLOW_COLLECTION" --arg action "$FLOW_ACTION" \
        --arg status "$actual_status" --argjson rejected "$FLOW_REJECTED_STEPS" \
        '{schemaVersion: 1, name: $spec[0].name, config: $spec[0].config,
          packageId: $package, daoId: $dao, registryId: $registry,
          collectionId: $collection, actionId: $action, status: $status,
          rejectedSteps: $rejected, transactions: $transactions[0], events: $events[0],
          balances: $balances[0],
          expected: $spec[0].expected}' >"$LAST_FLOW_RESULT"

    local tmp="$RUNTIME_DIR/manifest.tmp.json"
    jq --slurpfile result "$LAST_FLOW_RESULT" \
        '.protocolFlow = $result[0] | .protocolFlows = ((.protocolFlows // []) + [$result[0]])' \
        "$MANIFEST_FILE" >"$tmp"
    mv "$tmp" "$MANIFEST_FILE"
    say "ok  acceptance/$(jq -r '.name' "$FLOW_SPEC_FILE")  $actual_status"
}

run_acceptance_scenario() {
    local scenario="${1:-$DEFAULT_SCENARIO}" scenario_name="${2:-successful-settlement}"
    publish_minehaul "$scenario"
    jq -e --arg name "$scenario_name" '.acceptanceScenarios[] | select(.name == $name)' \
        "$scenario" >/dev/null || fail "acceptance scenario not found: $scenario_name"

    local run_id
    run_id="$(date -u +%Y%m%dT%H%M%S%N)-$$"
    FLOW_DIR="$FLOW_RUNS_DIR/$scenario_name/$run_id"
    mkdir -p "$FLOW_DIR"
    FLOW_SPEC_FILE="$FLOW_DIR/spec.json"
    jq --arg name "$scenario_name" '.protocol as $defaults |
      .acceptanceScenarios[] | select(.name == $name) |
      .config = ($defaults * (.config // {}))' "$scenario" >"$FLOW_SPEC_FILE"
    FLOW_REJECTED_STEPS=0
    FLOW_ACTION=""
    FLOW_STEP_OUTPUTS=()

    local world_auth lister hauler arbiter character source_cap destination_cap
    world_auth="$(jq -r '.adapters.world' "$PROTOCOL_DEPLOYMENT")"
    lister="$(role_address lister)"
    hauler="$(role_address hauler)"
    arbiter="$(role_address arbiter)"
    character="$(jq -r '.objects[] | select(.kind == "character" and .name == "lister") | .objectId' "$MANIFEST_FILE")"
    FLOW_SOURCE="$(jq -r '.objects[] | select(.kind == "storage-unit" and .name == "source") | .objectId' "$MANIFEST_FILE")"
    FLOW_DESTINATION="$(jq -r '.objects[] | select(.kind == "storage-unit" and .name == "destination") | .objectId' "$MANIFEST_FILE")"

    say "executing acceptance scenario: $scenario_name"
    local tx="$FLOW_DIR/00-setup-dao.json"
    call_local minehaul-lister create_dao "$tx"
    FLOW_DAO="$(created_object "$tx" '::dao::DAO')"
    FLOW_VAULT="$(created_object "$tx" '::capability_vault::CapabilityVault')"
    FLOW_FREEZE="$(created_object "$tx" '::emergency::EmergencyFreeze')"
    [[ -n "$FLOW_DAO" && -n "$FLOW_VAULT" && -n "$FLOW_FREEZE" ]] || \
        fail "DAO companion objects missing"

    tx="$FLOW_DIR/00-setup-delivery-auth.json"
    call_local minehaul-lister create_delivery_auth "$tx"
    FLOW_LOCAL_AUTH="$(created_object "$tx" '::witnesses::AdapterAuth')"
    [[ -n "$FLOW_LOCAL_AUTH" ]] || fail "scenario delivery authorization missing"

    tx="$FLOW_DIR/00-setup-enable-types.json"
    call_local minehaul-lister enable_types "$tx" "$FLOW_DAO" "$FLOW_VAULT" "$FLOW_FREEZE" 0x6

    local reward_amount cargo_amount collateral_amount
    reward_amount="$(jq -r '.config.rewardAmount' "$FLOW_SPEC_FILE")"
    cargo_amount="$(jq -r '.config.cargoAmount' "$FLOW_SPEC_FILE")"
    collateral_amount="$(jq -r '.config.collateralAmount' "$FLOW_SPEC_FILE")"
    tx="$FLOW_DIR/00-setup-assets.json"
    call_local minehaul-lister create_assets "$tx" \
        "$hauler" "$arbiter" "$reward_amount" "$cargo_amount" "$collateral_amount"
    FLOW_COLLECTION="$(created_object "$tx" '::multicoin::Collection')"
    FLOW_REWARD="$(find_owned_balance "$tx" 0 "$reward_amount" "$lister")"
    FLOW_CARGO="$(find_owned_balance "$tx" 1 "$cargo_amount" "$lister")"
    FLOW_HAULER_COLLATERAL="$(find_owned_balance "$tx" 0 "$collateral_amount" "$hauler")"
    FLOW_COMPETITOR_COLLATERAL="$(find_owned_balance "$tx" 0 "$collateral_amount" "$arbiter")"

    tx="$FLOW_DIR/00-setup-configure.json"
    call_local minehaul-lister configure "$tx" "$FLOW_DAO" "$FLOW_VAULT" "$FLOW_FREEZE" \
        "$FLOW_COLLECTION" "$arbiter" \
        "$(jq -r '.config.minCollateralRatioBps' "$FLOW_SPEC_FILE")" \
        "$(jq -r '.config.disputeWindowMs' "$FLOW_SPEC_FILE")" 0x6
    FLOW_REGISTRY="$(created_object "$tx" '::witnesses::AdapterRegistry')"
    [[ -n "$FLOW_REGISTRY" ]] || fail "adapter registry missing"

    tx="$FLOW_DIR/00-setup-register-adapters.json"
    call_local minehaul-lister register_adapters "$tx" "$FLOW_DAO" "$FLOW_VAULT" \
        "$FLOW_FREEZE" "$FLOW_REGISTRY" "$world_auth" "$FLOW_LOCAL_AUTH" 0x6
    source_cap="$(find_owner_cap "$character" "$FLOW_SOURCE")"
    destination_cap="$(find_owner_cap "$character" "$FLOW_DESTINATION")"
    [[ -n "$source_cap" && -n "$destination_cap" ]] || fail "SSU OwnerCaps missing"
    tx="$FLOW_DIR/00-setup-register-endpoints.json"
    call_local minehaul-lister register_endpoints "$tx" "$FLOW_DAO" "$FLOW_VAULT" \
        "$FLOW_FREEZE" "$FLOW_REGISTRY" "$world_auth" "$character" \
        "$FLOW_SOURCE" "$source_cap" "$FLOW_DESTINATION" "$destination_cap" 0x6

    local step index=0
    while IFS= read -r step; do
        index=$((index + 1))
        execute_flow_step "$step" "$index"
    done < <(jq -c '.steps[]' "$FLOW_SPEC_FILE")
    assert_flow_result
}

run_live_flow() {
    run_acceptance_scenario "${1:-$DEFAULT_SCENARIO}" "${2:-successful-settlement}"
}

run_acceptance_matrix() {
    local scenario="${1:-$DEFAULT_SCENARIO}" scenario_name
    validate_scenario "$scenario"
    reset
    local -a results=()
    while IFS= read -r scenario_name; do
        run_acceptance_scenario "$scenario" "$scenario_name"
        results+=("$LAST_FLOW_RESULT")
    done < <(jq -r '.acceptanceScenarios[].name' "$scenario")
    jq -s '{schemaVersion: 1, status: "passed", scenarios: map({name, status,
      actionId, rejectedSteps})}' "${results[@]}" >"$MATRIX_MANIFEST"
    say "ok  acceptance-matrix/$(jq '.scenarios | length' "$MATRIX_MANIFEST")  passed"
    say "manifest: $MATRIX_MANIFEST"
}

run_tests() {
    local scenario="${1:-$DEFAULT_SCENARIO}"
    doctor "$scenario" >/dev/null
    say "running Minehaul package and security tests"
    local package
    for package in "$ROOT_DIR"/packages/*; do
        sui move build --path "$package" -e testnet
        SUI_SKIP_SHARED_OBJECTS_VERSION_CHECK=1 sui move test --path "$package" -e testnet -i 100000000
    done
    sui move build --path "$ROOT_DIR/integration/game/move" -e testnet
    bash "$ROOT_DIR/scripts/check-security-boundaries.sh"
    run_acceptance_matrix "$scenario"
}

down() {
    if [[ ! -f "$PID_FILE" ]]; then
        say "local game chain is not running"
        return
    fi
    local pid
    pid="$(cat "$PID_FILE")"
    if kill -0 "$pid" 2>/dev/null; then
        kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
        local attempt
        for attempt in $(seq 1 20); do
            kill -0 "$pid" 2>/dev/null || break
            sleep 0.25
        done
    fi
    rm -f "$PID_FILE"
    say "local game chain stopped"
}

reset() {
    down
    rm -rf "$STATE_DIR"
    say "local game state removed"
}

status() {
    if is_running; then
        say "running: $RPC_URL"
        [[ ! -s "$MANIFEST_FILE" ]] || jq . "$MANIFEST_FILE"
    else
        say "stopped"
        return 1
    fi
}

usage() {
    cat <<'EOF'
Usage: ./scripts/game-env.sh COMMAND [SCENARIO] [CASE]

Commands:
  doctor    Validate local prerequisites and scenario JSON
  up        Start the isolated local Sui network
  seed      Deploy the pinned world and seed the scenario
  verify    Seed if needed, then verify every live fixture object
  publish   Publish Minehaul and the local delivery bridge to the local chain
  flow      Run one named acceptance case (default: successful-settlement)
  matrix    Reset, then run every acceptance case from fresh genesis
  cases     List acceptance case names from the scenario
  test      Run Move/security tests and the fresh-genesis acceptance matrix
  status    Show process status and the generated manifest
  manifest  Print the generated manifest
  logs      Follow the local Sui log
  down      Stop the local network and preserve state
  reset     Stop and delete disposable local state
EOF
}

command="${1:-}"
scenario="${2:-$DEFAULT_SCENARIO}"
acceptance_case="${3:-successful-settlement}"
case "$command" in
    doctor) doctor "$scenario" ;;
    up) up "$scenario" ;;
    seed) seed "$scenario" ;;
    verify) verify "$scenario" ;;
    publish) publish_minehaul "$scenario" ;;
    flow) run_live_flow "$scenario" "$acceptance_case" ;;
    matrix) run_acceptance_matrix "$scenario" ;;
    cases) validate_scenario "$scenario"; jq -r '.acceptanceScenarios[].name' "$scenario" ;;
    test) run_tests "$scenario" ;;
    status) status ;;
    manifest) [[ -s "$MANIFEST_FILE" ]] || fail "manifest not created; run seed"; jq . "$MANIFEST_FILE" ;;
    logs) [[ -f "$LOG_FILE" ]] || fail "log not created; run up"; tail -f "$LOG_FILE" ;;
    down) down ;;
    reset) reset ;;
    -h|--help|help|'') usage ;;
    *) usage >&2; fail "unknown command: $command" ;;
esac
