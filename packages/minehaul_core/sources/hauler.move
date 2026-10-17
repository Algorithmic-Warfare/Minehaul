/// HaulerCap — claim-time identity for an active haul.
///
/// Stored as a dynamic field on the `HaulAction` shared object, keyed
/// by the hauler's address. `claim_action` constructs it via `new` and
/// attaches it; delivery completion or dispute resolution consumes it.
module minehaul_core::hauler;

use sui::object::ID;
use sui::tx_context::{Self, TxContext};
use minehaul_core::errors;

public struct HaulerCap has store {
    action_id: ID,
    hauler: address,
    deadline_ms: u64,
}

// === Construction / destruction ===

public(package) fun new(
    action_id: ID,
    hauler: address,
    deadline_ms: u64,
): HaulerCap {
    HaulerCap {
        action_id,
        hauler,
        deadline_ms,
    }
}

/// Consume the cap. The caller must have ensured the haul is complete or the
/// action is being cancelled — this function does not re-check.
public(package) fun destroy(self: HaulerCap) {
    let HaulerCap { action_id: _, hauler: _, deadline_ms: _ } = self;
}

// === Accessors ===

public fun action_id(self: &HaulerCap): ID { self.action_id }
public fun hauler(self: &HaulerCap): address { self.hauler }
public fun deadline_ms(self: &HaulerCap): u64 { self.deadline_ms }

/// Assert that the transaction sender is the hauler bound to this cap.
/// v0 binding is by address; v1 will swap to a `VerifiedCharacter` witness.
public fun assert_sender(self: &HaulerCap, ctx: &TxContext) {
    assert!(tx_context::sender(ctx) == self.hauler, errors::not_claimer());
}
