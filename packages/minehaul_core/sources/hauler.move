/// HaulerCap — claim-time cap that tracks an in-flight haul.
///
/// Stored as a dynamic object field on the `HaulAction` shared object, keyed
/// by the hauler's address. `claim_action` constructs it via `new` and
/// attaches it; `record_hop` / `complete_action` borrow it; `destroy`
/// disposes of it at completion or cancellation.
module minehaul_core::hauler;

use sui::object::ID;
use sui::tx_context::{Self, TxContext};
use minehaul_core::route::{Self, Route, HopCursor};
use minehaul_core::witnesses::MintedPermit;

public struct HaulerCap has store {
    action_id: ID,
    hauler: address,
    route_hash: vector<u8>,
    cursor: HopCursor,
    permits_remaining: u16,
    deadline_ms: u64,
}

// === Construction / destruction ===

public(package) fun new(
    action_id: ID,
    hauler: address,
    route: &Route,
    deadline_ms: u64,
): HaulerCap {
    abort 0
}

/// Consume the cap. The caller must have ensured the haul is complete or the
/// action is being cancelled — this function does not re-check.
public(package) fun destroy(self: HaulerCap) {
    let HaulerCap { action_id: _, hauler: _, route_hash: _, cursor: _,
        permits_remaining: _, deadline_ms: _ } = self;
}

// === Accessors ===

public fun action_id(self: &HaulerCap): ID { self.action_id }
public fun hauler(self: &HaulerCap): address { self.hauler }
public fun cursor(self: &HaulerCap): &HopCursor { &self.cursor }
public fun route_hash(self: &HaulerCap): &vector<u8> { &self.route_hash }
public fun permits_remaining(self: &HaulerCap): u16 { self.permits_remaining }
public fun deadline_ms(self: &HaulerCap): u64 { self.deadline_ms }

/// Assert that the transaction sender is the hauler bound to this cap.
/// v0 binding is by address; v1 will swap to a `VerifiedCharacter` witness.
public fun assert_sender(self: &HaulerCap, ctx: &TxContext) {
    assert!(tx_context::sender(ctx) == self.hauler, /* ENotClaimer */ 8);
}

/// Verify and advance one hop via `route::verify_hop`, decrementing
/// `permits_remaining`.
public(package) fun consume_permit(
    self: &mut HaulerCap,
    rt: &Route,
    permit: MintedPermit,
    now_ms: u64,
) {
    route::verify_hop(rt, &mut self.cursor, permit, self.hauler, now_ms);
    self.permits_remaining = self.permits_remaining - 1;
}
