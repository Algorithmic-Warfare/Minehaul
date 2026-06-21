/// Reward + collateral escrow for a `HaulAction`.
///
/// Following the warehouse_receipts / armature_vault pattern: the actual
/// `multicoin::Balance` objects are stored as **dynamic object fields** on
/// the HaulAction's UID, keyed by `RewardKey` / `CollateralKey`. The
/// `Escrow` struct holds only metadata (cached amounts, payout split,
/// presence flags). Functions take the HaulAction's `&mut UID` so they can
/// move balances in and out via `dynamic_object_field`.
///
/// Invariant: `reward_amount` and `collateral_amount` cached on the Escrow
/// struct always match `multicoin::value(<the DOF>)`. Only this module
/// touches those DOFs.
module minehaul_core::escrow;

use sui::object::UID;
use sui::tx_context::TxContext;
use sui::dynamic_object_field as dof;
use multicoin::multicoin::{Self, Balance as McBalance};
use minehaul_core::errors;

/// DOF key for the reward Balance on a HaulAction.
public struct RewardKey has copy, drop, store {}

/// DOF key for the collateral Balance on a HaulAction.
public struct CollateralKey has copy, drop, store {}

public struct Escrow has store {
    reward_amount: u64,
    reward_to_hauler_bps: u16, // remainder goes to network treasury
    collateral_amount: u64,
    has_collateral: bool,
}

const BPS_DENOM: u64 = 10_000;

// === Construction ===

/// Attach `reward` as a DOF on `action_uid` and return the metadata struct.
public(package) fun new(
    action_uid: &mut UID,
    reward: McBalance,
    reward_to_hauler_bps: u16,
    _ctx: &mut TxContext,
): Escrow {
    assert!((reward_to_hauler_bps as u64) <= BPS_DENOM, errors::insufficient_reward());
    let reward_amount = multicoin::value(&reward);
    assert!(reward_amount > 0, errors::insufficient_reward());
    dof::add(action_uid, RewardKey {}, reward);
    Escrow {
        reward_amount,
        reward_to_hauler_bps,
        collateral_amount: 0,
        has_collateral: false,
    }
}

// === Mutators ===

/// Attach `collateral` as a DOF. Asserts `!has_collateral` (one carrier per
/// action; no piling on) and that the collateral is non-zero.
public(package) fun post_collateral(
    self: &mut Escrow,
    action_uid: &mut UID,
    collateral: McBalance,
) {
    assert!(!self.has_collateral, errors::insufficient_collateral());
    let collateral_amount = multicoin::value(&collateral);
    assert!(collateral_amount > 0, errors::insufficient_collateral());
    self.collateral_amount = collateral_amount;
    self.has_collateral = true;
    dof::add(action_uid, CollateralKey {}, collateral);
}

/// Successful delivery payout. Removes the reward DOF, splits it into
/// hauler/treasury shares using `reward_to_hauler_bps`, and removes the
/// collateral (if posted). Returns `(hauler_payout, treasury_payout,
/// collateral_returned?)`. Caller transfers / disposes of the returned
/// balances; if `treasury_payout` is zero (e.g. bps=10000), caller must
/// `multicoin::destroy_zero` it. Collateral is None when none was posted.
public(package) fun payout_success(
    self: &mut Escrow,
    action_uid: &mut UID,
    ctx: &mut TxContext,
): (McBalance, McBalance, Option<McBalance>) {
    let mut treasury_payout: McBalance = dof::remove(action_uid, RewardKey {});
    let total = multicoin::value(&treasury_payout);
    let hauler_share = (total * (self.reward_to_hauler_bps as u64)) / BPS_DENOM;
    // multicoin::split aborts on amount==0; mint a zero balance instead so
    // bps=0 (full to treasury) is representable.
    let hauler_payout = if (hauler_share == 0) {
        multicoin::zero(
            multicoin::collection_id(&treasury_payout),
            multicoin::asset_id(&treasury_payout),
            ctx,
        )
    } else {
        multicoin::split(&mut treasury_payout, hauler_share, ctx)
    };

    let collateral_opt = if (self.has_collateral) {
        let c: McBalance = dof::remove(action_uid, CollateralKey {});
        option::some(c)
    } else {
        option::none<McBalance>()
    };

    self.reward_amount = 0;
    self.collateral_amount = 0;
    self.has_collateral = false;

    (hauler_payout, treasury_payout, collateral_opt)
}

/// Refund the reward to the lister (used by `cancel_action` while still
/// `Open`, or `expire_action` when listing TTL elapses with no claim).
public(package) fun refund_reward(
    self: &mut Escrow,
    action_uid: &mut UID,
    _ctx: &mut TxContext,
): McBalance {
    let reward: McBalance = dof::remove(action_uid, RewardKey {});
    self.reward_amount = 0;
    reward
}

/// Return collateral to the hauler — used when an action is voluntarily
/// abandoned before any disputable infraction. Aborts if no collateral was
/// posted.
public(package) fun refund_collateral(
    self: &mut Escrow,
    action_uid: &mut UID,
    _ctx: &mut TxContext,
): McBalance {
    assert!(self.has_collateral, errors::insufficient_collateral());
    let collateral: McBalance = dof::remove(action_uid, CollateralKey {});
    self.collateral_amount = 0;
    self.has_collateral = false;
    collateral
}

/// Dispute resolution that favors the lister. `slash_bps` of the collateral
/// goes to `lister_recovery`; the rest of the collateral plus the full
/// reward goes to `treasury_share`. Aborts if no collateral was posted.
/// Returns `(lister_recovery, treasury_share)`.
public(package) fun slash(
    self: &mut Escrow,
    action_uid: &mut UID,
    slash_bps: u16,
    ctx: &mut TxContext,
): (McBalance, McBalance) {
    assert!((slash_bps as u64) <= BPS_DENOM, errors::insufficient_collateral());
    assert!(self.has_collateral, errors::insufficient_collateral());

    let reward: McBalance = dof::remove(action_uid, RewardKey {});
    let mut treasury_share: McBalance = dof::remove(action_uid, CollateralKey {});

    let coll_total = multicoin::value(&treasury_share);
    let lister_take = (coll_total * (slash_bps as u64)) / BPS_DENOM;
    // Same zero-boundary handling as payout_success.
    let lister_recovery = if (lister_take == 0) {
        multicoin::zero(
            multicoin::collection_id(&treasury_share),
            multicoin::asset_id(&treasury_share),
            ctx,
        )
    } else {
        multicoin::split(&mut treasury_share, lister_take, ctx)
    };

    // Treasury keeps the un-slashed collateral remainder + the full reward.
    multicoin::join(&mut treasury_share, reward, ctx);

    self.reward_amount = 0;
    self.collateral_amount = 0;
    self.has_collateral = false;

    (lister_recovery, treasury_share)
}

/// Drop the metadata after all DOFs have been removed. Asserts both
/// cached amounts are zero.
public(package) fun destroy_empty(self: Escrow) {
    let Escrow { reward_amount, reward_to_hauler_bps: _, collateral_amount, has_collateral } = self;
    assert!(reward_amount == 0, errors::insufficient_reward());
    assert!(collateral_amount == 0, errors::insufficient_collateral());
    assert!(!has_collateral, errors::insufficient_collateral());
}

// === Views ===

public fun reward_amount(self: &Escrow): u64 { self.reward_amount }
public fun collateral_amount(self: &Escrow): u64 { self.collateral_amount }
public fun reward_to_hauler_bps(self: &Escrow): u16 { self.reward_to_hauler_bps }
public fun has_collateral(self: &Escrow): bool { self.has_collateral }

public fun reward_exists(action_uid: &UID): bool {
    dof::exists(action_uid, RewardKey {})
}

public fun collateral_exists(action_uid: &UID): bool {
    dof::exists(action_uid, CollateralKey {})
}

public fun borrow_reward(action_uid: &UID): &McBalance {
    dof::borrow(action_uid, RewardKey {})
}

public fun borrow_collateral(action_uid: &UID): &McBalance {
    dof::borrow(action_uid, CollateralKey {})
}
