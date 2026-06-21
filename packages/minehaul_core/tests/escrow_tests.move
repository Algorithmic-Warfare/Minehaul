#[test_only]
module minehaul_core::escrow_tests;

use sui::object;
use sui::tx_context::TxContext;
use sui::test_scenario as ts;
use sui::transfer;
use multicoin::multicoin::{Self, Collection, CollectionCap, Balance};
use minehaul_core::escrow::{Self, Escrow};

const ADMIN: address = @0xA;
const ASSET_ID: u64 = 0;

// === helpers ===

fun mint(cap: &CollectionCap, coll: &mut Collection, amount: u64, ctx: &mut TxContext): Balance {
    multicoin::mint_balance(cap, coll, ASSET_ID, amount, ctx)
}

fun finish(coll: Collection, cap: CollectionCap, uid: object::UID) {
    transfer::public_transfer(coll, ADMIN);
    transfer::public_transfer(cap, ADMIN);
    object::delete(uid);
}

// === new ===

#[test]
fun test_new_attaches_reward_and_caches_amount() {
    let mut scenario = ts::begin(ADMIN);
    let ctx = scenario.ctx();
    let (mut coll, cap) = multicoin::new_collection(ctx);
    let reward = mint(&cap, &mut coll, 1000, ctx);
    let mut uid = object::new(ctx);

    let mut esc = escrow::new(&mut uid, reward, 8000, ctx);
    assert!(escrow::reward_amount(&esc) == 1000, 0);
    assert!(escrow::reward_to_hauler_bps(&esc) == 8000, 1);
    assert!(!escrow::has_collateral(&esc), 2);
    assert!(escrow::collateral_amount(&esc) == 0, 3);
    assert!(escrow::reward_exists(&uid), 4);
    assert!(!escrow::collateral_exists(&uid), 5);

    // teardown — drain and destroy
    let r = escrow::refund_reward(&mut esc, &mut uid, scenario.ctx());
    multicoin::burn(&mut coll, r, scenario.ctx());
    escrow::destroy_empty(esc);
    finish(coll, cap, uid);
    scenario.end();
}

#[test, expected_failure(abort_code = 16)] // EInsufficientReward — bps > 10000
fun test_new_aborts_on_bps_over_max() {
    let mut scenario = ts::begin(ADMIN);
    let ctx = scenario.ctx();
    let (mut coll, cap) = multicoin::new_collection(ctx);
    let reward = mint(&cap, &mut coll, 100, ctx);
    let mut uid = object::new(ctx);
    let _esc = escrow::new(&mut uid, reward, 10_001, ctx);
    abort 0 // unreachable
}

// === post_collateral ===

#[test]
fun test_post_collateral_attaches() {
    let mut scenario = ts::begin(ADMIN);
    let ctx = scenario.ctx();
    let (mut coll, cap) = multicoin::new_collection(ctx);
    let reward = mint(&cap, &mut coll, 1000, ctx);
    let coll_bal = mint(&cap, &mut coll, 400, ctx);
    let mut uid = object::new(ctx);

    let mut esc = escrow::new(&mut uid, reward, 8000, ctx);
    escrow::post_collateral(&mut esc, &mut uid, coll_bal);

    assert!(escrow::has_collateral(&esc), 0);
    assert!(escrow::collateral_amount(&esc) == 400, 1);
    assert!(escrow::collateral_exists(&uid), 2);

    // teardown
    let r = escrow::refund_reward(&mut esc, &mut uid, scenario.ctx());
    let c = escrow::refund_collateral(&mut esc, &mut uid, scenario.ctx());
    multicoin::burn(&mut coll, r, scenario.ctx());
    multicoin::burn(&mut coll, c, scenario.ctx());
    escrow::destroy_empty(esc);
    finish(coll, cap, uid);
    scenario.end();
}

#[test, expected_failure(abort_code = 17)] // EInsufficientCollateral — double-post
fun test_post_collateral_aborts_on_double_post() {
    let mut scenario = ts::begin(ADMIN);
    let ctx = scenario.ctx();
    let (mut coll, cap) = multicoin::new_collection(ctx);
    let reward = mint(&cap, &mut coll, 1000, ctx);
    let c1 = mint(&cap, &mut coll, 400, ctx);
    let c2 = mint(&cap, &mut coll, 100, ctx);
    let mut uid = object::new(ctx);

    let mut esc = escrow::new(&mut uid, reward, 8000, ctx);
    escrow::post_collateral(&mut esc, &mut uid, c1);
    escrow::post_collateral(&mut esc, &mut uid, c2); // aborts here

    abort 0
}

// === payout_success ===

#[test]
fun test_payout_success_no_collateral_returns_none() {
    let mut scenario = ts::begin(ADMIN);
    let ctx = scenario.ctx();
    let (mut coll, cap) = multicoin::new_collection(ctx);
    let reward = mint(&cap, &mut coll, 1000, ctx);
    let mut uid = object::new(ctx);

    let mut esc = escrow::new(&mut uid, reward, 7500, ctx);
    let (hauler, treasury, coll_opt) = escrow::payout_success(&mut esc, &mut uid, scenario.ctx());

    assert!(multicoin::value(&hauler) == 750, 0);
    assert!(multicoin::value(&treasury) == 250, 1);
    assert!(coll_opt.is_none(), 2);
    assert!(escrow::reward_amount(&esc) == 0, 3);
    assert!(!escrow::reward_exists(&uid), 4);

    multicoin::burn(&mut coll, hauler, scenario.ctx());
    multicoin::burn(&mut coll, treasury, scenario.ctx());
    coll_opt.destroy_none();
    escrow::destroy_empty(esc);
    finish(coll, cap, uid);
    scenario.end();
}

#[test]
fun test_payout_success_with_collateral_returns_some() {
    let mut scenario = ts::begin(ADMIN);
    let ctx = scenario.ctx();
    let (mut coll, cap) = multicoin::new_collection(ctx);
    let reward = mint(&cap, &mut coll, 1000, ctx);
    let collat = mint(&cap, &mut coll, 400, ctx);
    let mut uid = object::new(ctx);

    let mut esc = escrow::new(&mut uid, reward, 8000, ctx);
    escrow::post_collateral(&mut esc, &mut uid, collat);

    let (hauler, treasury, coll_opt) = escrow::payout_success(&mut esc, &mut uid, scenario.ctx());

    assert!(multicoin::value(&hauler) == 800, 0);
    assert!(multicoin::value(&treasury) == 200, 1);
    assert!(coll_opt.is_some(), 2);
    let collateral_back = coll_opt.destroy_some();
    assert!(multicoin::value(&collateral_back) == 400, 3);
    assert!(!escrow::has_collateral(&esc), 4);
    assert!(!escrow::collateral_exists(&uid), 5);

    multicoin::burn(&mut coll, hauler, scenario.ctx());
    multicoin::burn(&mut coll, treasury, scenario.ctx());
    multicoin::burn(&mut coll, collateral_back, scenario.ctx());
    escrow::destroy_empty(esc);
    finish(coll, cap, uid);
    scenario.end();
}

#[test]
fun test_payout_full_to_hauler_zero_treasury() {
    let mut scenario = ts::begin(ADMIN);
    let ctx = scenario.ctx();
    let (mut coll, cap) = multicoin::new_collection(ctx);
    let reward = mint(&cap, &mut coll, 1000, ctx);
    let mut uid = object::new(ctx);

    let mut esc = escrow::new(&mut uid, reward, 10_000, ctx);
    let (hauler, treasury, coll_opt) = escrow::payout_success(&mut esc, &mut uid, scenario.ctx());

    assert!(multicoin::value(&hauler) == 1000, 0);
    assert!(multicoin::value(&treasury) == 0, 1);

    multicoin::destroy_zero(treasury);
    multicoin::burn(&mut coll, hauler, scenario.ctx());
    coll_opt.destroy_none();
    escrow::destroy_empty(esc);
    finish(coll, cap, uid);
    scenario.end();
}

#[test]
fun test_payout_zero_to_hauler_full_treasury() {
    let mut scenario = ts::begin(ADMIN);
    let ctx = scenario.ctx();
    let (mut coll, cap) = multicoin::new_collection(ctx);
    let reward = mint(&cap, &mut coll, 1000, ctx);
    let mut uid = object::new(ctx);

    let mut esc = escrow::new(&mut uid, reward, 0, ctx);
    let (hauler, treasury, coll_opt) = escrow::payout_success(&mut esc, &mut uid, scenario.ctx());

    assert!(multicoin::value(&hauler) == 0, 0);
    assert!(multicoin::value(&treasury) == 1000, 1);

    multicoin::destroy_zero(hauler);
    multicoin::burn(&mut coll, treasury, scenario.ctx());
    coll_opt.destroy_none();
    escrow::destroy_empty(esc);
    finish(coll, cap, uid);
    scenario.end();
}

// === refunds ===

#[test]
fun test_refund_reward_returns_full_amount() {
    let mut scenario = ts::begin(ADMIN);
    let ctx = scenario.ctx();
    let (mut coll, cap) = multicoin::new_collection(ctx);
    let reward = mint(&cap, &mut coll, 1234, ctx);
    let mut uid = object::new(ctx);

    let mut esc = escrow::new(&mut uid, reward, 8000, ctx);
    let r = escrow::refund_reward(&mut esc, &mut uid, scenario.ctx());

    assert!(multicoin::value(&r) == 1234, 0);
    assert!(escrow::reward_amount(&esc) == 0, 1);
    assert!(!escrow::reward_exists(&uid), 2);

    multicoin::burn(&mut coll, r, scenario.ctx());
    escrow::destroy_empty(esc);
    finish(coll, cap, uid);
    scenario.end();
}

#[test]
fun test_refund_collateral_returns_full_amount() {
    let mut scenario = ts::begin(ADMIN);
    let ctx = scenario.ctx();
    let (mut coll, cap) = multicoin::new_collection(ctx);
    let reward = mint(&cap, &mut coll, 500, ctx);
    let collat = mint(&cap, &mut coll, 321, ctx);
    let mut uid = object::new(ctx);

    let mut esc = escrow::new(&mut uid, reward, 8000, ctx);
    escrow::post_collateral(&mut esc, &mut uid, collat);
    let c = escrow::refund_collateral(&mut esc, &mut uid, scenario.ctx());

    assert!(multicoin::value(&c) == 321, 0);
    assert!(!escrow::has_collateral(&esc), 1);
    assert!(escrow::collateral_amount(&esc) == 0, 2);

    let r = escrow::refund_reward(&mut esc, &mut uid, scenario.ctx());
    multicoin::burn(&mut coll, r, scenario.ctx());
    multicoin::burn(&mut coll, c, scenario.ctx());
    escrow::destroy_empty(esc);
    finish(coll, cap, uid);
    scenario.end();
}

#[test, expected_failure(abort_code = 17)] // EInsufficientCollateral
fun test_refund_collateral_aborts_without_collateral() {
    let mut scenario = ts::begin(ADMIN);
    let ctx = scenario.ctx();
    let (mut coll, cap) = multicoin::new_collection(ctx);
    let reward = mint(&cap, &mut coll, 1000, ctx);
    let mut uid = object::new(ctx);

    let mut esc = escrow::new(&mut uid, reward, 8000, ctx);
    let _c = escrow::refund_collateral(&mut esc, &mut uid, scenario.ctx());
    abort 0
}

// === slash ===

#[test]
fun test_slash_splits_collateral_and_routes_reward_to_treasury() {
    let mut scenario = ts::begin(ADMIN);
    let ctx = scenario.ctx();
    let (mut coll, cap) = multicoin::new_collection(ctx);
    let reward = mint(&cap, &mut coll, 1000, ctx);
    let collat = mint(&cap, &mut coll, 400, ctx);
    let mut uid = object::new(ctx);

    let mut esc = escrow::new(&mut uid, reward, 8000, ctx);
    escrow::post_collateral(&mut esc, &mut uid, collat);

    // 50% slash on 400 collateral = 200 to lister; remaining 200 + 1000 reward = 1200 to treasury.
    let (lister, treasury) = escrow::slash(&mut esc, &mut uid, 5000, scenario.ctx());

    assert!(multicoin::value(&lister) == 200, 0);
    assert!(multicoin::value(&treasury) == 1200, 1);
    assert!(escrow::reward_amount(&esc) == 0, 2);
    assert!(escrow::collateral_amount(&esc) == 0, 3);
    assert!(!escrow::has_collateral(&esc), 4);

    multicoin::burn(&mut coll, lister, scenario.ctx());
    multicoin::burn(&mut coll, treasury, scenario.ctx());
    escrow::destroy_empty(esc);
    finish(coll, cap, uid);
    scenario.end();
}

#[test]
fun test_slash_full_to_lister() {
    let mut scenario = ts::begin(ADMIN);
    let ctx = scenario.ctx();
    let (mut coll, cap) = multicoin::new_collection(ctx);
    let reward = mint(&cap, &mut coll, 1000, ctx);
    let collat = mint(&cap, &mut coll, 400, ctx);
    let mut uid = object::new(ctx);

    let mut esc = escrow::new(&mut uid, reward, 8000, ctx);
    escrow::post_collateral(&mut esc, &mut uid, collat);
    let (lister, treasury) = escrow::slash(&mut esc, &mut uid, 10_000, scenario.ctx());

    assert!(multicoin::value(&lister) == 400, 0);
    assert!(multicoin::value(&treasury) == 1000, 1); // just the reward

    multicoin::burn(&mut coll, lister, scenario.ctx());
    multicoin::burn(&mut coll, treasury, scenario.ctx());
    escrow::destroy_empty(esc);
    finish(coll, cap, uid);
    scenario.end();
}

#[test]
fun test_slash_zero_bps_routes_everything_to_treasury() {
    let mut scenario = ts::begin(ADMIN);
    let ctx = scenario.ctx();
    let (mut coll, cap) = multicoin::new_collection(ctx);
    let reward = mint(&cap, &mut coll, 1000, ctx);
    let collat = mint(&cap, &mut coll, 400, ctx);
    let mut uid = object::new(ctx);

    let mut esc = escrow::new(&mut uid, reward, 8000, ctx);
    escrow::post_collateral(&mut esc, &mut uid, collat);
    // 0% slash = full collateral + full reward to treasury, lister gets zero balance.
    let (lister, treasury) = escrow::slash(&mut esc, &mut uid, 0, scenario.ctx());

    assert!(multicoin::value(&lister) == 0, 0);
    assert!(multicoin::value(&treasury) == 1400, 1);

    multicoin::destroy_zero(lister);
    multicoin::burn(&mut coll, treasury, scenario.ctx());
    escrow::destroy_empty(esc);
    finish(coll, cap, uid);
    scenario.end();
}

#[test, expected_failure(abort_code = 17)] // EInsufficientCollateral
fun test_slash_aborts_without_collateral() {
    let mut scenario = ts::begin(ADMIN);
    let ctx = scenario.ctx();
    let (mut coll, cap) = multicoin::new_collection(ctx);
    let reward = mint(&cap, &mut coll, 1000, ctx);
    let mut uid = object::new(ctx);

    let mut esc = escrow::new(&mut uid, reward, 8000, ctx);
    let (_l, _t) = escrow::slash(&mut esc, &mut uid, 5000, scenario.ctx());
    abort 0
}

#[test, expected_failure(abort_code = 17)] // EInsufficientCollateral
fun test_slash_aborts_on_bps_over_max() {
    let mut scenario = ts::begin(ADMIN);
    let ctx = scenario.ctx();
    let (mut coll, cap) = multicoin::new_collection(ctx);
    let reward = mint(&cap, &mut coll, 1000, ctx);
    let collat = mint(&cap, &mut coll, 400, ctx);
    let mut uid = object::new(ctx);

    let mut esc = escrow::new(&mut uid, reward, 8000, ctx);
    escrow::post_collateral(&mut esc, &mut uid, collat);
    let (_l, _t) = escrow::slash(&mut esc, &mut uid, 10_001, scenario.ctx());
    abort 0
}

// === destroy_empty ===

#[test, expected_failure(abort_code = 16)] // EInsufficientReward (used as 'non-empty reward')
fun test_destroy_empty_aborts_if_reward_nonzero() {
    let mut scenario = ts::begin(ADMIN);
    let ctx = scenario.ctx();
    let (mut coll, cap) = multicoin::new_collection(ctx);
    let reward = mint(&cap, &mut coll, 1000, ctx);
    let mut uid = object::new(ctx);

    let esc = escrow::new(&mut uid, reward, 8000, ctx);
    escrow::destroy_empty(esc); // aborts — reward still 1000

    // unreachable cleanup (would leak); abort_code asserts we got here
    object::delete(uid);
    transfer::public_transfer(coll, ADMIN);
    transfer::public_transfer(cap, ADMIN);
    scenario.end();
}
