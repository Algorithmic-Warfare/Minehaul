#[test_only]
module minehaul_core::witnesses_tests;

use std::internal;
use sui::object;
use sui::clock;
use sui::test_scenario as ts;
use sui::transfer;
use minehaul_core::witnesses::{Self, AdapterAuth, AdapterRegistry};

const ADMIN: address = @0xA;
const NETWORK_ADDR: address = @0xCAFE;
const SSU_ADDR: address = @0xF00D;
const OWNER_ADDR: address = @0x123;

const NOW_MS: u64 = 1_000_000;

fun net(): object::ID { object::id_from_address(NETWORK_ADDR) }

fun setup_clock(scenario: &mut ts::Scenario): clock::Clock {
    let mut c = clock::create_for_testing(scenario.ctx());
    clock::increment_for_testing(&mut c, NOW_MS);
    c
}

// === new_auth ===

#[test]
fun test_new_auth_starts_unrevoked() {
    let mut scenario = ts::begin(ADMIN);
    let auth = witnesses::new_auth(internal::permit<NETWORK_WITNESS>(), @minehaul_core, 0, scenario.ctx());
    assert!(!witnesses::auth_revoked(&auth), 0);
    assert!(witnesses::auth_world_version(&auth) == 0, 1);
    assert!(witnesses::auth_adapter_pkg(&auth) == @minehaul_core, 2);
    transfer::public_transfer(auth, ADMIN);
    scenario.end();
}

// === mint_verified_ssu happy + abort paths ===

#[test]
fun test_mint_verified_ssu_happy_path() {
    let mut scenario = ts::begin(ADMIN);
    let auth = witnesses::new_auth(internal::permit<NETWORK_WITNESS>(), @minehaul_core, 0, scenario.ctx());
    let mut registry = witnesses::new_registry_for_test(net(), vector[], scenario.ctx());
    witnesses::register_for_test(&mut registry, object::id(&auth));
    let c = setup_clock(&mut scenario);

    let vssu = witnesses::mint_verified_ssu(internal::permit<NETWORK_WITNESS>(),
        &auth,
        &registry,
        object::id_from_address(SSU_ADDR),
        object::id_from_address(OWNER_ADDR),
        &c,
    );
    assert!(witnesses::vssu_id(&vssu) == object::id_from_address(SSU_ADDR), 0);
    assert!(witnesses::vssu_network(&vssu) == net(), 1);
    assert!(witnesses::vssu_owner(&vssu) == object::id_from_address(OWNER_ADDR), 2);
    assert!(witnesses::vssu_verified_at_ms(&vssu) == NOW_MS, 3);

    transfer::public_transfer(auth, ADMIN);
    witnesses::share_registry(registry);
    clock::destroy_for_testing(c);
    scenario.end();
}

#[test, expected_failure(abort_code = 19)] // EAdapterNotRegistered
fun test_mint_verified_ssu_aborts_when_not_registered() {
    let mut scenario = ts::begin(ADMIN);
    let auth = witnesses::new_auth(internal::permit<NETWORK_WITNESS>(), @minehaul_core, 0, scenario.ctx());
    // registry exists but auth is NOT in authorized
    let registry = witnesses::new_registry_for_test(net(), vector[], scenario.ctx());
    let c = setup_clock(&mut scenario);
    let _vssu = witnesses::mint_verified_ssu(internal::permit<NETWORK_WITNESS>(),
        &auth, &registry,
        object::id_from_address(SSU_ADDR),
        object::id_from_address(OWNER_ADDR),
        &c,
    );
    // unreachable cleanup
    transfer::public_transfer(auth, ADMIN);
    witnesses::share_registry(registry);
    clock::destroy_for_testing(c);
    scenario.end();
}

#[test, expected_failure(abort_code = 18)] // EAdapterRevoked
fun test_mint_verified_ssu_aborts_when_revoked() {
    let mut scenario = ts::begin(ADMIN);
    let mut auth = witnesses::new_auth(internal::permit<NETWORK_WITNESS>(), @minehaul_core, 0, scenario.ctx());
    let mut registry = witnesses::new_registry_for_test(net(), vector[], scenario.ctx());
    witnesses::register_for_test(&mut registry, object::id(&auth));
    // Bypass ExecutionRequest-gated revoke_adapter; the assert_auth_authorized
    // path is what we're exercising here, not the registry mutation.
    witnesses::set_revoked_for_test(&mut auth);
    let c = setup_clock(&mut scenario);
    let _vssu = witnesses::mint_verified_ssu(internal::permit<NETWORK_WITNESS>(),
        &auth, &registry,
        object::id_from_address(SSU_ADDR),
        object::id_from_address(OWNER_ADDR),
        &c,
    );
    transfer::public_transfer(auth, ADMIN);
    witnesses::share_registry(registry);
    clock::destroy_for_testing(c);
    scenario.end();
}

// === Production register_adapter + revoke_adapter end-to-end ===
//
// Uses armature::proposal::new_execution_request_for_testing so the real
// ExecutionRequest-gated entries are exercised, not the test_only fast-track
// helpers.

#[test]
fun test_register_and_revoke_adapter_full_path() {
    use armature::proposal;
    let mut scenario = ts::begin(ADMIN);
    let mut auth = witnesses::new_auth(internal::permit<NETWORK_WITNESS>(), @minehaul_core, 0, scenario.ctx());
    let auth_id = object::id(&auth);

    // Build a registry directly (production path is new_registry, also
    // ExecutionRequest-gated; we use new_registry_for_test to avoid the
    // armature dao_id round trip — only the auth-registration path is what
    // we want to exercise end-to-end here).
    let mut registry = witnesses::new_registry_for_test(net(), vector[], scenario.ctx());

    // Mint a real ExecutionRequest via armature's test helper.
    let dao_id = object::id_from_address(NETWORK_ADDR);
    let proposal_id = object::id_from_address(@0xDEADBEEF);
    let req = proposal::new_execution_request_for_testing<NETWORK_WITNESS>(dao_id, proposal_id);

    // Production register_adapter: must succeed once.
    witnesses::register_adapter<NETWORK_WITNESS>(internal::permit<NETWORK_WITNESS>(), &mut registry, &auth, &req);
    assert!(registry.registry_authorized().contains(&auth_id), 0);

    // Production revoke_adapter: flips flag AND removes the ID.
    witnesses::revoke_adapter<NETWORK_WITNESS>(internal::permit<NETWORK_WITNESS>(), &mut registry, &mut auth, &req);
    assert!(witnesses::auth_revoked(&auth), 1);
    assert!(!registry.registry_authorized().contains(&auth_id), 2);

    // Re-registering a revoked auth must abort.
    proposal::consume_execution_request_for_testing(req);

    transfer::public_transfer(auth, ADMIN);
    witnesses::share_registry(registry);
    scenario.end();
}

/// Phantom marker for the test ExecutionRequest above.
public struct NETWORK_WITNESS has drop {}

#[test, expected_failure(abort_code = 18)] // EAdapterRevoked
fun test_register_adapter_rejects_revoked_auth() {
    use armature::proposal;
    let mut scenario = ts::begin(ADMIN);
    let mut auth = witnesses::new_auth(internal::permit<NETWORK_WITNESS>(), @minehaul_core, 0, scenario.ctx());
    witnesses::set_revoked_for_test(&mut auth);

    let mut registry = witnesses::new_registry_for_test(net(), vector[], scenario.ctx());
    let dao_id = object::id_from_address(NETWORK_ADDR);
    let proposal_id = object::id_from_address(@0xDEADBEEF);
    let req = proposal::new_execution_request_for_testing<NETWORK_WITNESS>(dao_id, proposal_id);

    witnesses::register_adapter<NETWORK_WITNESS>(internal::permit<NETWORK_WITNESS>(), &mut registry, &auth, &req);

    // unreachable
    proposal::consume_execution_request_for_testing(req);
    transfer::public_transfer(auth, ADMIN);
    witnesses::share_registry(registry);
    scenario.end();
}
