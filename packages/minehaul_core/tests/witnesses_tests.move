#[test_only]
module minehaul_core::witnesses_tests;

use sui::object;
use sui::clock;
use sui::test_scenario as ts;
use sui::transfer;
use minehaul_core::witnesses::{Self, AdapterAuth, AdapterRegistry};

const ADMIN: address = @0xA;
const NETWORK_ADDR: address = @0xCAFE;
const SSU_ADDR: address = @0xF00D;
const GATE_ADDR: address = @0xB00B;
const LOC_ADDR: address = @0xFADE;
const OWNER_ADDR: address = @0x123;
const HAULER_ADDR: address = @0xBEEF;

const NOW_MS: u64 = 1_000_000;
const TTL: u64 = 60_000;

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
    let auth = witnesses::new_auth(@minehaul_core, 0, scenario.ctx());
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
    let auth = witnesses::new_auth(@minehaul_core, 0, scenario.ctx());
    let mut registry = witnesses::new_registry_for_test(net(), vector::empty(), scenario.ctx());
    witnesses::register_for_test(&mut registry, object::id(&auth));
    let c = setup_clock(&mut scenario);

    let vssu = witnesses::mint_verified_ssu(
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
    let auth = witnesses::new_auth(@minehaul_core, 0, scenario.ctx());
    // registry exists but auth is NOT in authorized
    let registry = witnesses::new_registry_for_test(net(), vector::empty(), scenario.ctx());
    let c = setup_clock(&mut scenario);
    let _vssu = witnesses::mint_verified_ssu(
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
    let mut auth = witnesses::new_auth(@minehaul_core, 0, scenario.ctx());
    let mut registry = witnesses::new_registry_for_test(net(), vector::empty(), scenario.ctx());
    witnesses::register_for_test(&mut registry, object::id(&auth));
    // Bypass ExecutionRequest-gated revoke_adapter; the assert_auth_authorized
    // path is what we're exercising here, not the registry mutation.
    witnesses::set_revoked_for_test(&mut auth);
    let c = setup_clock(&mut scenario);
    let _vssu = witnesses::mint_verified_ssu(
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

// === mint_verified_gate ===

#[test]
fun test_mint_verified_gate_happy_path() {
    let mut scenario = ts::begin(ADMIN);
    let auth = witnesses::new_auth(@minehaul_core, 0, scenario.ctx());
    let mut registry = witnesses::new_registry_for_test(net(), vector::empty(), scenario.ctx());
    witnesses::register_for_test(&mut registry, object::id(&auth));
    let c = setup_clock(&mut scenario);

    let vg = witnesses::mint_verified_gate(
        &auth, &registry,
        object::id_from_address(GATE_ADDR),
        object::id_from_address(LOC_ADDR),
        &c,
    );
    assert!(witnesses::vgate_id(&vg) == object::id_from_address(GATE_ADDR), 0);
    assert!(witnesses::vgate_network(&vg) == net(), 1);
    assert!(witnesses::vgate_location(&vg) == object::id_from_address(LOC_ADDR), 2);

    transfer::public_transfer(auth, ADMIN);
    witnesses::share_registry(registry);
    clock::destroy_for_testing(c);
    scenario.end();
}

// === mint_permit ===

#[test]
fun test_mint_permit_uses_clock_plus_ttl() {
    let mut scenario = ts::begin(ADMIN);
    let auth = witnesses::new_auth(@minehaul_core, 0, scenario.ctx());
    let mut registry = witnesses::new_registry_for_test(net(), vector::empty(), scenario.ctx());
    witnesses::register_for_test(&mut registry, object::id(&auth));
    let c = setup_clock(&mut scenario);
    let rh = b"hash";

    let p = witnesses::mint_permit(
        &auth, &registry,
        object::id_from_address(GATE_ADDR),
        rh,
        HAULER_ADDR,
        TTL,
        &c,
    );
    assert!(witnesses::permit_gate(&p) == object::id_from_address(GATE_ADDR), 0);
    assert!(witnesses::permit_hauler(&p) == HAULER_ADDR, 1);
    assert!(witnesses::permit_expires_at_ms(&p) == NOW_MS + TTL, 2);

    transfer::public_transfer(auth, ADMIN);
    witnesses::share_registry(registry);
    clock::destroy_for_testing(c);
    scenario.end();
}
