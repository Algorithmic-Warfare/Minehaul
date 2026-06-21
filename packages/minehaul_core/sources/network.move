/// LogisticNetwork — per-DAO state stored as armature DAO type-state under
/// the phantom witness `NETWORK`. One network per DAO; the DAO opts in by
/// proposal-executing `init_network`. SSUs and gates are registered/
/// unregistered through `ExecutionRequest`-gated entries that consume
/// adapter-minted `VerifiedSsu` / `VerifiedGate` hot potatoes.
module minehaul_core::network;

use sui::object::ID;
use sui::tx_context::TxContext;
use sui::vec_map::VecMap;
use sui::vec_set::VecSet;
use armature::dao::DAO;
use armature::proposal::ExecutionRequest;
use minehaul_core::witnesses::{VerifiedSsu, VerifiedGate};

/// Phantom witness that scopes the LogisticNetwork in DAO type-state.
public struct NETWORK has drop {}

public struct NetworkConfig has store, copy, drop {
    default_reward_collection: ID,
    default_reward_asset_id: u64,
    min_collateral_ratio_bps: u16, // collateral / reward
    max_route_len: u8,
    max_cargo_lines: u8,
    permit_ttl_ms: u64,
    dispute_window_ms: u64,
    allow_open_marketplace: bool,
    treasury_addr: address,
}

public struct RegisteredSsu has store, copy, drop {
    ssu_id: ID,
    owner_char_id: ID,
    mode: OwnershipMode,
    registered_at_ms: u64,
}

/// How the network controls an SSU.
public enum OwnershipMode has store, copy, drop {
    /// OwnerCap<StorageUnit> custodied in the DAO `capability_vault`.
    Vaulted { cap_id: ID },
    /// Member-owned SSU leased to the network for a window.
    Leased { lease_id: ID, expires_at_ms: u64 },
}

public struct LogisticNetwork has store {
    network_id: ID, // cached == object::id(dao)
    config: NetworkConfig,
    registered_ssus: VecMap<ID, RegisteredSsu>,
    registered_gates: VecSet<ID>,
    auxiliary_haulers: VecSet<address>, // non-member allowlist
    paused: bool,
    actions_open: u64,
    actions_completed: u64,
}

// === Type-state init ===

/// One-shot init: stores `LogisticNetwork` as DAO type-state under
/// phantom-key `NETWORK`. Asserts `req.req_dao_id() == object::id(dao)`.
/// Returns the network_id so the caller can spin up the per-network
/// `AdapterRegistry` in the same PTB.
public(package) fun init_network<P>(
    dao: &mut DAO,
    config: NetworkConfig,
    req: &ExecutionRequest<P>,
    ctx: &mut TxContext,
): ID {
    abort 0
}

// === Configuration ===

public(package) fun set_config<P>(dao: &mut DAO, new_config: NetworkConfig, req: &ExecutionRequest<P>) {
    abort 0
}

public(package) fun set_paused<P>(dao: &mut DAO, paused: bool, req: &ExecutionRequest<P>) {
    abort 0
}

// === SSU registration ===

/// Consumes `vssu` and stores a `RegisteredSsu` entry. Asserts vssu's
/// network_id matches dao.id().
public(package) fun register_ssu<P>(
    dao: &mut DAO,
    vssu: VerifiedSsu,
    mode: OwnershipMode,
    req: &ExecutionRequest<P>,
    ctx: &mut TxContext,
) {
    abort 0
}

public(package) fun unregister_ssu<P>(dao: &mut DAO, ssu_id: ID, req: &ExecutionRequest<P>) {
    abort 0
}

public(package) fun register_gate<P>(
    dao: &mut DAO,
    vgate: VerifiedGate,
    req: &ExecutionRequest<P>,
) {
    abort 0
}

public(package) fun unregister_gate<P>(dao: &mut DAO, gate_id: ID, req: &ExecutionRequest<P>) {
    abort 0
}

// === Auxiliary haulers ===

public(package) fun add_auxiliary_hauler<P>(dao: &mut DAO, who: address, req: &ExecutionRequest<P>) {
    abort 0
}

public(package) fun remove_auxiliary_hauler<P>(dao: &mut DAO, who: address, req: &ExecutionRequest<P>) {
    abort 0
}

// === Views ===

public fun borrow(dao: &DAO): &LogisticNetwork {
    abort 0
}

public fun network_id(self: &LogisticNetwork): ID { self.network_id }
public fun config(self: &LogisticNetwork): &NetworkConfig { &self.config }
public fun is_paused(self: &LogisticNetwork): bool { self.paused }
public fun is_ssu_registered(self: &LogisticNetwork, ssu_id: ID): bool {
    abort 0
}
public fun is_gate_registered(self: &LogisticNetwork, gate_id: ID): bool {
    abort 0
}
public fun ssu_entry(self: &LogisticNetwork, ssu_id: ID): &RegisteredSsu {
    abort 0
}

/// Aborts if `who` cannot claim/run an action on this network.
/// Allowed if: (DAO governance member) OR (auxiliary_haulers.contains) OR
/// (config.allow_open_marketplace). Also asserts `!paused`.
public fun assert_can_haul(self: &LogisticNetwork, dao: &DAO, who: address) {
    abort 0
}

// === Config accessors / constructors ===

public fun new_config(
    default_reward_collection: ID,
    default_reward_asset_id: u64,
    min_collateral_ratio_bps: u16,
    max_route_len: u8,
    max_cargo_lines: u8,
    permit_ttl_ms: u64,
    dispute_window_ms: u64,
    allow_open_marketplace: bool,
    treasury_addr: address,
): NetworkConfig {
    NetworkConfig {
        default_reward_collection, default_reward_asset_id, min_collateral_ratio_bps,
        max_route_len, max_cargo_lines, permit_ttl_ms, dispute_window_ms,
        allow_open_marketplace, treasury_addr,
    }
}

public fun config_max_route_len(self: &NetworkConfig): u8 { self.max_route_len }
public fun config_max_cargo_lines(self: &NetworkConfig): u8 { self.max_cargo_lines }
public fun config_permit_ttl_ms(self: &NetworkConfig): u64 { self.permit_ttl_ms }
public fun config_dispute_window_ms(self: &NetworkConfig): u64 { self.dispute_window_ms }
public fun config_min_collateral_ratio_bps(self: &NetworkConfig): u16 { self.min_collateral_ratio_bps }
public fun config_allow_open_marketplace(self: &NetworkConfig): bool { self.allow_open_marketplace }
public fun config_treasury_addr(self: &NetworkConfig): address { self.treasury_addr }
public fun config_default_reward_collection(self: &NetworkConfig): ID { self.default_reward_collection }
public fun config_default_reward_asset_id(self: &NetworkConfig): u64 { self.default_reward_asset_id }

public fun ssu_id(self: &RegisteredSsu): ID { self.ssu_id }
public fun ssu_owner_char_id(self: &RegisteredSsu): ID { self.owner_char_id }
public fun ssu_mode(self: &RegisteredSsu): &OwnershipMode { &self.mode }

public fun new_vaulted(cap_id: ID): OwnershipMode { OwnershipMode::Vaulted { cap_id } }
public fun new_leased(lease_id: ID, expires_at_ms: u64): OwnershipMode {
    OwnershipMode::Leased { lease_id, expires_at_ms }
}
