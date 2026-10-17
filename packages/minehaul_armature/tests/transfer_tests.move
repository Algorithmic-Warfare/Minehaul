/// Integration of real governance handlers and core transitions. MockDelivery
/// is deliberately test-only: it models a trusted delivery adapter, not world
/// inventory movement. No production function can issue this marker's permit.
#[test_only]
module minehaul_armature::transfer_tests;

use std::internal;
use sui::{clock::{Self, Clock}, object, test_scenario as ts, transfer};
use armature::{dao::{Self, DAO}, governance, proposal::{Self, ExecutionTicket}};
use multicoin::multicoin::{Self, Balance};
use minehaul_core::{action::{Self, HaulAction}, escrow, network, witnesses::{Self, AdapterAuth, AdapterRegistry}};
use minehaul_armature::{configure_network::{Self, ConfigureLogisticNetwork}, list_haul_action, cancel_haul_action, resolve_dispute};

const LISTER: address = @0xA1;
const HAULER: address = @0xB1;
const TREASURY: address = @0xC1;
const OUTSIDER: address = @0xD1;
public struct MockDelivery {}
public struct WrongAdapter {}
public struct OtherNetwork {}

fun src(): ID { object::id_from_address(@0x100) }
fun dst(): ID { object::id_from_address(@0x200) }

fun ticket<P: store>(dao: &DAO, payload: P): ExecutionTicket<P> {
    proposal::new_standalone_ticket_for_testing(dao.id(), object::id_from_address(@0xAAA), payload, 100, 100)
}

fun setup(collateral_amount: u64): (ts::Scenario, Clock) {
    let mut s = ts::begin(LISTER);
    let c = clock::create_for_testing(s.ctx());
    let init = governance::init_board(vector[LISTER]);
    dao::create(&init, b"Transfer DAO".to_string(), b"".to_string(), s.ctx());
    let (mut collection, cap) = multicoin::new_collection(s.ctx());
    let cid = object::id(&collection);
    let reward = multicoin::mint_balance(&cap, &mut collection, 0, 1000, s.ctx());
    let cargo = multicoin::mint_balance(&cap, &mut collection, 1, 25, s.ctx());
    let collateral = multicoin::mint_balance(&cap, &mut collection, 0, collateral_amount, s.ctx());
    transfer::public_transfer(collateral, HAULER);
    transfer::public_transfer(collection, LISTER);
    transfer::public_transfer(cap, LISTER);
    s.next_tx(LISTER);
    let mut dao = s.take_shared<DAO>();
    let cfg = network::new_config(cid, 0, 2000, 16, 100, true, TREASURY);
    let t = ticket(&dao, configure_network::new_set_config(cfg));
    configure_network::execute_configure_logistic_network(&mut dao, t, s.ctx());
    let nid = dao.id();
    let t = ticket(&dao, configure_network::new_register_ssu_vaulted(src(), src()));
    configure_network::execute_register_ssu(&mut dao, t,
        witnesses::new_verified_ssu_for_test(src(), nid, src(), 0), s.ctx());
    let t = ticket(&dao, configure_network::new_register_ssu_vaulted(dst(), dst()));
    configure_network::execute_register_ssu(&mut dao, t,
        witnesses::new_verified_ssu_for_test(dst(), nid, dst(), 0), s.ctx());
    ts::return_shared(dao);
    s.next_tx(LISTER);
    let dao = s.take_shared<DAO>();
    let mut registry = s.take_shared<AdapterRegistry>();
    let auth = witnesses::new_auth(internal::permit<MockDelivery>(), @minehaul_armature, 0, s.ctx());
    let t = ticket(&dao, configure_network::new_register_adapter(object::id(&auth)));
    configure_network::execute_register_adapter(&dao, t, &mut registry, &auth);
    transfer::public_share_object(auth);
    ts::return_shared(registry);
    let p = list_haul_action::new(src(), dst(), vector[action::new_cargo_line(cid, 1, 25)],
        action::new_cargo_line(cid, 0, 1000), 8000, LISTER, 1000, 1000);
    let t = ticket(&dao, p);
    list_haul_action::execute(&dao, t, vector[cargo], reward, &c, s.ctx());
    ts::return_shared(dao);
    s.next_tx(HAULER);
    (s, c)
}

fun claim(s: &mut ts::Scenario, c: &Clock) {
    let dao = s.take_shared<DAO>();
    let mut a = s.take_shared<HaulAction>();
    let collateral = s.take_from_sender<Balance>();
    action::claim_action<ConfigureLogisticNetwork>(&mut a, &dao, collateral, c, s.ctx());
    assert!(action::has_hauler_cap(&a, HAULER), 0);
    ts::return_shared(a);
    ts::return_shared(dao);
    let sender = s.ctx().sender();
    s.next_tx(sender);
}

fun collect(s: &mut ts::Scenario, c: &Clock) {
    let dao = s.take_shared<DAO>();
    let mut a = s.take_shared<HaulAction>();
    action::confirm_collection<ConfigureLogisticNetwork>(&mut a, &dao, c, s.ctx());
    assert!(action::is_collected(&a), 0);
    ts::return_shared(a);
    ts::return_shared(dao);
    let sender = s.ctx().sender();
    s.next_tx(sender);
}

fun deliver(s: &mut ts::Scenario, c: &Clock) {
    let dao = s.take_shared<DAO>();
    let mut a = s.take_shared<HaulAction>();
    let registry = s.take_shared<AdapterRegistry>();
    let auth = s.take_shared<AdapterAuth>();
    let (cargo, request) = action::withdraw_cargo_for_delivery<ConfigureLogisticNetwork>(&mut a, &dao, c, s.ctx());
    assert!(witnesses::delivery_destination(&request) == dst(), 0);
    assert!(witnesses::delivery_hauler(&request) == HAULER, 1);
    assert!(*witnesses::delivery_manifest_hash(&request) == action::manifest_hash(&a), 2);
    // Mock delivery transfers the exact funded balances to the lister.
    cargo.do!(|balance| transfer::public_transfer(balance, LISTER));
    let proof = witnesses::certify_delivery(internal::permit<MockDelivery>(), &auth, &registry, request);
    action::complete_action<ConfigureLogisticNetwork>(&mut a, &dao, proof, c, s.ctx());
    assert!(action::is_delivered(&a), 3);
    assert!(escrow::reward_amount(action::escrow(&a)) == 1000, 4);
    assert!(escrow::collateral_amount(action::escrow(&a)) == 400, 5);
    assert!(!action::has_hauler_cap(&a, HAULER), 6);
    ts::return_shared(a);
    ts::return_shared(dao);
    ts::return_shared(registry);
    ts::return_shared(auth);
    let sender = s.ctx().sender();
    s.next_tx(sender);
}

fun finish(s: ts::Scenario, c: Clock) { c.destroy_for_testing(); s.end(); }

fun total(s: &mut ts::Scenario, account: address, asset: u64): u64 {
    let mut sum = 0;
    ts::ids_for_address<Balance>(account).do!(|id| {
        let b = ts::take_from_address_by_id<Balance>(s, account, id);
        if (multicoin::asset_id(&b) == asset) sum = sum + multicoin::value(&b);
        ts::return_to_address(account, b);
    });
    let sender = s.ctx().sender();
    s.next_tx(sender);
    sum
}

#[test]
fun transfer_deliver_then_permissionless_settlement() {
    let (mut s, mut c) = setup(400);
    let a = s.take_shared<HaulAction>();
    assert!(action::source_ssu(&a) == src(), 0);
    assert!(action::destination_ssu(&a) == dst(), 1);
    ts::return_shared(a);
    s.next_tx(HAULER);
    claim(&mut s, &c);
    collect(&mut s, &c);
    deliver(&mut s, &c);
    c.increment_for_testing(100);
    s.next_tx(OUTSIDER);
    let dao = s.take_shared<DAO>();
    let mut a = s.take_shared<HaulAction>();
    action::finalize_action<ConfigureLogisticNetwork>(&mut a, &dao, &c, s.ctx());
    assert!(action::is_settled(&a), 0);
    assert!(escrow::reward_amount(action::escrow(&a)) == 0, 1);
    assert!(escrow::collateral_amount(action::escrow(&a)) == 0, 2);
    ts::return_shared(a);
    ts::return_shared(dao);
    s.next_tx(OUTSIDER);
    assert!(total(&mut s, HAULER, 0) == 1200, 3);
    assert!(total(&mut s, TREASURY, 0) == 200, 4);
    assert!(total(&mut s, LISTER, 1) == 25, 5);
    finish(s, c);
}

#[test]
fun cancelled_listing_refunds_reward_and_all_cargo() {
    let (mut s, c) = setup(400);
    let dao = s.take_shared<DAO>();
    let mut a = s.take_shared<HaulAction>();
    let t = ticket(&dao, cancel_haul_action::new(action::id(&a)));
    cancel_haul_action::execute(&dao, &mut a, t, s.ctx());
    assert!(action::is_cancelled(&a), 0);
    ts::return_shared(a);
    ts::return_shared(dao);
    s.next_tx(OUTSIDER);
    assert!(total(&mut s, LISTER, 0) == 1000, 1);
    assert!(total(&mut s, LISTER, 1) == 25, 2);
    finish(s, c);
}

#[test]
fun expired_listing_refunds_reward_and_all_cargo() {
    let (mut s, mut c) = setup(400);
    c.increment_for_testing(1000);
    let dao = s.take_shared<DAO>();
    let mut a = s.take_shared<HaulAction>();
    action::expire_action<ConfigureLogisticNetwork>(&mut a, &dao, &c, s.ctx());
    assert!(action::is_expired(&a), 0);
    ts::return_shared(a);
    ts::return_shared(dao);
    s.next_tx(OUTSIDER);
    assert!(total(&mut s, LISTER, 0) == 1000 && total(&mut s, LISTER, 1) == 25, 1);
    finish(s, c);
}

fun resolve(s: &mut ts::Scenario, award: bool, slash: u16) {
    let dao = s.take_shared<DAO>();
    let mut a = s.take_shared<HaulAction>();
    let t = ticket(&dao, resolve_dispute::new(action::id(&a), award, slash));
    resolve_dispute::execute(&dao, &mut a, t, s.ctx());
    assert!(action::is_resolved(&a), 0);
    assert!(!action::has_hauler_cap(&a, HAULER), 1);
    ts::return_shared(a);
    ts::return_shared(dao);
    let sender = s.ctx().sender();
    s.next_tx(sender);
}

#[test]
fun expired_claim_retains_escrow_until_governed_slash() {
    let (mut s, mut c) = setup(400);
    claim(&mut s, &c);
    c.increment_for_testing(1000);
    s.next_tx(OUTSIDER);
    let dao = s.take_shared<DAO>();
    let mut a = s.take_shared<HaulAction>();
    action::expire_action<ConfigureLogisticNetwork>(&mut a, &dao, &c, s.ctx());
    assert!(escrow::collateral_amount(action::escrow(&a)) == 400, 0);
    ts::return_shared(a);
    ts::return_shared(dao);
    s.next_tx(LISTER);
    resolve(&mut s, false, 5000);
    s.next_tx(OUTSIDER);
    assert!(total(&mut s, LISTER, 0) == 200, 1);
    assert!(total(&mut s, TREASURY, 0) == 1200, 2);
    assert!(total(&mut s, LISTER, 1) == 25, 3);
    finish(s, c);
}

#[test]
fun post_delivery_dispute_can_still_slash_collateral() {
    let (mut s, c) = setup(400);
    claim(&mut s, &c);
    collect(&mut s, &c);
    deliver(&mut s, &c);
    s.next_tx(LISTER);
    let dao = s.take_shared<DAO>();
    let mut a = s.take_shared<HaulAction>();
    action::dispute_action<ConfigureLogisticNetwork>(&mut a, &dao, &c, s.ctx());
    ts::return_shared(a);
    ts::return_shared(dao);
    s.next_tx(LISTER);
    resolve(&mut s, false, 10000);
    s.next_tx(OUTSIDER);
    assert!(total(&mut s, LISTER, 0) == 400, 0);
    assert!(total(&mut s, TREASURY, 0) == 1000, 1);
    finish(s, c);
}

#[test]
fun dispute_award_pays_hauler_and_returns_unmoved_cargo() {
    let (mut s, c) = setup(400);
    claim(&mut s, &c);
    collect(&mut s, &c);
    let dao = s.take_shared<DAO>();
    let mut a = s.take_shared<HaulAction>();
    action::dispute_action<ConfigureLogisticNetwork>(&mut a, &dao, &c, s.ctx());
    ts::return_shared(a);
    ts::return_shared(dao);
    s.next_tx(LISTER);
    resolve(&mut s, true, 0);
    s.next_tx(OUTSIDER);
    assert!(total(&mut s, HAULER, 0) == 1200, 0);
    assert!(total(&mut s, TREASURY, 0) == 200, 1);
    assert!(total(&mut s, LISTER, 1) == 25, 2);
    finish(s, c);
}

#[test, expected_failure(abort_code = 17, location = minehaul_core::action)]
fun claim_rejects_insufficient_collateral() {
    let (mut s, c) = setup(199);
    claim(&mut s, &c);
    abort 999
}

#[test, expected_failure(abort_code = 7, location = minehaul_core::action)]
fun claim_rejects_expired_listing_at_boundary() {
    let (mut s, mut c) = setup(400);
    c.increment_for_testing(1000);
    claim(&mut s, &c);
    abort 999
}

#[test, expected_failure(abort_code = 8, location = minehaul_core::action)]
fun collection_rejects_wrong_sender() {
    let (mut s, c) = setup(400);
    claim(&mut s, &c);
    s.next_tx(OUTSIDER);
    collect(&mut s, &c);
    abort 999
}

#[test, expected_failure(abort_code = 7, location = minehaul_core::action)]
fun collection_rejects_deadline_boundary() {
    let (mut s, mut c) = setup(400);
    claim(&mut s, &c);
    c.increment_for_testing(1000);
    collect(&mut s, &c);
    abort 999
}

#[test, expected_failure(abort_code = 8, location = minehaul_core::action)]
fun delivery_rejects_wrong_sender() {
    let (mut s, c) = setup(400);
    claim(&mut s, &c);
    collect(&mut s, &c);
    s.next_tx(OUTSIDER);
    deliver(&mut s, &c);
    abort 999
}

#[test, expected_failure(abort_code = 37, location = minehaul_core::action)]
fun settlement_rejects_before_dispute_window() {
    let (mut s, c) = setup(400);
    claim(&mut s, &c);
    collect(&mut s, &c);
    deliver(&mut s, &c);
    let dao = s.take_shared<DAO>();
    let mut a = s.take_shared<HaulAction>();
    action::finalize_action<ConfigureLogisticNetwork>(&mut a, &dao, &c, s.ctx());
    abort 999
}

#[test, expected_failure(abort_code = 36, location = minehaul_core::action)]
fun dispute_rejects_at_settlement_boundary() {
    let (mut s, mut c) = setup(400);
    claim(&mut s, &c);
    collect(&mut s, &c);
    deliver(&mut s, &c);
    c.increment_for_testing(100);
    let dao = s.take_shared<DAO>();
    let mut a = s.take_shared<HaulAction>();
    action::dispute_action<ConfigureLogisticNetwork>(&mut a, &dao, &c, s.ctx());
    abort 999
}

#[test, expected_failure(abort_code = 23, location = minehaul_core::action)]
fun dispute_rejects_outsider() {
    let (mut s, c) = setup(400);
    claim(&mut s, &c);
    collect(&mut s, &c);
    deliver(&mut s, &c);
    s.next_tx(OUTSIDER);
    let dao = s.take_shared<DAO>();
    let mut a = s.take_shared<HaulAction>();
    action::dispute_action<ConfigureLogisticNetwork>(&mut a, &dao, &c, s.ctx());
    abort 999
}

#[test, expected_failure(abort_code = 6, location = minehaul_core::action)]
fun settlement_rejects_second_payout() {
    let (mut s, mut c) = setup(400);
    claim(&mut s, &c);
    collect(&mut s, &c);
    deliver(&mut s, &c);
    c.increment_for_testing(100);
    let dao = s.take_shared<DAO>();
    let mut a = s.take_shared<HaulAction>();
    action::finalize_action<ConfigureLogisticNetwork>(&mut a, &dao, &c, s.ctx());
    action::finalize_action<ConfigureLogisticNetwork>(&mut a, &dao, &c, s.ctx());
    abort 999
}

#[test, expected_failure(abort_code = 6, location = minehaul_core::action)]
fun settlement_rejects_disputed_delivery() {
    let (mut s, mut c) = setup(400);
    claim(&mut s, &c);
    collect(&mut s, &c);
    deliver(&mut s, &c);
    let dao = s.take_shared<DAO>();
    let mut a = s.take_shared<HaulAction>();
    action::dispute_action<ConfigureLogisticNetwork>(&mut a, &dao, &c, s.ctx());
    c.increment_for_testing(100);
    action::finalize_action<ConfigureLogisticNetwork>(&mut a, &dao, &c, s.ctx());
    abort 999
}

#[test, expected_failure(abort_code = 33, location = minehaul_core::action)]
fun claim_rejects_wrong_network_key() {
    let (mut s, c) = setup(400);
    let dao = s.take_shared<DAO>();
    let mut a = s.take_shared<HaulAction>();
    let collateral = s.take_from_sender<Balance>();
    action::claim_action<OtherNetwork>(&mut a, &dao, collateral, &c, s.ctx());
    abort 999
}

#[test, expected_failure(abort_code = 38, location = minehaul_core::action)]
fun expiry_rejects_before_listing_deadline() {
    let (mut s, c) = setup(400);
    let dao = s.take_shared<DAO>();
    let mut a = s.take_shared<HaulAction>();
    action::expire_action<ConfigureLogisticNetwork>(&mut a, &dao, &c, s.ctx());
    abort 999
}

#[test, expected_failure(abort_code = 2, location = minehaul_core::network)]
fun claim_rejects_paused_network() {
    let (mut s, c) = setup(400);
    let mut dao = s.take_shared<DAO>();
    let t = ticket(&dao, configure_network::new_set_paused(true));
    configure_network::execute_set_paused(&mut dao, t);
    ts::return_shared(dao);
    s.next_tx(HAULER);
    claim(&mut s, &c);
    abort 999
}

#[test, expected_failure(abort_code = 19, location = minehaul_core::witnesses)]
fun adapter_cannot_mint_as_different_marker() {
    let (s, c) = setup(400);
    let auth = s.take_shared<AdapterAuth>();
    let registry = s.take_shared<AdapterRegistry>();
    let _v = witnesses::mint_verified_ssu(internal::permit<WrongAdapter>(), &auth, &registry, src(), src(), &c);
    abort 999
}

#[test, expected_failure(abort_code = 26, location = minehaul_core::witnesses)]
fun other_proposal_type_cannot_authorize_adapter() {
    let (mut s, _c) = setup(400);
    let dao = s.take_shared<DAO>();
    let mut registry = s.take_shared<AdapterRegistry>();
    let auth = witnesses::new_auth(internal::permit<WrongAdapter>(), @minehaul_armature, 0, s.ctx());
    let req = proposal::new_execution_request_for_testing<OtherNetwork>(dao.id(), src());
    witnesses::register_adapter(internal::permit<OtherNetwork>(), &mut registry, &auth, &req);
    abort 999
}

#[test, expected_failure(abort_code = 26, location = minehaul_core::witnesses)]
fun foreign_dao_cannot_authorize_adapter() {
    let (mut s, _c) = setup(400);
    let mut registry = s.take_shared<AdapterRegistry>();
    let auth = witnesses::new_auth(internal::permit<WrongAdapter>(), @minehaul_armature, 0, s.ctx());
    // Use a different locally defined type: DAO mismatch must be checked first.
    let req2 = proposal::new_execution_request_for_testing<OtherNetwork>(src(), dst());
    witnesses::register_adapter(internal::permit<OtherNetwork>(), &mut registry, &auth, &req2);
    abort 999
}

#[test, expected_failure(abort_code = 19, location = minehaul_core::witnesses)]
fun revoked_adapter_cannot_complete_delivery() {
    let (mut s, c) = setup(400);
    claim(&mut s, &c);
    collect(&mut s, &c);
    let dao = s.take_shared<DAO>();
    let mut registry = s.take_shared<AdapterRegistry>();
    let auth = s.take_shared<AdapterAuth>();
    let t = ticket(&dao, configure_network::new_revoke_adapter(object::id(&auth)));
    configure_network::execute_revoke_adapter(&dao, t, &mut registry, &auth);
    ts::return_shared(dao);
    ts::return_shared(registry);
    ts::return_shared(auth);
    s.next_tx(HAULER);
    deliver(&mut s, &c);
    abort 999
}

/// Regression: anyone can create a DAO, stand up a network and register a
/// shared auth. Revoking it there must not stop the auth on the victim network.
#[test]
fun foreign_network_revocation_does_not_disable_shared_adapter() {
    let (mut s, c) = setup(400);
    claim(&mut s, &c);
    collect(&mut s, &c);
    let victim_dao = s.take_shared<DAO>();
    let victim_id = victim_dao.id();
    let victim_registry_id = network::registry_id(network::borrow<ConfigureLogisticNetwork>(&victim_dao));
    ts::return_shared(victim_dao);

    s.next_tx(OUTSIDER);
    let init = governance::init_board(vector[OUTSIDER]);
    let attacker_id = dao::create(&init, b"Attacker DAO".to_string(), b"".to_string(), s.ctx());
    s.next_tx(OUTSIDER);
    let mut attacker = s.take_shared_by_id<DAO>(attacker_id);
    let t = ticket(&attacker, configure_network::new_set_config(network::new_config(src(), 0, 0, 1, 0, true, OUTSIDER)));
    configure_network::execute_configure_logistic_network(&mut attacker, t, s.ctx());
    ts::return_shared(attacker);
    s.next_tx(OUTSIDER);
    let attacker = s.take_shared_by_id<DAO>(attacker_id);
    let attacker_registry_id = network::registry_id(network::borrow<ConfigureLogisticNetwork>(&attacker));
    let mut attacker_registry = s.take_shared_by_id<AdapterRegistry>(attacker_registry_id);
    let auth = s.take_shared<AdapterAuth>();
    let t = ticket(&attacker, configure_network::new_register_adapter(object::id(&auth)));
    configure_network::execute_register_adapter(&attacker, t, &mut attacker_registry, &auth);
    let t = ticket(&attacker, configure_network::new_revoke_adapter(object::id(&auth)));
    configure_network::execute_revoke_adapter(&attacker, t, &mut attacker_registry, &auth);
    assert!(!witnesses::auth_revoked(&auth), 0);
    ts::return_shared(attacker);
    ts::return_shared(attacker_registry);
    ts::return_shared(auth);

    s.next_tx(HAULER);
    let dao = s.take_shared_by_id<DAO>(victim_id);
    let mut a = s.take_shared<HaulAction>();
    let registry = s.take_shared_by_id<AdapterRegistry>(victim_registry_id);
    let auth = s.take_shared<AdapterAuth>();
    let (cargo, request) = action::withdraw_cargo_for_delivery<ConfigureLogisticNetwork>(&mut a, &dao, &c, s.ctx());
    cargo.do!(|balance| transfer::public_transfer(balance, LISTER));
    let proof = witnesses::certify_delivery(internal::permit<MockDelivery>(), &auth, &registry, request);
    action::complete_action<ConfigureLogisticNetwork>(&mut a, &dao, proof, &c, s.ctx());
    assert!(action::is_delivered(&a), 1);
    ts::return_shared(a);
    ts::return_shared(dao);
    ts::return_shared(registry);
    ts::return_shared(auth);
    finish(s, c);
}

#[test, expected_failure(abort_code = 1, location = minehaul_armature::cancel_haul_action)]
fun cancel_rejects_different_action() {
    let (mut s, _c) = setup(400);
    let dao = s.take_shared<DAO>();
    let mut a = s.take_shared<HaulAction>();
    let t = ticket(&dao, cancel_haul_action::new(src()));
    cancel_haul_action::execute(&dao, &mut a, t, s.ctx());
    abort 999
}

#[test, expected_failure(abort_code = 1, location = minehaul_armature::resolve_dispute)]
fun resolution_rejects_different_action() {
    let (mut s, _c) = setup(400);
    let dao = s.take_shared<DAO>();
    let mut a = s.take_shared<HaulAction>();
    let t = ticket(&dao, resolve_dispute::new(src(), true, 0));
    resolve_dispute::execute(&dao, &mut a, t, s.ctx());
    abort 999
}

#[test]
fun configuration_changes_do_not_rewrite_existing_job_terms() {
    let (mut s, mut c) = setup(400);
    let mut dao = s.take_shared<DAO>();
    let a = s.take_shared<HaulAction>();
    let cid = action::cargo_line_collection(&action::cargo_manifest(&a)[0]);
    // New jobs use a different treasury, 100% collateral and a longer window.
    let cfg = network::new_config(cid, 0, 10000, 16, 10000, true, OUTSIDER);
    let t = ticket(&dao, configure_network::new_set_config(cfg));
    configure_network::execute_configure_logistic_network(&mut dao, t, s.ctx());
    ts::return_shared(a);
    ts::return_shared(dao);
    s.next_tx(HAULER);
    claim(&mut s, &c); // Still uses the original 20% minimum.
    collect(&mut s, &c);
    deliver(&mut s, &c);
    c.increment_for_testing(100); // Still uses the original dispute window.
    let dao = s.take_shared<DAO>();
    let mut a = s.take_shared<HaulAction>();
    action::finalize_action<ConfigureLogisticNetwork>(&mut a, &dao, &c, s.ctx());
    ts::return_shared(a);
    ts::return_shared(dao);
    s.next_tx(OUTSIDER);
    assert!(total(&mut s, TREASURY, 0) == 200, 0);
    assert!(total(&mut s, OUTSIDER, 0) == 0, 1);
    finish(s, c);
}

#[test, expected_failure(abort_code = 26, location = minehaul_core::action)]
fun claim_rejects_different_dao() {
    let (mut s, c) = setup(400);
    let init = governance::init_board(vector[HAULER]);
    dao::create(&init, b"Other DAO".to_string(), b"".to_string(), s.ctx());
    s.next_tx(HAULER);
    claim(&mut s, &c);
    abort 999
}

#[test, expected_failure(abort_code = 6, location = minehaul_core::action)]
fun cancel_rejects_claimed_job() {
    let (mut s, c) = setup(400);
    claim(&mut s, &c);
    let dao = s.take_shared<DAO>();
    let mut a = s.take_shared<HaulAction>();
    let t = ticket(&dao, cancel_haul_action::new(action::id(&a)));
    cancel_haul_action::execute(&dao, &mut a, t, s.ctx());
    abort 999
}

#[test]
fun collected_expiry_retains_assets_for_resolution() {
    let (mut s, mut c) = setup(400);
    claim(&mut s, &c);
    collect(&mut s, &c);
    c.increment_for_testing(1000);
    let dao = s.take_shared<DAO>();
    let mut a = s.take_shared<HaulAction>();
    action::expire_action<ConfigureLogisticNetwork>(&mut a, &dao, &c, s.ctx());
    assert!(action::is_disputed(&a), 0);
    assert!(escrow::reward_amount(action::escrow(&a)) == 1000, 1);
    assert!(escrow::collateral_amount(action::escrow(&a)) == 400, 2);
    let line = action::cargo_manifest(&a)[0];
    assert!(action::has_cargo(&a, action::cargo_line_collection(&line), action::cargo_line_asset_id(&line)), 3);
    ts::return_shared(a);
    ts::return_shared(dao);
    finish(s, c);
}

#[test, expected_failure(abort_code = 1, location = sui::dynamic_field)]
fun unrelated_proposal_cannot_write_network_storage_slot() {
    let (s, _c) = setup(400);
    let mut dao = s.take_shared<DAO>();
    let req = proposal::new_execution_request_for_testing<OtherNetwork>(dao.id(), src());
    assert!(!network::has_network<OtherNetwork>(&dao), 0);
    network::set_paused(internal::permit<OtherNetwork>(), &mut dao, true, &req);
    abort 999
}

/// Exercise listing validation after constructing the real network/registry.
fun list_invalid(s: &mut ts::Scenario, c: &Clock, duplicate: bool, wrong_reward: bool) {
    let dao = s.take_shared<DAO>();
    let mut collection = ts::take_from_address<multicoin::Collection>(s, LISTER);
    let cap = ts::take_from_address<multicoin::CollectionCap>(s, LISTER);
    let cid = object::id(&collection);
    let cargo = multicoin::mint_balance(&cap, &mut collection, 1, 25, s.ctx());
    let mut balances = vector[cargo];
    let mut manifest = vector[action::new_cargo_line(cid, 1, if (duplicate) 25 else 26)];
    if (duplicate) {
        balances.push_back(multicoin::mint_balance(&cap, &mut collection, 1, 25, s.ctx()));
        manifest.push_back(action::new_cargo_line(cid, 1, 25));
    };
    let reward = multicoin::mint_balance(&cap, &mut collection, 0, 1000, s.ctx());
    let p = list_haul_action::new(src(), dst(), manifest,
        action::new_cargo_line(cid, 0, if (wrong_reward) 1001 else 1000), 8000, LISTER, 1000, 1000);
    let t = ticket(&dao, p);
    list_haul_action::execute(&dao, t, balances, reward, c, s.ctx());
    abort 999
}

#[test, expected_failure(abort_code = 14, location = minehaul_core::action)]
fun listing_rejects_mismatched_cargo_quantity() {
    let (mut s, c) = setup(400);
    list_invalid(&mut s, &c, false, false);
    abort 999
}

#[test, expected_failure(abort_code = 14, location = minehaul_core::action)]
fun listing_rejects_duplicate_cargo_asset() {
    let (mut s, c) = setup(400);
    list_invalid(&mut s, &c, true, false);
    abort 999
}

#[test, expected_failure(abort_code = 1, location = minehaul_armature::list_haul_action)]
fun listing_rejects_reward_different_from_approved_payload() {
    let (mut s, c) = setup(400);
    list_invalid(&mut s, &c, false, true);
    abort 999
}

fun restrict_to_auxiliary(s: &mut ts::Scenario, remove: bool) {
    let mut dao = s.take_shared<DAO>();
    let a = s.take_shared<HaulAction>();
    let cid = action::cargo_line_collection(&action::cargo_manifest(&a)[0]);
    let cfg = network::new_config(cid, 0, 2000, 16, 100, false, TREASURY);
    let t = ticket(&dao, configure_network::new_set_config(cfg));
    configure_network::execute_configure_logistic_network(&mut dao, t, s.ctx());
    let t = ticket(&dao, configure_network::new_add_auxiliary_hauler(HAULER));
    configure_network::execute_membership_update(&mut dao, t);
    if (remove) {
        let t = ticket(&dao, configure_network::new_remove_auxiliary_hauler(HAULER));
        configure_network::execute_membership_update(&mut dao, t);
    };
    ts::return_shared(a);
    ts::return_shared(dao);
    s.next_tx(HAULER);
}

#[test]
fun auxiliary_hauler_can_claim_closed_marketplace() {
    let (mut s, c) = setup(400);
    restrict_to_auxiliary(&mut s, false);
    claim(&mut s, &c);
    finish(s, c);
}

#[test, expected_failure(abort_code = 1, location = minehaul_core::network)]
fun removed_auxiliary_hauler_cannot_claim_closed_marketplace() {
    let (mut s, c) = setup(400);
    restrict_to_auxiliary(&mut s, true);
    claim(&mut s, &c);
    abort 999
}

#[test, expected_failure(abort_code = 22, location = minehaul_core::network)]
fun claim_rejects_lease_expired_since_listing() {
    let (mut s, mut c) = setup(400);
    let mut dao = s.take_shared<DAO>();
    let t = ticket(&dao, configure_network::new_unregister_ssu(src()));
    configure_network::execute_membership_update(&mut dao, t);
    let t = ticket(&dao, configure_network::new_register_ssu_leased(src(), src(), 500));
    let proof = witnesses::new_verified_ssu_for_test(src(), dao.id(), src(), 0);
    configure_network::execute_register_ssu(&mut dao, t, proof, s.ctx());
    ts::return_shared(dao);
    c.increment_for_testing(500);
    s.next_tx(HAULER);
    claim(&mut s, &c);
    abort 999
}
