/// Hot-potato witnesses and adapter registry. The only modules that mint
/// `VerifiedSsu`, `VerifiedGate`, or `MintedPermit` are the world adapter
/// packages (minehaul_world_v0 / minehaul_world_v1). Adapters identify
/// themselves with an `AdapterAuth` registered into a per-LogisticNetwork
/// `AdapterRegistry`. Core consumes the hot potatoes in-place; it never
/// stores or copies them.
module minehaul_core::witnesses;

use sui::object::{Self, ID, UID};
use sui::tx_context::TxContext;
use sui::clock::{Self, Clock};
use sui::transfer;
use armature::proposal::ExecutionRequest;
use minehaul_core::errors;

/// Long-lived adapter identity. One per published adapter package. After
/// registration via `register_adapter`, the holder of `&AdapterAuth` can mint
/// the verification witnesses below for as long as `revoked == false`.
public struct AdapterAuth has key, store {
    id: UID,
    adapter_pkg: address,
    world_version: u8,
    revoked: bool,
}

/// Per-LogisticNetwork list of `AdapterAuth` IDs currently allowed to mint
/// witnesses for actions on this network. Registered/revoked via
/// `ExecutionRequest`-gated functions.
public struct AdapterRegistry has key {
    id: UID,
    network_id: ID,
    authorized: vector<ID>,
}

/// Proof that the adapter has confirmed `ssu_id` is a deployed, online,
/// owner-verified Smart Storage Unit at this point in the tx. Cannot be
/// stored; must be consumed same-tx.
public struct VerifiedSsu has drop {
    ssu_id: ID,
    network_id: ID,
    owner_char_id: ID,
    verified_at_ms: u64,
}

/// Proof that `gate_id` is a deployed, online, in-network Gate. Hot potato.
public struct VerifiedGate has drop {
    gate_id: ID,
    network_id: ID,
    location_id: ID,
    verified_at_ms: u64,
}

/// Proof that the adapter has minted (and the world-contracts gate will
/// honor) one jump permit through `gate_id`, bound to a specific route and
/// hauler. Hot potato; consumed by `route::verify_hop`.
public struct MintedPermit has drop {
    gate_id: ID,
    route_hash: vector<u8>,
    hauler: address,
    expires_at_ms: u64,
}

// === Registry lifecycle (ExecutionRequest-gated) ===

/// Spawn an empty registry for a LogisticNetwork. Called once during network
/// init by `network::init_network`.
public(package) fun new_registry<P>(
    network_id: ID,
    _req: &ExecutionRequest<P>,
    ctx: &mut TxContext,
): AdapterRegistry {
    AdapterRegistry {
        id: object::new(ctx),
        network_id,
        authorized: vector::empty<ID>(),
    }
}

/// Share the AdapterRegistry. Safe to be `public`: the only way to obtain an
/// unshared registry is `new_registry`, which is gated on `ExecutionRequest`.
public fun share_registry(registry: AdapterRegistry) {
    transfer::share_object(registry);
}

/// Authorize an `AdapterAuth` ID on this network's registry. The auth object
/// itself stays with the adapter; the registry just records that its ID is
/// trusted here.
public(package) fun register_adapter<P>(
    registry: &mut AdapterRegistry,
    auth_id: ID,
    _req: &ExecutionRequest<P>,
) {
    assert!(!registry.authorized.contains(&auth_id), errors::already_registered());
    registry.authorized.push_back(auth_id);
}

/// Flip an authorized adapter to revoked AND remove it from the registry.
/// After this, witness mint calls using `auth` abort with `EAdapterRevoked`,
/// and re-authorization would require a fresh `register_adapter` (the same
/// auth ID can't be re-added because `revoked` stays true on the object).
public(package) fun revoke_adapter<P>(
    registry: &mut AdapterRegistry,
    auth: &mut AdapterAuth,
    _req: &ExecutionRequest<P>,
) {
    auth.revoked = true;
    let auth_id = object::id(auth);
    let (found, idx) = registry.authorized.index_of(&auth_id);
    if (found) {
        registry.authorized.remove(idx);
    };
}

// === Adapter-publish helpers (called by adapter `init` functions) ===

/// Construct a fresh `AdapterAuth`. The adapter's `init` calls this once and
/// transfers the result to itself (or a DAO-controlled custodian).
public fun new_auth(
    adapter_pkg: address,
    world_version: u8,
    ctx: &mut TxContext,
): AdapterAuth {
    AdapterAuth {
        id: object::new(ctx),
        adapter_pkg,
        world_version,
        revoked: false,
    }
}

// === Witness mint (called by adapter modules) ===
// These are `public` so adapters in sibling packages can call them, but each
// requires `&AdapterAuth` + `&AdapterRegistry` matching the network and
// passes `errors::EAdapterRevoked` / `EAdapterNotRegistered` /
// `EAdapterNetworkMismatch` if the auth is invalid.

public fun mint_verified_ssu(
    auth: &AdapterAuth,
    registry: &AdapterRegistry,
    ssu_id: ID,
    owner_char_id: ID,
    clock: &Clock,
): VerifiedSsu {
    assert_auth_authorized(auth, registry);
    VerifiedSsu {
        ssu_id,
        network_id: registry.network_id,
        owner_char_id,
        verified_at_ms: clock::timestamp_ms(clock),
    }
}

public fun mint_verified_gate(
    auth: &AdapterAuth,
    registry: &AdapterRegistry,
    gate_id: ID,
    location_id: ID,
    clock: &Clock,
): VerifiedGate {
    assert_auth_authorized(auth, registry);
    VerifiedGate {
        gate_id,
        network_id: registry.network_id,
        location_id,
        verified_at_ms: clock::timestamp_ms(clock),
    }
}

public fun mint_permit(
    auth: &AdapterAuth,
    registry: &AdapterRegistry,
    gate_id: ID,
    route_hash: vector<u8>,
    hauler: address,
    ttl_ms: u64,
    clock: &Clock,
): MintedPermit {
    assert_auth_authorized(auth, registry);
    let expires_at_ms = clock::timestamp_ms(clock) + ttl_ms;
    MintedPermit {
        gate_id,
        route_hash,
        hauler,
        expires_at_ms,
    }
}

/// Shared mint precondition: auth not revoked AND auth's ID is recorded in
/// this network's registry. Network binding propagates via the witnesses'
/// `network_id` field (set from `registry.network_id`).
fun assert_auth_authorized(auth: &AdapterAuth, registry: &AdapterRegistry) {
    assert!(!auth.revoked, errors::adapter_revoked());
    let auth_id = object::id(auth);
    assert!(registry.authorized.contains(&auth_id), errors::adapter_not_registered());
}

// === Accessors ===

public fun auth_revoked(self: &AdapterAuth): bool { self.revoked }
public fun auth_world_version(self: &AdapterAuth): u8 { self.world_version }
public fun auth_adapter_pkg(self: &AdapterAuth): address { self.adapter_pkg }

public fun registry_network_id(self: &AdapterRegistry): ID { self.network_id }
public fun registry_authorized(self: &AdapterRegistry): &vector<ID> { &self.authorized }

public fun vssu_id(v: &VerifiedSsu): ID { v.ssu_id }
public fun vssu_network(v: &VerifiedSsu): ID { v.network_id }
public fun vssu_owner(v: &VerifiedSsu): ID { v.owner_char_id }
public fun vssu_verified_at_ms(v: &VerifiedSsu): u64 { v.verified_at_ms }

public fun vgate_id(v: &VerifiedGate): ID { v.gate_id }
public fun vgate_network(v: &VerifiedGate): ID { v.network_id }
public fun vgate_location(v: &VerifiedGate): ID { v.location_id }

public fun permit_gate(p: &MintedPermit): ID { p.gate_id }
public fun permit_route_hash(p: &MintedPermit): &vector<u8> { &p.route_hash }
public fun permit_hauler(p: &MintedPermit): address { p.hauler }
public fun permit_expires_at_ms(p: &MintedPermit): u64 { p.expires_at_ms }

/// Destructure consumers — called by `route` / `action` modules to read
/// fields out of the hot potato at the moment they consume it.
public(package) fun consume_verified_ssu(v: VerifiedSsu): (ID, ID, ID, u64) {
    let VerifiedSsu { ssu_id, network_id, owner_char_id, verified_at_ms } = v;
    (ssu_id, network_id, owner_char_id, verified_at_ms)
}

public(package) fun consume_verified_gate(v: VerifiedGate): (ID, ID, ID, u64) {
    let VerifiedGate { gate_id, network_id, location_id, verified_at_ms } = v;
    (gate_id, network_id, location_id, verified_at_ms)
}

public(package) fun consume_permit(p: MintedPermit): (ID, vector<u8>, address, u64) {
    let MintedPermit { gate_id, route_hash, hauler, expires_at_ms } = p;
    (gate_id, route_hash, hauler, expires_at_ms)
}

// === Test-only constructors ===
// Bypass the AdapterAuth + AdapterRegistry plumbing so unit tests can mint
// hot potatoes directly. NEVER add non-test-only callers to these.

#[test_only]
public fun new_verified_ssu_for_test(
    ssu_id: ID,
    network_id: ID,
    owner_char_id: ID,
    verified_at_ms: u64,
): VerifiedSsu {
    VerifiedSsu { ssu_id, network_id, owner_char_id, verified_at_ms }
}

#[test_only]
public fun new_verified_gate_for_test(
    gate_id: ID,
    network_id: ID,
    location_id: ID,
    verified_at_ms: u64,
): VerifiedGate {
    VerifiedGate { gate_id, network_id, location_id, verified_at_ms }
}

#[test_only]
public fun new_minted_permit_for_test(
    gate_id: ID,
    route_hash: vector<u8>,
    hauler: address,
    expires_at_ms: u64,
): MintedPermit {
    MintedPermit { gate_id, route_hash, hauler, expires_at_ms }
}

#[test_only]
public fun new_registry_for_test(
    network_id: ID,
    authorized: vector<ID>,
    ctx: &mut TxContext,
): AdapterRegistry {
    AdapterRegistry {
        id: object::new(ctx),
        network_id,
        authorized,
    }
}

#[test_only]
public fun register_for_test(registry: &mut AdapterRegistry, auth_id: ID) {
    registry.authorized.push_back(auth_id);
}

#[test_only]
public fun set_revoked_for_test(auth: &mut AdapterAuth) {
    auth.revoked = true;
}

