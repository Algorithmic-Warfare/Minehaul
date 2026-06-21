#[test_only]
module minehaul_world_v0::adapter_tests;

use sui::object;
use sui::clock;
use sui::test_scenario as ts;
use sui::transfer;
use minehaul_core::witnesses::{Self, AdapterRegistry};
use minehaul_world_v0::adapter;

const ADMIN: address = @0xA;
const NETWORK_ADDR: address = @0xCAFE;

fun net(): object::ID { object::id_from_address(NETWORK_ADDR) }

// === init / world_version ===

#[test]
fun test_init_for_testing_returns_unrevoked_v0_auth() {
    let mut scenario = ts::begin(ADMIN);
    let auth = adapter::init_for_testing(scenario.ctx());
    assert!(!witnesses::auth_revoked(&auth), 0);
    assert!(witnesses::auth_world_version(&auth) == 0, 1);
    assert!(witnesses::auth_adapter_pkg(&auth) == @minehaul_world_v0, 2);
    transfer::public_transfer(auth, ADMIN);
    scenario.end();
}

#[test]
fun test_world_version_constant() {
    assert!(adapter::world_version() == 0, 0);
}

// === End-to-end witness path: adapter mints, witness flows through registry ===

#[test]
fun test_authorized_adapter_can_mint_ssu_witness() {
    let mut scenario = ts::begin(ADMIN);
    let auth = adapter::init_for_testing(scenario.ctx());

    let mut registry: AdapterRegistry =
        witnesses::new_registry_for_test(net(), vector[], scenario.ctx());
    witnesses::register_for_test(&mut registry, object::id(&auth));

    let mut c = clock::create_for_testing(scenario.ctx());
    clock::increment_for_testing(&mut c, 1_000);

    let ssu_id = object::id_from_address(@0xF00D);
    let owner_id = object::id_from_address(@0x123);
    let vssu = witnesses::mint_verified_ssu(&auth, &registry, ssu_id, owner_id, &c);

    assert!(witnesses::vssu_id(&vssu) == ssu_id, 0);
    assert!(witnesses::vssu_network(&vssu) == net(), 1);
    assert!(witnesses::vssu_owner(&vssu) == owner_id, 2);
    assert!(witnesses::vssu_verified_at_ms(&vssu) == 1_000, 3);

    transfer::public_transfer(auth, ADMIN);
    witnesses::share_registry(registry);
    clock::destroy_for_testing(c);
    scenario.end();
}

#[test, expected_failure(abort_code = 19)] // EAdapterNotRegistered
fun test_unauthorized_adapter_cannot_mint() {
    let mut scenario = ts::begin(ADMIN);
    let auth = adapter::init_for_testing(scenario.ctx());

    // Note: registry never gets `register_for_test` for this auth.
    let registry = witnesses::new_registry_for_test(net(), vector[], scenario.ctx());
    let c = clock::create_for_testing(scenario.ctx());

    let _vssu = witnesses::mint_verified_ssu(
        &auth, &registry,
        object::id_from_address(@0xF00D),
        object::id_from_address(@0x123),
        &c,
    );

    transfer::public_transfer(auth, ADMIN);
    witnesses::share_registry(registry);
    clock::destroy_for_testing(c);
    scenario.end();
}
