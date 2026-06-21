/// LogisticNetwork — per-DAO state stored as armature DAO type-state keyed
/// by the proposal-type marker `P`. One network per DAO; the DAO opts in
/// by proposal-executing `init_network` (or implicitly through the lazy-init
/// path inside `minehaul_armature::configure_network`). SSUs and gates are
/// registered/unregistered through `ExecutionRequest`-gated entries that
/// consume adapter-minted `VerifiedSsu` / `VerifiedGate` hot potatoes.
///
/// `P` is generic at the function boundary so callers in `minehaul_armature`
/// supply their own proposal-type markers (e.g. `ConfigureLogisticNetwork`,
/// `RegisterSsu`) — `init_type_state<P, S>` is keyed by P, so the same DAO
/// can host the network's lazy-init under one P and run subsequent register
/// operations under another P, all targeting the same LogisticNetwork
/// state. Only the FIRST P used is the storage key; downstream callers
/// must use the same P to look up the state.
module minehaul_core::network;

use sui::object::{Self, ID};
use sui::tx_context::TxContext;
use sui::vec_map::{Self, VecMap};
use sui::vec_set::{Self, VecSet};
use armature::dao::{Self, DAO};
use armature::proposal::ExecutionRequest;
use minehaul_core::witnesses::{Self, VerifiedSsu, VerifiedGate};
use minehaul_core::errors;
use minehaul_core::events;

public struct NetworkConfig has store, copy, drop {
    default_reward_collection: ID,
    default_reward_asset_id: u64,
    min_collateral_ratio_bps: u16,
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
    network_id: ID, // cached == object::id(dao) at init time
    config: NetworkConfig,
    registered_ssus: VecMap<ID, RegisteredSsu>,
    registered_gates: VecSet<ID>,
    auxiliary_haulers: VecSet<address>,
    paused: bool,
    actions_open: u64,
    actions_completed: u64,
}

// === Type-state init ===

/// One-shot init: stores `LogisticNetwork` as DAO type-state under
/// proposal-key `P`. Returns the network_id for the caller to spin up
/// per-network state (e.g. AdapterRegistry) in the same PTB.
public fun init_network<P>(
    dao: &mut DAO,
    config: NetworkConfig,
    req: &ExecutionRequest<P>,
    _ctx: &mut TxContext,
): ID {
    let net = LogisticNetwork {
        network_id: dao::id(dao),
        config,
        registered_ssus: vec_map::empty<ID, RegisteredSsu>(),
        registered_gates: vec_set::empty<ID>(),
        auxiliary_haulers: vec_set::empty<address>(),
        paused: false,
        actions_open: 0,
        actions_completed: 0,
    };
    let nid = net.network_id;
    let max_route_len = config.max_route_len;
    let permit_ttl_ms = config.permit_ttl_ms;
    let default_reward_collection = config.default_reward_collection;
    let default_reward_asset_id = config.default_reward_asset_id;
    dao::init_type_state<P, LogisticNetwork>(dao, net, req);
    events::emit_network_configured(events::new_network_configured(
        nid, default_reward_collection, default_reward_asset_id,
        max_route_len, permit_ttl_ms, false,
    ));
    nid
}

// === Configuration ===

public fun set_config<P>(dao: &mut DAO, new_config: NetworkConfig, req: &ExecutionRequest<P>) {
    let net = dao::borrow_type_state_mut<P, LogisticNetwork>(dao, req);
    net.config = new_config;
}

public fun set_paused<P>(dao: &mut DAO, paused: bool, req: &ExecutionRequest<P>) {
    let net = dao::borrow_type_state_mut<P, LogisticNetwork>(dao, req);
    net.paused = paused;
}

// === SSU registration ===

public fun register_ssu<P>(
    dao: &mut DAO,
    vssu: VerifiedSsu,
    mode: OwnershipMode,
    req: &ExecutionRequest<P>,
    _ctx: &mut TxContext,
) {
    let nid = dao::id(dao);
    let (ssu_id, vnet, owner_char_id, verified_at_ms) = witnesses::consume_verified_ssu(vssu);
    assert!(vnet == nid, errors::ssu_network_mismatch());
    let net = dao::borrow_type_state_mut<P, LogisticNetwork>(dao, req);
    assert!(!net.registered_ssus.contains(&ssu_id), errors::already_registered());
    let entry = RegisteredSsu { ssu_id, owner_char_id, mode, registered_at_ms: verified_at_ms };
    net.registered_ssus.insert(ssu_id, entry);
    let (vaulted, lease_expires_at_ms) = match (&mode) {
        OwnershipMode::Vaulted { cap_id: _ } => (true, 0),
        OwnershipMode::Leased { lease_id: _, expires_at_ms } => (false, *expires_at_ms),
    };
    events::emit_ssu_registered(events::new_ssu_registered(
        nid, ssu_id, owner_char_id, vaulted, lease_expires_at_ms,
    ));
}

public fun unregister_ssu<P>(dao: &mut DAO, ssu_id: ID, req: &ExecutionRequest<P>) {
    let net = dao::borrow_type_state_mut<P, LogisticNetwork>(dao, req);
    assert!(net.registered_ssus.contains(&ssu_id), errors::not_registered());
    let (_, _) = net.registered_ssus.remove(&ssu_id);
}

public fun register_gate<P>(
    dao: &mut DAO,
    vgate: VerifiedGate,
    req: &ExecutionRequest<P>,
) {
    let nid = dao::id(dao);
    let (gate_id, vnet, location_id, _ts) = witnesses::consume_verified_gate(vgate);
    assert!(vnet == nid, errors::gate_network_mismatch());
    let net = dao::borrow_type_state_mut<P, LogisticNetwork>(dao, req);
    assert!(!net.registered_gates.contains(&gate_id), errors::already_registered());
    net.registered_gates.insert(gate_id);
    events::emit_gate_registered(events::new_gate_registered(nid, gate_id, location_id));
}

public fun unregister_gate<P>(dao: &mut DAO, gate_id: ID, req: &ExecutionRequest<P>) {
    let net = dao::borrow_type_state_mut<P, LogisticNetwork>(dao, req);
    assert!(net.registered_gates.contains(&gate_id), errors::not_registered());
    net.registered_gates.remove(&gate_id);
}

// === Auxiliary haulers ===

public fun add_auxiliary_hauler<P>(dao: &mut DAO, who: address, req: &ExecutionRequest<P>) {
    let net = dao::borrow_type_state_mut<P, LogisticNetwork>(dao, req);
    assert!(!net.auxiliary_haulers.contains(&who), errors::already_registered());
    net.auxiliary_haulers.insert(who);
}

public fun remove_auxiliary_hauler<P>(dao: &mut DAO, who: address, req: &ExecutionRequest<P>) {
    let net = dao::borrow_type_state_mut<P, LogisticNetwork>(dao, req);
    assert!(net.auxiliary_haulers.contains(&who), errors::not_registered());
    net.auxiliary_haulers.remove(&who);
}

// === Views ===

/// Borrow the LogisticNetwork stored under proposal-key `P`. Caller must
/// know which P the DAO initialized under.
public fun borrow<P>(dao: &DAO): &LogisticNetwork {
    dao::borrow_type_state<P, LogisticNetwork>(dao)
}

public fun has_network<P>(dao: &DAO): bool {
    dao::has_type_state<P>(dao)
}

public fun network_id(self: &LogisticNetwork): ID { self.network_id }
public fun config(self: &LogisticNetwork): &NetworkConfig { &self.config }
public fun is_paused(self: &LogisticNetwork): bool { self.paused }

public fun is_ssu_registered(self: &LogisticNetwork, ssu_id: ID): bool {
    self.registered_ssus.contains(&ssu_id)
}

public fun is_gate_registered(self: &LogisticNetwork, gate_id: ID): bool {
    self.registered_gates.contains(&gate_id)
}

public fun ssu_entry(self: &LogisticNetwork, ssu_id: ID): RegisteredSsu {
    assert!(self.registered_ssus.contains(&ssu_id), errors::ssu_not_registered());
    *self.registered_ssus.get(&ssu_id)
}

public fun is_auxiliary_hauler(self: &LogisticNetwork, who: address): bool {
    self.auxiliary_haulers.contains(&who)
}

public fun ssu_count(self: &LogisticNetwork): u64 { self.registered_ssus.length() }
public fun gate_count(self: &LogisticNetwork): u64 { self.registered_gates.length() }

/// Aborts if `who` cannot claim/run an action on this network.
/// Allowed if: (DAO governance member) OR (auxiliary_haulers.contains) OR
/// (config.allow_open_marketplace). Also asserts `!paused`.
public fun assert_can_haul(self: &LogisticNetwork, dao: &DAO, who: address) {
    assert!(!self.paused, errors::network_paused());
    let allowed = dao::is_governance_member(dao, who)
        || self.auxiliary_haulers.contains(&who)
        || self.config.allow_open_marketplace;
    assert!(allowed, errors::not_network_member());
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
public fun ssu_registered_at_ms(self: &RegisteredSsu): u64 { self.registered_at_ms }

public fun new_vaulted(cap_id: ID): OwnershipMode { OwnershipMode::Vaulted { cap_id } }
public fun new_leased(lease_id: ID, expires_at_ms: u64): OwnershipMode {
    OwnershipMode::Leased { lease_id, expires_at_ms }
}
