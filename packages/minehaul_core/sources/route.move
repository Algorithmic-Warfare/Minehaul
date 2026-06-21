/// Route value type and hop cursor.
///
/// A `Route` is the ordered sequence of gate IDs a hauler must traverse, plus
/// a stable `route_hash` that adapter-minted `MintedPermit`s commit to.
/// Construction is `public(package)` — only `action::create_action` (or a
/// future proximity-proof module) can mint a `Route` from `VerifiedGate`
/// hot potatoes.
module minehaul_core::route;

use sui::object::ID;
use minehaul_core::witnesses::{VerifiedGate, MintedPermit};

public struct Route has store, copy, drop {
    gates: vector<ID>,
    route_hash: vector<u8>, // hash of BCS(gates) || BCS(network_id)
    network_id: ID,
}

public struct HopCursor has store, copy, drop {
    next_idx: u16,
}

// === Construction ===

/// Build a Route from verified gates. Consumes each `VerifiedGate` hot potato.
/// Asserts every gate's `network_id` matches and that `gates.length() <= max_len`.
public(package) fun new_from_verified(
    network_id: ID,
    vgates: vector<VerifiedGate>,
    max_len: u8,
): Route {
    abort 0
}

/// Empty route for Inject/Extract actions that have no transit hops.
public(package) fun new_empty(network_id: ID): Route {
    abort 0
}

// === Cursor ===

public fun new_cursor(): HopCursor {
    HopCursor { next_idx: 0 }
}

public fun cursor_done(self: &HopCursor, route: &Route): bool {
    self.next_idx == (vector::length(&route.gates) as u16)
}

public fun cursor_index(self: &HopCursor): u16 { self.next_idx }

/// Verify and advance one hop. Consumes the `MintedPermit` hot potato.
/// Asserts permit's `route_hash` matches `route.route_hash`, permit's
/// `gate_id` equals `route.gates[cursor.next_idx]`, permit's `hauler` equals
/// the caller-supplied `hauler`, and `now_ms < permit.expires_at_ms`.
public(package) fun verify_hop(
    route: &Route,
    cursor: &mut HopCursor,
    permit: MintedPermit,
    hauler: address,
    now_ms: u64,
) {
    abort 0
}

// === Accessors ===

public fun gates(self: &Route): &vector<ID> { &self.gates }
public fun route_hash(self: &Route): &vector<u8> { &self.route_hash }
public fun len(self: &Route): u16 { (vector::length(&self.gates) as u16) }
public fun network_id(self: &Route): ID { self.network_id }
public fun is_empty(self: &Route): bool { vector::is_empty(&self.gates) }
