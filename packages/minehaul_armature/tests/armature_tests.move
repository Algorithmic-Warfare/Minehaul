/// Lightweight handler tests for the minehaul_armature proposal layer.
/// Uses proposal::new_standalone_ticket_for_testing to synthesize
/// ExecutionTicket<ConfigureLogisticNetwork> directly, skipping the
/// vote pipeline (exhaustively tested in armature). Focus here is on
/// handler-body correctness, payload-variant dispatch, and the
/// payload-witness id-match assertion.
#[test_only]
module minehaul_armature::armature_tests;

use sui::object;
use sui::test_scenario as ts;
use std::string;
use armature::dao::{Self, DAO};
use armature::governance;
use armature::proposal;
use minehaul_core::network::{Self, NetworkConfig};
use minehaul_core::witnesses;
use minehaul_armature::configure_network::{Self, ConfigureLogisticNetwork};

const CREATOR: address = @0xA1;
const TREASURY: address = @0xA2;
const SSU_ADDR: address = @0xF00D;
const OWNER_ADDR: address = @0x123;
const GATE_ADDR: address = @0xB00B;
const LOC_ADDR: address = @0xFADE;

fun make_config(): NetworkConfig {
    network::new_config(
        object::id_from_address(@0xC011),
        0, 2_000, 8, 16, 60_000, 86_400_000, false, TREASURY,
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

fun enable_types(scenario: &mut ts::Scenario) {
    let cfg = proposal::new_config(5_000, 5_000, 0, 604_800_000, 0, 0);
    ts::next_tx(scenario, CREATOR);
    let mut dao = ts::take_shared<DAO>(scenario);
    dao.test_enable_type(b"ConfigureLogisticNetwork".to_ascii_string(), cfg);
    dao.test_bind_type<ConfigureLogisticNetwork>(b"ConfigureLogisticNetwork".to_ascii_string());
    ts::return_shared(dao);
}

fun synth_ticket(
    scenario: &mut ts::Scenario,
    dao_id: ID,
    proposal_seed: address,
    payload: ConfigureLogisticNetwork,
): proposal::ExecutionTicket<ConfigureLogisticNetwork> {
    let _ = scenario;
    proposal::new_standalone_ticket_for_testing<ConfigureLogisticNetwork>(
        dao_id, object::id_from_address(proposal_seed), payload, 100, 100,
    )
}

// === SetConfig: lazy init + update ===

#[test]
fun test_set_config_lazy_init() {
    let mut scenario = ts::begin(CREATOR);
    setup_dao(&mut scenario);
    enable_types(&mut scenario);

    ts::next_tx(&mut scenario, CREATOR);
    let mut dao = ts::take_shared<DAO>(&mut scenario);
    let dao_id = dao.id();
    let payload = configure_network::new_set_config(make_config());
    let ticket = synth_ticket(&mut scenario, dao_id, @0xD01, payload);

    assert!(!network::has_network<ConfigureLogisticNetwork>(&dao), 0);
    configure_network::execute_configure_logistic_network(&mut dao, ticket, scenario.ctx());
    assert!(network::has_network<ConfigureLogisticNetwork>(&dao), 1);

    let net = network::borrow<ConfigureLogisticNetwork>(&dao);
    assert!(network::network_id(net) == dao_id, 2);
    assert!(network::ssu_count(net) == 0, 3);
    assert!(network::gate_count(net) == 0, 4);
    assert!(network::config_treasury_addr(network::config(net)) == TREASURY, 5);

    ts::return_shared(dao);
    scenario.end();
}

#[test]
fun test_set_config_update_in_place() {
    let mut scenario = ts::begin(CREATOR);
    setup_dao(&mut scenario);
    enable_types(&mut scenario);

    ts::next_tx(&mut scenario, CREATOR);
    let mut dao = ts::take_shared<DAO>(&mut scenario);
    let dao_id = dao.id();

    let t1 = synth_ticket(&mut scenario, dao_id, @0xD01,
        configure_network::new_set_config(make_config()));
    configure_network::execute_configure_logistic_network(&mut dao, t1, scenario.ctx());

    let new_cfg = network::new_config(
        object::id_from_address(@0xC011), 0, 2_000, 8, 16, 60_000, 86_400_000, true, @0xCAFE,
    );
    let t2 = synth_ticket(&mut scenario, dao_id, @0xD02,
        configure_network::new_set_config(new_cfg));
    configure_network::execute_configure_logistic_network(&mut dao, t2, scenario.ctx());

    let net = network::borrow<ConfigureLogisticNetwork>(&dao);
    assert!(network::config_treasury_addr(network::config(net)) == @0xCAFE, 0);
    assert!(network::config_allow_open_marketplace(network::config(net)), 1);

    ts::return_shared(dao);
    scenario.end();
}

#[test, expected_failure(abort_code = 1)] // EWrongOpVariant
fun test_set_config_aborts_on_wrong_variant() {
    let mut scenario = ts::begin(CREATOR);
    setup_dao(&mut scenario);
    enable_types(&mut scenario);

    ts::next_tx(&mut scenario, CREATOR);
    let mut dao = ts::take_shared<DAO>(&mut scenario);
    let dao_id = dao.id();
    // Ticket is for a RegisterGate variant, but caller invokes execute_configure_logistic_network.
    let t = synth_ticket(&mut scenario, dao_id, @0xD09,
        configure_network::new_register_gate(object::id_from_address(GATE_ADDR)));
    configure_network::execute_configure_logistic_network(&mut dao, t, scenario.ctx());

    ts::return_shared(dao);
    scenario.end();
}

// === RegisterSsu ===

#[test]
fun test_register_ssu_vaulted_happy_path() {
    let mut scenario = ts::begin(CREATOR);
    setup_dao(&mut scenario);
    enable_types(&mut scenario);

    ts::next_tx(&mut scenario, CREATOR);
    let mut dao = ts::take_shared<DAO>(&mut scenario);
    let dao_id = dao.id();

    let t1 = synth_ticket(&mut scenario, dao_id, @0xD01,
        configure_network::new_set_config(make_config()));
    configure_network::execute_configure_logistic_network(&mut dao, t1, scenario.ctx());

    let ssu_id = object::id_from_address(SSU_ADDR);
    let owner_id = object::id_from_address(OWNER_ADDR);
    let cap_id = object::id_from_address(@0xCA9);
    let vssu = witnesses::new_verified_ssu_for_test(ssu_id, dao_id, owner_id, 12_345);

    let t2 = synth_ticket(&mut scenario, dao_id, @0xD02,
        configure_network::new_register_ssu_vaulted(ssu_id, cap_id));
    configure_network::execute_register_ssu(&mut dao, t2, vssu, scenario.ctx());

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

#[test]
fun test_register_ssu_leased_happy_path() {
    let mut scenario = ts::begin(CREATOR);
    setup_dao(&mut scenario);
    enable_types(&mut scenario);

    ts::next_tx(&mut scenario, CREATOR);
    let mut dao = ts::take_shared<DAO>(&mut scenario);
    let dao_id = dao.id();

    let t1 = synth_ticket(&mut scenario, dao_id, @0xD01,
        configure_network::new_set_config(make_config()));
    configure_network::execute_configure_logistic_network(&mut dao, t1, scenario.ctx());

    let ssu_id = object::id_from_address(SSU_ADDR);
    let lease_id = object::id_from_address(@0x1EA5E);
    let vssu = witnesses::new_verified_ssu_for_test(
        ssu_id, dao_id, object::id_from_address(OWNER_ADDR), 100,
    );

    let t2 = synth_ticket(&mut scenario, dao_id, @0xD02,
        configure_network::new_register_ssu_leased(ssu_id, lease_id, 999_999));
    configure_network::execute_register_ssu(&mut dao, t2, vssu, scenario.ctx());

    let net = network::borrow<ConfigureLogisticNetwork>(&dao);
    assert!(network::is_ssu_registered(net, ssu_id), 0);

    ts::return_shared(dao);
    scenario.end();
}

#[test, expected_failure(abort_code = 2)] // EIntentWitnessMismatch
fun test_register_ssu_aborts_on_id_mismatch() {
    let mut scenario = ts::begin(CREATOR);
    setup_dao(&mut scenario);
    enable_types(&mut scenario);

    ts::next_tx(&mut scenario, CREATOR);
    let mut dao = ts::take_shared<DAO>(&mut scenario);
    let dao_id = dao.id();

    let t1 = synth_ticket(&mut scenario, dao_id, @0xD01,
        configure_network::new_set_config(make_config()));
    configure_network::execute_configure_logistic_network(&mut dao, t1, scenario.ctx());

    // Payload approves SSU_ADDR; witness presents a different ID.
    let approved_id = object::id_from_address(SSU_ADDR);
    let smuggled_id = object::id_from_address(@0xBAD);
    let vssu = witnesses::new_verified_ssu_for_test(
        smuggled_id, dao_id, object::id_from_address(OWNER_ADDR), 0,
    );
    let cap_id = object::id_from_address(@0xCA9);
    let t2 = synth_ticket(&mut scenario, dao_id, @0xD02,
        configure_network::new_register_ssu_vaulted(approved_id, cap_id));
    configure_network::execute_register_ssu(&mut dao, t2, vssu, scenario.ctx());

    ts::return_shared(dao);
    scenario.end();
}

#[test, expected_failure(abort_code = 4)] // ESsuNetworkMismatch (core)
fun test_register_ssu_aborts_on_wrong_network() {
    let mut scenario = ts::begin(CREATOR);
    setup_dao(&mut scenario);
    enable_types(&mut scenario);

    ts::next_tx(&mut scenario, CREATOR);
    let mut dao = ts::take_shared<DAO>(&mut scenario);
    let dao_id = dao.id();

    let t1 = synth_ticket(&mut scenario, dao_id, @0xD01,
        configure_network::new_set_config(make_config()));
    configure_network::execute_configure_logistic_network(&mut dao, t1, scenario.ctx());

    let ssu_id = object::id_from_address(SSU_ADDR);
    let wrong_net = object::id_from_address(@0xBAD);
    let vssu = witnesses::new_verified_ssu_for_test(
        ssu_id, wrong_net, object::id_from_address(OWNER_ADDR), 0,
    );
    let cap_id = object::id_from_address(@0xCA9);
    let t2 = synth_ticket(&mut scenario, dao_id, @0xD02,
        configure_network::new_register_ssu_vaulted(ssu_id, cap_id));
    configure_network::execute_register_ssu(&mut dao, t2, vssu, scenario.ctx());

    ts::return_shared(dao);
    scenario.end();
}

#[test, expected_failure(abort_code = 1)] // EWrongOpVariant
fun test_register_ssu_aborts_on_wrong_variant() {
    let mut scenario = ts::begin(CREATOR);
    setup_dao(&mut scenario);
    enable_types(&mut scenario);

    ts::next_tx(&mut scenario, CREATOR);
    let mut dao = ts::take_shared<DAO>(&mut scenario);
    let dao_id = dao.id();

    let t1 = synth_ticket(&mut scenario, dao_id, @0xD01,
        configure_network::new_set_config(make_config()));
    configure_network::execute_configure_logistic_network(&mut dao, t1, scenario.ctx());

    let ssu_id = object::id_from_address(SSU_ADDR);
    let vssu = witnesses::new_verified_ssu_for_test(
        ssu_id, dao_id, object::id_from_address(OWNER_ADDR), 0,
    );
    // Ticket is a RegisterGate variant; calling execute_register_ssu must abort.
    let t2 = synth_ticket(&mut scenario, dao_id, @0xD02,
        configure_network::new_register_gate(ssu_id));
    configure_network::execute_register_ssu(&mut dao, t2, vssu, scenario.ctx());

    ts::return_shared(dao);
    scenario.end();
}

// === RegisterGate ===

#[test]
fun test_register_gate_happy_path() {
    let mut scenario = ts::begin(CREATOR);
    setup_dao(&mut scenario);
    enable_types(&mut scenario);

    ts::next_tx(&mut scenario, CREATOR);
    let mut dao = ts::take_shared<DAO>(&mut scenario);
    let dao_id = dao.id();

    let t1 = synth_ticket(&mut scenario, dao_id, @0xD01,
        configure_network::new_set_config(make_config()));
    configure_network::execute_configure_logistic_network(&mut dao, t1, scenario.ctx());

    let gate_id = object::id_from_address(GATE_ADDR);
    let vgate = witnesses::new_verified_gate_for_test(
        gate_id, dao_id, object::id_from_address(LOC_ADDR), 100,
    );
    let t2 = synth_ticket(&mut scenario, dao_id, @0xD02,
        configure_network::new_register_gate(gate_id));
    configure_network::execute_register_gate(&mut dao, t2, vgate);

    let net = network::borrow<ConfigureLogisticNetwork>(&dao);
    assert!(network::is_gate_registered(net, gate_id), 0);
    assert!(network::gate_count(net) == 1, 1);

    ts::return_shared(dao);
    scenario.end();
}

#[test, expected_failure(abort_code = 2)] // EIntentWitnessMismatch
fun test_register_gate_aborts_on_id_mismatch() {
    let mut scenario = ts::begin(CREATOR);
    setup_dao(&mut scenario);
    enable_types(&mut scenario);

    ts::next_tx(&mut scenario, CREATOR);
    let mut dao = ts::take_shared<DAO>(&mut scenario);
    let dao_id = dao.id();

    let t1 = synth_ticket(&mut scenario, dao_id, @0xD01,
        configure_network::new_set_config(make_config()));
    configure_network::execute_configure_logistic_network(&mut dao, t1, scenario.ctx());

    let approved_id = object::id_from_address(GATE_ADDR);
    let smuggled_id = object::id_from_address(@0xBAD);
    let vgate = witnesses::new_verified_gate_for_test(
        smuggled_id, dao_id, object::id_from_address(LOC_ADDR), 0,
    );
    let t2 = synth_ticket(&mut scenario, dao_id, @0xD02,
        configure_network::new_register_gate(approved_id));
    configure_network::execute_register_gate(&mut dao, t2, vgate);

    ts::return_shared(dao);
    scenario.end();
}
