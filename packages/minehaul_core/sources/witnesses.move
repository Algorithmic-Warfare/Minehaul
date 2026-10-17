/// Transaction-local proofs and adapter registry. Minting requires both an
/// authorized capability and a compiler-issued permit from the module defining
/// its adapter marker. SSU proofs can be dropped, but never stored or copied.
/// Delivery obligations and proofs have no abilities at all.
module minehaul_core::witnesses;

use std::internal::Permit;
use std::type_name::{Self, TypeName};
use sui::object::{Self, ID, UID};
use sui::tx_context::TxContext;
use sui::clock::{Self, Clock};
use sui::transfer;
use armature::proposal::ExecutionRequest;
use minehaul_core::{errors, events};

/// Long-lived adapter identity, bound to the defining module of its marker.
/// The capability alone does not permit minting proofs. Adapter packages
/// normally construct one in init and register its exact object ID.
public struct AdapterAuth has key, store {
    id: UID,
    adapter_type: TypeName,
    adapter_pkg: address,
    world_version: u8,
    revoked: bool,
}

/// Per-LogisticNetwork list of `AdapterAuth` IDs currently allowed to mint
/// witnesses for actions on this network. Registered/revoked via
/// `ExecutionRequest`-gated functions.
///
/// INVARIANT: has only `key` — NOT `store`. Combined with the
/// `ExecutionRequest`-gated `new_registry` constructor, this prevents any
/// caller from holding an unshared registry off-chain. If a future refactor
/// adds `store`, audit every callsite that consumes one by value.
public struct AdapterRegistry has key {
    id: UID,
    network_id: ID,
    authorized: vector<ID>,
    governance_type: Option<TypeName>,
}

/// Adapter-verified SSU identity and capability authorization. Operational
/// state and character-binding guarantees depend on the adapter. This proof
/// can be discarded but cannot escape the transaction or be copied.
public struct VerifiedSsu has drop {
    ssu_id: ID,
    network_id: ID,
    owner_char_id: ID,
    verified_at_ms: u64,
}

// === Registry lifecycle (ExecutionRequest-gated) ===

/// Spawn an empty registry for a LogisticNetwork. Called once during network
/// init by `network::init_network`.
public(package) fun new_registry<P>(
    network_id: ID,
    req: &ExecutionRequest<P>,
    ctx: &mut TxContext,
): AdapterRegistry {
    assert!(req.req_dao_id() == network_id, errors::wrong_dao());
    AdapterRegistry {
        id: object::new(ctx),
        network_id,
        authorized: vector[],
        governance_type: option::some(type_name::with_defining_ids<P>()),
    }
}

/// Share the AdapterRegistry. Safe to be `public`: the only way to obtain an
/// unshared registry is `new_registry`, which is gated on `ExecutionRequest`.
public fun share_registry(registry: AdapterRegistry) {
    transfer::share_object(registry);
}

/// Authorize an `AdapterAuth` on this network's registry. Takes `&AdapterAuth`
/// (not just an `ID`) so a retired auth can be rejected statically — once
/// retired by its adapter, an auth is dead globally and registering it is
/// meaningless.
public fun register_adapter<P>(
    _permit: Permit<P>,
    registry: &mut AdapterRegistry,
    auth: &AdapterAuth,
    req: &ExecutionRequest<P>,
) {
    assert_registry_request(registry, req);
    assert!(!auth.revoked, errors::adapter_revoked());
    let auth_id = object::id(auth);
    assert!(!registry.authorized.contains(&auth_id), errors::already_registered());
    registry.authorized.push_back(auth_id);
    events::emit_adapter_registered(events::new_adapter_registered(
        registry.network_id, auth_id, auth.adapter_pkg, auth.world_version,
    ));
}

/// Remove an authorized adapter from THIS registry only. Auths are shared and
/// any DAO can stand up a network that registers one, so a network's
/// governance must never be able to disable an adapter for other networks.
/// The same governance may register the auth again later. Global retirement
/// belongs to the adapter itself (`retire_auth`).
public fun revoke_adapter<P>(
    _permit: Permit<P>,
    registry: &mut AdapterRegistry,
    auth: &AdapterAuth,
    req: &ExecutionRequest<P>,
) {
    assert_registry_request(registry, req);
    let auth_id = object::id(auth);
    let (found, idx) = registry.authorized.index_of(&auth_id);
    assert!(found, errors::adapter_not_registered());
    registry.authorized.remove(idx);
    events::emit_adapter_revoked(events::new_adapter_revoked(registry.network_id, auth_id));
}

/// Terminal, global kill switch: every mint on every network aborts with
/// `EAdapterRevoked` afterwards. Only the defining module of the auth's marker
/// can issue the permit, so the adapter package decides who may retire it.
public fun retire_auth<A>(_permit: Permit<A>, auth: &mut AdapterAuth) {
    assert!(auth.adapter_type == type_name::with_defining_ids<A>(), errors::adapter_not_registered());
    assert!(!auth.revoked, errors::adapter_revoked());
    auth.revoked = true;
    events::emit_adapter_retired(events::new_adapter_retired(object::id(auth)));
}

// === Adapter-publish helpers (called by adapter `init` functions) ===

/// Construct a fresh `AdapterAuth`. The adapter's `init` calls this once and
/// transfers the result to itself (or a DAO-controlled custodian).
public fun new_auth<A>(
    _permit: Permit<A>,
    adapter_pkg: address,
    world_version: u8,
    ctx: &mut TxContext,
): AdapterAuth {
    AdapterAuth {
        id: object::new(ctx),
        adapter_type: type_name::with_defining_ids<A>(),
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

public fun mint_verified_ssu<A>(
    _permit: Permit<A>,
    auth: &AdapterAuth,
    registry: &AdapterRegistry,
    ssu_id: ID,
    owner_char_id: ID,
    clock: &Clock,
): VerifiedSsu {
    assert_auth_authorized<A>(auth, registry);
    VerifiedSsu {
        ssu_id,
        network_id: registry.network_id,
        owner_char_id,
        verified_at_ms: clock::timestamp_ms(clock),
    }
}

/// Shared mint precondition: auth not revoked AND auth's ID is recorded in
/// this network's registry. Network binding propagates via the witnesses'
/// `network_id` field (set from `registry.network_id`).
fun assert_auth_authorized<A>(auth: &AdapterAuth, registry: &AdapterRegistry) {
    assert!(!auth.revoked, errors::adapter_revoked());
    let auth_id = object::id(auth);
    assert!(registry.authorized.contains(&auth_id), errors::adapter_not_registered());
    assert!(auth.adapter_type == type_name::with_defining_ids<A>(), errors::adapter_not_registered());
}

// === Accessors ===

public fun auth_revoked(self: &AdapterAuth): bool { self.revoked }
public fun auth_world_version(self: &AdapterAuth): u8 { self.world_version }
public fun auth_adapter_type(self: &AdapterAuth): TypeName { self.adapter_type }
public fun auth_adapter_pkg(self: &AdapterAuth): address { self.adapter_pkg }

public fun registry_network_id(self: &AdapterRegistry): ID { self.network_id }
public fun registry_authorized(self: &AdapterRegistry): &vector<ID> { &self.authorized }

public fun vssu_id(v: &VerifiedSsu): ID { v.ssu_id }
public fun vssu_network(v: &VerifiedSsu): ID { v.network_id }
public fun vssu_owner(v: &VerifiedSsu): ID { v.owner_char_id }
public fun vssu_verified_at_ms(v: &VerifiedSsu): u64 { v.verified_at_ms }

/// Destructure consumer — called by `network` / `action` modules to read
/// fields out of the hot potato at the moment they consume it.
public(package) fun consume_verified_ssu(v: VerifiedSsu): (ID, ID, ID, u64) {
    let VerifiedSsu { ssu_id, network_id, owner_char_id, verified_at_ms } = v;
    (ssu_id, network_id, owner_char_id, verified_at_ms)
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
public fun new_registry_for_test(
    network_id: ID,
    authorized: vector<ID>,
    ctx: &mut TxContext,
): AdapterRegistry {
    AdapterRegistry {
        id: object::new(ctx),
        network_id,
        authorized,
        governance_type: option::none(),
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

fun assert_registry_request<P>(registry: &AdapterRegistry, req: &ExecutionRequest<P>) {
    assert!(registry.network_id == req.req_dao_id(), errors::wrong_dao());
    if (registry.governance_type.is_some()) {
        assert!(*registry.governance_type.borrow() == type_name::with_defining_ids<P>(), errors::wrong_dao());
    };
}

/// Neither value has abilities: withdrawing cargo must end in adapter-verified
/// delivery and core completion in the same transaction, or the transaction aborts.
public struct DeliveryRequest {
    action_id: ID,
    network_id: ID,
    registry_id: ID,
    destination: ID,
    hauler: address,
    manifest_hash: vector<u8>,
}

public struct VerifiedDelivery {
    request: DeliveryRequest,
}

public(package) fun new_delivery_request(
    action_id: ID, network_id: ID, registry_id: ID, destination: ID,
    hauler: address, manifest_hash: vector<u8>,
): DeliveryRequest {
    DeliveryRequest { action_id, network_id, registry_id, destination, hauler, manifest_hash }
}

/// Only the defining module of the registered adapter's marker can attest.
/// It MUST verify actual delivery of the entire manifest before calling this.
/// An SSU ownership/existence check alone is insufficient.
public fun certify_delivery<A>(
    _permit: Permit<A>, auth: &AdapterAuth, registry: &AdapterRegistry,
    request: DeliveryRequest,
): VerifiedDelivery {
    assert_auth_authorized<A>(auth, registry);
    assert!(request.network_id == registry.network_id
        && request.registry_id == object::id(registry), errors::adapter_network_mismatch());
    VerifiedDelivery { request }
}

public fun delivery_action(r: &DeliveryRequest): ID { r.action_id }
public fun delivery_destination(r: &DeliveryRequest): ID { r.destination }
public fun delivery_hauler(r: &DeliveryRequest): address { r.hauler }
public fun delivery_manifest_hash(r: &DeliveryRequest): &vector<u8> { &r.manifest_hash }

public(package) fun consume_delivery(proof: VerifiedDelivery): (ID, ID, ID, address, vector<u8>) {
    let VerifiedDelivery { request } = proof;
    let DeliveryRequest { action_id, network_id, registry_id: _, destination, hauler, manifest_hash } = request;
    (action_id, network_id, destination, hauler, manifest_hash)
}
