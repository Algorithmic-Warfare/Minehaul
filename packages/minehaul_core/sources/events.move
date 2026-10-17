/// Indexer events. All emit functions are `public(package)`; only modules
/// inside minehaul_core call them.
module minehaul_core::events;

use sui::event;
use sui::object::ID;

public struct NetworkConfigured has copy, drop {
    network_id: ID,
    default_reward_collection: ID,
    default_reward_asset_id: u64,
    min_collateral_ratio_bps: u16,
    max_cargo_lines: u8,
    dispute_window_ms: u64,
    allow_open_marketplace: bool,
    treasury_addr: address,
    paused: bool,
}

public struct SsuRegistered has copy, drop {
    network_id: ID,
    ssu_id: ID,
    owner_char_id: ID,
    vaulted: bool,
    lease_expires_at_ms: u64, // 0 if vaulted
}

public struct SsuUnregistered has copy, drop {
    network_id: ID,
    ssu_id: ID,
}

public struct ActionListed has copy, drop {
    network_id: ID,
    action_id: ID,
    lister: address,
    kind_tag: u8, // 0=Inject, 1=Transfer, 2=Extract
    source_ssu: ID,
    destination_ssu: ID,
    reward_collection: ID,
    reward_asset_id: u64,
    reward_amount: u64,
    listing_expires_at_ms: u64,
}

public struct ActionClaimed has copy, drop {
    action_id: ID,
    hauler: address,
    collateral_amount: u64,
    haul_deadline_ms: u64,
}

public struct ActionDelivered has copy, drop {
    action_id: ID,
    hauler: address,
    hauler_payout: u64,
    treasury_payout: u64,
    delivered_at_ms: u64,
}

public struct ActionDisputed has copy, drop {
    action_id: ID,
    opener: address,
    hauler: address,
    opened_at_ms: u64,
}

public struct ActionResolved has copy, drop {
    action_id: ID,
    award_to_hauler: bool,
    slash_bps: u16,
}

public struct ActionExpired has copy, drop {
    action_id: ID,
    was_open: bool, // false => was Claimed/Collected when deadline passed
}

public struct ActionCancelled has copy, drop {
    action_id: ID,
    cancelled_by: address,
}

public struct AdapterRegistered has copy, drop {
    network_id: ID,
    auth_id: ID,
    adapter_pkg: address,
    world_version: u8,
}

/// Removal from one network's registry; the auth stays valid elsewhere.
public struct AdapterRevoked has copy, drop {
    network_id: ID,
    auth_id: ID,
}

/// Global retirement by the adapter; the auth is dead on every network.
public struct AdapterRetired has copy, drop {
    auth_id: ID,
}

public(package) fun emit_network_configured(e: NetworkConfigured) { event::emit(e) }
public(package) fun emit_ssu_registered(e: SsuRegistered)         { event::emit(e) }
public(package) fun emit_ssu_unregistered(e: SsuUnregistered)     { event::emit(e) }
public(package) fun emit_action_listed(e: ActionListed)           { event::emit(e) }
public(package) fun emit_action_claimed(e: ActionClaimed)         { event::emit(e) }
public(package) fun emit_action_delivered(e: ActionDelivered)     { event::emit(e) }
public(package) fun emit_action_disputed(e: ActionDisputed)       { event::emit(e) }
public(package) fun emit_action_resolved(e: ActionResolved)       { event::emit(e) }
public(package) fun emit_action_expired(e: ActionExpired)         { event::emit(e) }
public(package) fun emit_action_cancelled(e: ActionCancelled)     { event::emit(e) }
public(package) fun emit_adapter_registered(e: AdapterRegistered) { event::emit(e) }
public(package) fun emit_adapter_revoked(e: AdapterRevoked)       { event::emit(e) }
public(package) fun emit_adapter_retired(e: AdapterRetired)       { event::emit(e) }

public(package) fun new_network_configured(
    network_id: ID, default_reward_collection: ID, default_reward_asset_id: u64,
    min_collateral_ratio_bps: u16, max_cargo_lines: u8,
    dispute_window_ms: u64, allow_open_marketplace: bool,
    treasury_addr: address, paused: bool,
): NetworkConfigured {
    NetworkConfigured {
        network_id, default_reward_collection, default_reward_asset_id,
        min_collateral_ratio_bps, max_cargo_lines, dispute_window_ms,
        allow_open_marketplace, treasury_addr, paused,
    }
}

public(package) fun new_ssu_registered(
    network_id: ID, ssu_id: ID, owner_char_id: ID, vaulted: bool, lease_expires_at_ms: u64,
): SsuRegistered {
    SsuRegistered { network_id, ssu_id, owner_char_id, vaulted, lease_expires_at_ms }
}

public(package) fun new_ssu_unregistered(network_id: ID, ssu_id: ID): SsuUnregistered {
    SsuUnregistered { network_id, ssu_id }
}

public(package) fun new_action_listed(
    network_id: ID, action_id: ID, lister: address, kind_tag: u8,
    source_ssu: ID, destination_ssu: ID, reward_collection: ID,
    reward_asset_id: u64, reward_amount: u64, listing_expires_at_ms: u64,
): ActionListed {
    ActionListed {
        network_id, action_id, lister, kind_tag, source_ssu, destination_ssu,
        reward_collection, reward_asset_id, reward_amount, listing_expires_at_ms,
    }
}

public(package) fun new_action_claimed(
    action_id: ID, hauler: address, collateral_amount: u64, haul_deadline_ms: u64,
): ActionClaimed {
    ActionClaimed { action_id, hauler, collateral_amount, haul_deadline_ms }
}

public(package) fun new_action_delivered(
    action_id: ID, hauler: address, hauler_payout: u64, treasury_payout: u64, delivered_at_ms: u64,
): ActionDelivered {
    ActionDelivered { action_id, hauler, hauler_payout, treasury_payout, delivered_at_ms }
}

public(package) fun new_action_disputed(
    action_id: ID, opener: address, hauler: address, opened_at_ms: u64,
): ActionDisputed {
    ActionDisputed { action_id, opener, hauler, opened_at_ms }
}

public(package) fun new_action_resolved(
    action_id: ID, award_to_hauler: bool, slash_bps: u16,
): ActionResolved {
    ActionResolved { action_id, award_to_hauler, slash_bps }
}

public(package) fun new_action_expired(action_id: ID, was_open: bool): ActionExpired {
    ActionExpired { action_id, was_open }
}

public(package) fun new_action_cancelled(action_id: ID, cancelled_by: address): ActionCancelled {
    ActionCancelled { action_id, cancelled_by }
}

public(package) fun new_adapter_registered(
    network_id: ID, auth_id: ID, adapter_pkg: address, world_version: u8,
): AdapterRegistered {
    AdapterRegistered { network_id, auth_id, adapter_pkg, world_version }
}

public(package) fun new_adapter_revoked(network_id: ID, auth_id: ID): AdapterRevoked {
    AdapterRevoked { network_id, auth_id }
}

public(package) fun new_adapter_retired(auth_id: ID): AdapterRetired {
    AdapterRetired { auth_id }
}

/// Actual payout, distinct from delivery (which starts the dispute window).
public struct ActionSettled has copy, drop {
    action_id: ID,
    hauler: address,
    hauler_payout: u64,
    treasury_payout: u64,
}

public(package) fun emit_action_settled(action_id: ID, hauler: address, hauler_payout: u64, treasury_payout: u64) {
    event::emit(ActionSettled { action_id, hauler, hauler_payout, treasury_payout });
}
