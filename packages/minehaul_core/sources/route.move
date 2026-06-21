/// Route value type and hop cursor.
///
/// A `Route` is the ordered sequence of gate IDs a hauler must traverse, plus
/// a stable `route_hash` that adapter-minted `MintedPermit`s commit to.
/// Construction is `public(package)` — only `action::create_action` (or a
/// future proximity-proof module) can mint a `Route` from `VerifiedGate`
/// hot potatoes.
///
/// LOAD-BEARING CONTRACT: `compute_route_hash` is the only canonical source
/// of route_hash bytes. The world adapter (minehaul_world_v0/v1) MUST hash
/// permits over the same payload — `bcs(gates) || bcs(network_id)` under
/// `sui::hash::blake2b256` — or every hop will fail with
/// `errors::route_hash_mismatch()`.
module minehaul_core::route;

use sui::object::ID;
use sui::bcs;
use sui::hash;
use minehaul_core::witnesses::{Self, VerifiedGate, MintedPermit};
use minehaul_core::errors;

public struct Route has store, copy, drop {
    gates: vector<ID>,
    route_hash: vector<u8>,
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
    let n = vgates.length();
    assert!(n > 0, errors::route_empty());
    assert!(n <= (max_len as u64), errors::route_too_long());

    let mut vgates_mut = vgates;
    let mut gates_rev = vector::empty<ID>();
    while (!vgates_mut.is_empty()) {
        let vgate = vgates_mut.pop_back();
        let (gid, gnet, _loc, _ts) = witnesses::consume_verified_gate(vgate);
        assert!(gnet == network_id, errors::gate_network_mismatch());
        gates_rev.push_back(gid);
    };
    vgates_mut.destroy_empty();
    gates_rev.reverse();
    let gates = gates_rev;

    let route_hash = compute_route_hash(&gates, network_id);
    Route { gates, route_hash, network_id }
}

/// Empty route for Inject/Extract actions that have no transit hops.
public(package) fun new_empty(network_id: ID): Route {
    let gates = vector::empty<ID>();
    let route_hash = compute_route_hash(&gates, network_id);
    Route { gates, route_hash, network_id }
}

/// Canonical route_hash: blake2b256(bcs(gates) || bcs(network_id)).
/// Order-sensitive — direction-strict routes. Adapters MUST use this exact
/// byte layout when issuing permits.
///
/// Wire format (for adapter implementers in non-Move languages):
///   bcs(vector<ID>) = ULEB128(length) || ID[0] || ID[1] || ...  (each ID = 32 bytes)
///   bcs(ID)         = 32 raw address bytes
/// Concatenate the two, hash with blake2b256, take the 32-byte digest.
/// `route_tests::test_route_hash_golden_vector` pins this format.
fun compute_route_hash(gates: &vector<ID>, network_id: ID): vector<u8> {
    let mut payload = bcs::to_bytes(gates);
    payload.append(bcs::to_bytes(&network_id));
    hash::blake2b256(&payload)
}

// === Cursor ===

public fun new_cursor(): HopCursor {
    HopCursor { next_idx: 0 }
}

public fun cursor_done(self: &HopCursor, route: &Route): bool {
    self.next_idx == (route.gates.length() as u16)
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
    let (p_gate, p_hash, p_hauler, p_exp) = witnesses::consume_permit(permit);
    assert!(p_hash == route.route_hash, errors::route_hash_mismatch());
    assert!(p_hauler == hauler, errors::permit_hauler_mismatch());
    assert!(now_ms < p_exp, errors::permit_expired());

    let idx = cursor.next_idx as u64;
    assert!(idx < route.gates.length(), errors::hop_out_of_order());
    let expected = *route.gates.borrow(idx);
    assert!(p_gate == expected, errors::hop_out_of_order());

    cursor.next_idx = cursor.next_idx + 1;
}

// === Accessors ===

public fun gates(self: &Route): &vector<ID> { &self.gates }
public fun route_hash(self: &Route): &vector<u8> { &self.route_hash }
public fun len(self: &Route): u16 { (self.gates.length() as u16) }
public fun network_id(self: &Route): ID { self.network_id }
public fun is_empty(self: &Route): bool { self.gates.is_empty() }
