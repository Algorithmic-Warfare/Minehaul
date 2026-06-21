/// Reward + collateral escrow for a `HaulAction`.
///
/// Following the warehouse_receipts / armature_vault pattern: the actual
/// `multicoin::Balance` objects are stored as **dynamic object fields** on
/// the HaulAction's UID, keyed by `RewardKey` / `CollateralKey`. The
/// `Escrow` struct holds only metadata (cached amounts, payout split,
/// presence flags). Functions take the HaulAction's `&mut UID` so they can
/// move balances in and out via `dynamic_object_field`.
module minehaul_core::escrow;

use sui::object::UID;
use sui::tx_context::TxContext;
use sui::dynamic_object_field as dof;
use multicoin::multicoin::Balance as McBalance;

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

// === Construction ===

/// Attach `reward` as a DOF on `action_id_uid` and return the metadata struct.
public(package) fun new(
    action_uid: &mut UID,
    reward: McBalance,
    reward_to_hauler_bps: u16,
    _ctx: &mut TxContext,
): Escrow {
    abort 0
}

// === Mutators ===

/// Attach `collateral` as a DOF. Asserts `!has_collateral` (one carrier per
/// action; no piling on).
public(package) fun post_collateral(
    self: &mut Escrow,
    action_uid: &mut UID,
    collateral: McBalance,
) {
    abort 0
}

/// Successful delivery payout. Removes the reward DOF, splits it into
/// hauler/treasury shares using `reward_to_hauler_bps`, and also removes
/// (and returns) the collateral. Returned tuple is `(hauler_share,
/// treasury_share, collateral_returned)`. Caller transfers them.
public(package) fun payout_success(
    self: &mut Escrow,
    action_uid: &mut UID,
    _ctx: &mut TxContext,
): (McBalance, McBalance, McBalance) {
    abort 0
}

/// Refund the reward to the lister (used by `cancel_action` while still
/// `Open`, or `expire_action` when listing TTL elapses with no claim).
public(package) fun refund_reward(
    self: &mut Escrow,
    action_uid: &mut UID,
    _ctx: &mut TxContext,
): McBalance {
    abort 0
}

/// Return collateral to the hauler — used when an action is voluntarily
/// abandoned before any disputable infraction.
public(package) fun refund_collateral(
    self: &mut Escrow,
    action_uid: &mut UID,
    _ctx: &mut TxContext,
): McBalance {
    abort 0
}

/// Dispute resolution that favors the lister. Slashes `slash_bps` of the
/// collateral to the lister side; the rest plus the reward goes to treasury.
/// Returns `(lister_recovery, treasury_share)`.
public(package) fun slash(
    self: &mut Escrow,
    action_uid: &mut UID,
    slash_bps: u16,
    _ctx: &mut TxContext,
): (McBalance, McBalance) {
    abort 0
}

/// Drop the metadata after all DOFs have been removed. Asserts both
/// `reward_amount` and `collateral_amount` cached values are zero.
public(package) fun destroy_empty(self: Escrow) {
    let Escrow { reward_amount: _, reward_to_hauler_bps: _, collateral_amount: _, has_collateral: _ } = self;
}

// === Views ===

public fun reward_amount(self: &Escrow): u64 { self.reward_amount }
public fun collateral_amount(self: &Escrow): u64 { self.collateral_amount }
public fun reward_to_hauler_bps(self: &Escrow): u16 { self.reward_to_hauler_bps }
public fun has_collateral(self: &Escrow): bool { self.has_collateral }

public fun reward_exists(action_uid: &UID): bool {
    dof::exists_(action_uid, RewardKey {})
}

public fun collateral_exists(action_uid: &UID): bool {
    dof::exists_(action_uid, CollateralKey {})
}

public fun borrow_reward(action_uid: &UID): &McBalance {
    dof::borrow(action_uid, RewardKey {})
}

public fun borrow_collateral(action_uid: &UID): &McBalance {
    dof::borrow(action_uid, CollateralKey {})
}
