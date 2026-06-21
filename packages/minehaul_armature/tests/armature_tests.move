/// Lightweight handler tests for the minehaul_armature proposal layer.
/// Uses proposal::new_standalone_ticket_for_testing to synthesize
/// ExecutionTicket<P> directly, skipping the vote + cooldown pipeline
/// (which is exhaustively tested in armature itself). Focus here is on
/// the handler bodies in configure_network.move and register_assets.move.
#[test_only]
module minehaul_armature::armature_tests;

use sui::object;
use sui::test_scenario as ts;
use sui::transfer;
use std::string;
use armature::dao::{Self, DAO};
use armature::governance;
use armature::proposal::{Self, ProposalConfig};
use minehaul_core::network::{Self, NetworkConfig};
use minehaul_core::witnesses;
use minehaul_armature::configure_network::{Self, ConfigureLogisticNetwork};
use minehaul_armature::register_assets;

const CREATOR: address = @0xA1;
const TREASURY: address = @0xA2;
const SSU_ADDR: address = @0xF00D;
const OWNER_ADDR: address = @0x123;
const GATE_ADDR: address = @0xB00B;
const LOC_ADDR: address = @0xFADE;

fun make_config(): NetworkConfig {
    network::new_config(
        object::id_from_address(@0xC011), // default_reward_collection
        0,                                 // default_reward_asset_id
        2_000,                             // min_collateral_ratio_bps (20%)
        8,                                 // max_route_len
        16,                                // max_cargo_lines
        60_000,                            // permit_ttl_ms
        86_400_000,                        // dispute_window_ms (24h)
        false,                             // allow_open_marketplace
        TREASURY,                          // treasury_addr
    )
}

fun setup_dao(scenario: &mut ts::Scenario) {
    ts::next_tx(scenario, CREATOR);
    let init = governance::init_board(vector[CREATOR]);
    dao::create(
        &init,
        string::utf8(b"Test DAO"),
        string::utf8(b"https://example.com/logo.png"),
        scenario.ctx(),
    );
}

fun enable_types(scenario: &mut ts::Scenario): ProposalConfig {
    let cfg = proposal::new_config(5_000, 5_000, 0, 604_800_000, 0, 0);
    ts::next_tx(scenario, CREATOR);
    let mut dao = ts::take_shared<DAO>(scenario);
    dao.test_enable_type(b"ConfigureLogisticNetwork".to_ascii_string(), cfg);
    dao.test_bind_type<ConfigureLogisticNetwork>(b"ConfigureLogisticNetwork".to_ascii_string());
    ts::return_shared(dao);
    cfg
}

// === ConfigureLogisticNetwork: lazy init + update ===

#[test]
fun test_configure_logistic_network_lazy_init() {
    let mut scenario = ts::begin(CREATOR);
    setup_dao(&mut scenario);
    let _cfg = enable_types(&mut scenario);

    ts::next_tx(&mut scenario, CREATOR);
    let mut dao = ts::take_shared<DAO>(&mut scenario);
    let dao_id = dao.id();
    let proposal_id = object::id_from_address(@0xDEAD);

    let payload = configure_network::new(make_config());
    let ticket = proposal::new_standalone_ticket_for_testing<ConfigureLogisticNetwork>(
        dao_id, proposal_id, payload, 100, 100,
    );

    assert!(!network::has_network<ConfigureLogisticNetwork>(&dao), 0);
    configure_network::execute_configure_logistic_network(&mut dao, ticket, scenario.ctx());
    assert!(network::has_network<ConfigureLogisticNetwork>(&dao), 1);

    let net = network::borrow<ConfigureLogisticNetwork>(&dao);
    assert!(network::network_id(net) == dao_id, 2);
    assert!(network::ssu_count(net) == 0, 3);
    assert!(network::gate_count(net) == 0, 4);
    assert!(!network::is_paused(net), 5);
    assert!(network::config_treasury_addr(network::config(net)) == TREASURY, 6);

    ts::return_shared(dao);
    scenario.end();
}

#[test]
fun test_configure_logistic_network_update() {
    let mut scenario = ts::begin(CREATOR);
    setup_dao(&mut scenario);
    let _cfg = enable_types(&mut scenario);

    ts::next_tx(&mut scenario, CREATOR);
    let mut dao = ts::take_shared<DAO>(&mut scenario);
    let dao_id = dao.id();

    // First call: lazy init with treasury = TREASURY
    let t1 = proposal::new_standalone_ticket_for_testing<ConfigureLogisticNetwork>(
        dao_id, object::id_from_address(@0xD01), configure_network::new(make_config()),
        100, 100,
    );
    configure_network::execute_configure_logistic_network(&mut dao, t1, scenario.ctx());

    // Second call: change treasury_addr
    let new_cfg = network::new_config(
        object::id_from_address(@0xC011), 0, 2_000, 8, 16, 60_000, 86_400_000, true, @0xCAFE,
    );
    let t2 = proposal::new_standalone_ticket_for_testing<ConfigureLogisticNetwork>(
        dao_id, object::id_from_address(@0xD02), configure_network::new(new_cfg),
        100, 100,
    );
    configure_network::execute_configure_logistic_network(&mut dao, t2, scenario.ctx());

    let net = network::borrow<ConfigureLogisticNetwork>(&dao);
    assert!(network::config_treasury_addr(network::config(net)) == @0xCAFE, 0);
    assert!(network::config_allow_open_marketplace(network::config(net)), 1);

    ts::return_shared(dao);
    scenario.end();
}

// === RegisterSsu ===

#[test]
fun test_register_ssu_full_path() {
    let mut scenario = ts::begin(CREATOR);
    setup_dao(&mut scenario);
    let _cfg = enable_types(&mut scenario);

    ts::next_tx(&mut scenario, CREATOR);
    let mut dao = ts::take_shared<DAO>(&mut scenario);
    let dao_id = dao.id();

    // Initialize the network.
    let t1 = proposal::new_standalone_ticket_for_testing<ConfigureLogisticNetwork>(
        dao_id, object::id_from_address(@0xD01), configure_network::new(make_config()),
        100, 100,
    );
    configure_network::execute_configure_logistic_network(&mut dao, t1, scenario.ctx());

    // Mint a synthetic VerifiedSsu matching dao_id and register it.
    let ssu_id = object::id_from_address(SSU_ADDR);
    let owner_id = object::id_from_address(OWNER_ADDR);
    let vssu = witnesses::new_verified_ssu_for_test(ssu_id, dao_id, owner_id, 12_345);
    let cap_id = object::id_from_address(@0xCA9);
    let intent = register_assets::new_register_ssu_vaulted(ssu_id, cap_id);

    let t2 = proposal::new_standalone_ticket_for_testing<ConfigureLogisticNetwork>(
        dao_id, object::id_from_address(@0xD02), configure_network::new(make_config()),
        100, 100,
    );
    register_assets::execute_register_ssu(&mut dao, t2, intent, vssu, scenario.ctx());

    let net = network::borrow<ConfigureLogisticNetwork>(&dao);
    assert!(network::is_ssu_registered(net, ssu_id), 0);
    assert!(network::ssu_count(net) == 1, 1);
    let entry = network::ssu_entry(net, ssu_id);
    assert!(network::ssu_id(&entry) == ssu_id, 2);
    assert!(network::ssu_owner_char_id(&entry) == owner_id, 3);
    assert!(network::ssu_registered_at_ms(&entry) == 12_345, 4);

    ts::return_shared(dao);
    scenario.end();
}

#[test, expected_failure(abort_code = 4)] // ESsuNetworkMismatch
fun test_register_ssu_aborts_on_wrong_network() {
    let mut scenario = ts::begin(CREATOR);
    setup_dao(&mut scenario);
    let _cfg = enable_types(&mut scenario);

    ts::next_tx(&mut scenario, CREATOR);
    let mut dao = ts::take_shared<DAO>(&mut scenario);
    let dao_id = dao.id();

    let t1 = proposal::new_standalone_ticket_for_testing<ConfigureLogisticNetwork>(
        dao_id, object::id_from_address(@0xD01), configure_network::new(make_config()),
        100, 100,
    );
    configure_network::execute_configure_logistic_network(&mut dao, t1, scenario.ctx());

    let ssu_id = object::id_from_address(SSU_ADDR);
    // Witness's network_id is DIFFERENT from dao_id.
    let wrong_net = object::id_from_address(@0xBAD);
    let vssu = witnesses::new_verified_ssu_for_test(
        ssu_id, wrong_net, object::id_from_address(OWNER_ADDR), 0,
    );
    let intent = register_assets::new_register_ssu_vaulted(ssu_id, object::id_from_address(@0xCA9));
    let t2 = proposal::new_standalone_ticket_for_testing<ConfigureLogisticNetwork>(
        dao_id, object::id_from_address(@0xD02), configure_network::new(make_config()),
        100, 100,
    );
    register_assets::execute_register_ssu(&mut dao, t2, intent, vssu, scenario.ctx());

    ts::return_shared(dao);
    scenario.end();
}

// === RegisterGate ===

#[test]
fun test_register_gate_full_path() {
    let mut scenario = ts::begin(CREATOR);
    setup_dao(&mut scenario);
    let _cfg = enable_types(&mut scenario);

    ts::next_tx(&mut scenario, CREATOR);
    let mut dao = ts::take_shared<DAO>(&mut scenario);
    let dao_id = dao.id();

    let t1 = proposal::new_standalone_ticket_for_testing<ConfigureLogisticNetwork>(
        dao_id, object::id_from_address(@0xD01), configure_network::new(make_config()),
        100, 100,
    );
    configure_network::execute_configure_logistic_network(&mut dao, t1, scenario.ctx());

    let gate_id = object::id_from_address(GATE_ADDR);
    let loc_id = object::id_from_address(LOC_ADDR);
    let vgate = witnesses::new_verified_gate_for_test(gate_id, dao_id, loc_id, 100);

    let intent = register_assets::new_register_gate(gate_id);
    let t2 = proposal::new_standalone_ticket_for_testing<ConfigureLogisticNetwork>(
        dao_id, object::id_from_address(@0xD02), configure_network::new(make_config()),
        100, 100,
    );
    register_assets::execute_register_gate(&mut dao, t2, intent, vgate);

    let net = network::borrow<ConfigureLogisticNetwork>(&dao);
    assert!(network::is_gate_registered(net, gate_id), 0);
    assert!(network::gate_count(net) == 1, 1);

    ts::return_shared(dao);
    scenario.end();
}
