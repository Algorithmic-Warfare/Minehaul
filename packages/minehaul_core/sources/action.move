/// HaulAction — shared-object lifecycle for funded Transfer jobs.
/// Inject and Extract remain reserved domain variants.
///
/// Storage layout:
///   - The `HaulAction` shared object holds endpoint, escrow, and status data.
///     Only Transfer is supported in this milestone.
///   - Cargo `multicoin::Balance` objects hang off the action's UID as
///     dynamic object fields keyed by `(collection_id, asset_id)`.
///   - Reward + collateral `Balance` objects also hang as DOFs (keyed in
///     `escrow.move`).
///   - The claiming hauler is recorded in `status`; the haul deadline in
///     `haul_deadline_ms`.
module minehaul_core::action;

use std::type_name::{Self, TypeName};
use sui::transfer;
use sui::object::{Self, ID, UID};
use sui::clock::Clock;
use sui::tx_context::TxContext;
use sui::dynamic_object_field as dof;
use armature::dao::DAO;
use armature::proposal::ExecutionRequest;
use multicoin::multicoin::{Self, Balance as McBalance};
use minehaul_core::escrow::{Self, Escrow};
use minehaul_core::{network, errors, events};
use minehaul_core::witnesses::{Self, DeliveryRequest, VerifiedDelivery};

// === Domain types ===

public struct CargoLine has store, copy, drop {
    collection_id: ID,
    asset_id: u64,
    qty: u64,
}

/// DOF key for a cargo `multicoin::Balance` on a HaulAction.
public struct CargoKey has copy, drop, store {
    collection_id: ID,
    asset_id: u64,
}

public enum InjectionSource has store, copy, drop {
    OffchainImport { import_id: vector<u8> }, // admin-signed at adapter layer
    MemberDeposit { depositor: address },
    MiningOutput { source_ssu: ID },
}

public enum ExtractionSink has store, copy, drop {
    OffchainExport { export_id: vector<u8> },
    MemberWallet { recipient: address },
    Treasury,
}

public enum ActionKind has store, copy, drop {
    Inject { source: InjectionSource, dst_ssu: ID },
    Transfer { src_ssu: ID, dst_ssu: ID },
    Extract { src_ssu: ID, sink: ExtractionSink },
}

public enum ActionStatus has store, copy, drop {
    Open,
    Claimed { hauler: address, claimed_at_ms: u64 },
    Collected { hauler: address, collected_at_ms: u64 },
    Delivering { hauler: address },
    Delivered { hauler: address, delivered_at_ms: u64 },
    Settled { hauler: address },
    Resolved { hauler: address, award_to_hauler: bool },
    Disputed { hauler: address, opened_at_ms: u64, opener: address },
    Expired,
    Cancelled,
}

public struct HaulAction has key {
    id: UID,
    network_id: ID,
    network_key: TypeName,
    registry_id: ID,
    treasury: address,
    min_collateral_ratio_bps: u16,
    dispute_window_ms: u64,
    haul_duration_ms: u64,
    kind: ActionKind,
    cargo_manifest: vector<CargoLine>,
    escrow: Escrow,
    status: ActionStatus,
    created_at_ms: u64,
    listing_expires_at_ms: u64,
    haul_deadline_ms: u64, // 0 until claimed
    lister: address,
}

// === Transfer lifecycle ===

/// List a funded Transfer. Other action kinds are reserved for later adapters.
/// Both governance identity and handler provenance are checked. The lister and
/// haul duration belong to the approved payload, never to the ticket executor.
public fun create_action<P, K>(
    _permit: std::internal::Permit<P>, dao: &DAO, kind: ActionKind,
    cargo: vector<CargoLine>, cargo_balances: vector<McBalance>,
    reward: McBalance, reward_to_hauler_bps: u16,
    lister: address, listing_ttl_ms: u64, haul_ttl_ms: u64,
    req: &ExecutionRequest<P>, clock: &Clock, ctx: &mut TxContext,
): ID {
    assert!(req.req_dao_id() == dao.id(), errors::wrong_dao());
    let net = network::borrow<K>(dao);
    assert!(!network::is_paused(net), errors::network_paused());
    let now = clock.timestamp_ms();
    assert!(listing_ttl_ms > 0 && haul_ttl_ms > 0, errors::invalid_deadline());
    let cfg = network::config(net);
    let (src, dst) = transfer_endpoints(&kind);
    assert!(src != dst, errors::same_endpoints());
    network::assert_ssu_active(net, src, now);
    network::assert_ssu_active(net, dst, now);
    assert!(!cargo.is_empty(), errors::cargo_empty());
    assert!(cargo.length() <= (network::config_max_cargo_lines(cfg) as u64), errors::cargo_lines_exceed_max());
    assert!(cargo.length() == cargo_balances.length(), errors::cargo_mismatch());
    assert!(multicoin::collection_id(&reward) == network::config_default_reward_collection(cfg)
        && multicoin::asset_id(&reward) == network::config_default_reward_asset_id(cfg), errors::wrong_reward_asset());
    let mut id = object::new(ctx);
    let mut balances = cargo_balances;
    // Vectors are positionally matched; duplicate keys abort before sharing.
    let mut i = cargo.length();
    while (i > 0) {
        i = i - 1;
        let line = &cargo[i];
        let balance = balances.pop_back();
        assert!(line.qty > 0 && line.qty == multicoin::value(&balance)
            && line.collection_id == multicoin::collection_id(&balance)
            && line.asset_id == multicoin::asset_id(&balance), errors::cargo_mismatch());
        let key = CargoKey { collection_id: line.collection_id, asset_id: line.asset_id };
        assert!(!dof::exists(&id, key), errors::cargo_mismatch());
        dof::add(&mut id, key, balance);
    };
    balances.destroy_empty();
    let reward_collection = multicoin::collection_id(&reward);
    let reward_asset = multicoin::asset_id(&reward);
    let escrow = escrow::new(&mut id, reward, reward_to_hauler_bps, ctx);
    let result = HaulAction {
        id, network_id: dao.id(), network_key: type_name::with_defining_ids<K>(),
        registry_id: network::registry_id(net), kind, cargo_manifest: cargo,
        escrow, status: ActionStatus::Open, created_at_ms: now,
        listing_expires_at_ms: now + listing_ttl_ms, haul_deadline_ms: 0,
        haul_duration_ms: haul_ttl_ms, lister,
        treasury: network::config_treasury_addr(cfg),
        min_collateral_ratio_bps: network::config_min_collateral_ratio_bps(cfg),
        dispute_window_ms: network::config_dispute_window_ms(cfg),
    };
    let action_id = object::id(&result);
    events::emit_action_listed(events::new_action_listed(
        dao.id(), action_id, lister, 1, src, dst,
        reward_collection, reward_asset, escrow::reward_amount(&result.escrow), result.listing_expires_at_ms,
    ));
    transfer::share_object(result);
    action_id
}

public fun claim_action<K>(
    action: &mut HaulAction, dao: &DAO, collateral: McBalance,
    clock: &Clock, ctx: &mut TxContext,
) {
    assert_network<K>(action, dao);
    assert!(is_open(action), errors::action_wrong_status());
    let now = clock.timestamp_ms();
    assert!(now < action.listing_expires_at_ms, errors::action_expired());
    let net = network::borrow<K>(dao);
    network::assert_can_haul(net, dao, ctx.sender());
    let (src, dst) = transfer_endpoints(&action.kind);
    network::assert_ssu_active(net, src, now);
    network::assert_ssu_active(net, dst, now);
    // Ratio is in reward-asset units; round up so fractional minima cannot be bypassed.
    let required = (((escrow::reward_amount(&action.escrow) as u128)
        * (action.min_collateral_ratio_bps as u128) + 9999) / 10000);
    assert!((multicoin::value(&collateral) as u128) >= required, errors::insufficient_collateral());
    escrow::post_collateral(&mut action.escrow, &mut action.id, collateral);
    action.haul_deadline_ms = now + action.haul_duration_ms;
    let who = ctx.sender();
    action.status = ActionStatus::Claimed { hauler: who, claimed_at_ms: now };
    events::emit_action_claimed(events::new_action_claimed(
        object::id(action), who, escrow::collateral_amount(&action.escrow), action.haul_deadline_ms,
    ));
}

/// Confirm collection from the approved source endpoint. Minehaul does not
/// prescribe or attest how the hauler travels between the two endpoints.
public fun confirm_collection<K>(
    action: &mut HaulAction, dao: &DAO, clock: &Clock, ctx: &TxContext,
) {
    assert_network<K>(action, dao);
    let who = match (action.status) {
        ActionStatus::Claimed { hauler, .. } => hauler,
        _ => abort errors::action_wrong_status(),
    };
    assert!(who == ctx.sender(), errors::not_claimer());
    assert_before_deadline(action, clock);
    action.status = ActionStatus::Collected { hauler: who, collected_at_ms: clock.timestamp_ms() };
}

/// Releases the entire manifest together with a non-droppable obligation.
/// An authorized adapter must deliver the cargo, certify the obligation, and
/// complete_action must consume that proof, all in the same transaction.
public fun withdraw_cargo_for_delivery<K>(
    action: &mut HaulAction, dao: &DAO, clock: &Clock, ctx: &TxContext,
): (vector<McBalance>, DeliveryRequest) {
    assert_network<K>(action, dao);
    let who = collected_hauler(action);
    assert!(who == ctx.sender(), errors::not_claimer());
    assert_before_deadline(action, clock);
    let (_, destination) = transfer_endpoints(&action.kind);
    let request = witnesses::new_delivery_request(
        object::id(action), action.network_id, action.registry_id, destination, who,
        manifest_hash(action),
    );
    let mut balances = vector[];
    action.cargo_manifest.do_ref!(|line| {
        balances.push_back(dof::remove<CargoKey, McBalance>(&mut action.id,
            CargoKey { collection_id: line.collection_id, asset_id: line.asset_id }));
    });
    action.status = ActionStatus::Delivering { hauler: who };
    (balances, request)
}

/// Records delivery, retaining escrow until the dispute window closes.
public fun complete_action<K>(
    action: &mut HaulAction, dao: &DAO, proof: VerifiedDelivery,
    clock: &Clock, ctx: &TxContext,
) {
    assert_network<K>(action, dao);
    let who = match (action.status) {
        ActionStatus::Delivering { hauler } => hauler,
        _ => abort errors::action_wrong_status(),
    };
    assert!(who == ctx.sender(), errors::not_claimer());
    assert_before_deadline(action, clock);
    let (aid, nid, dst, hauler, manifest) = witnesses::consume_delivery(proof);
    let (_, expected_dst) = transfer_endpoints(&action.kind);
    assert!(aid == object::id(action) && nid == action.network_id && dst == expected_dst
        && hauler == who && manifest == manifest_hash(action), errors::delivery_mismatch());
    action.status = ActionStatus::Delivered { hauler: who, delivered_at_ms: clock.timestamp_ms() };
    events::emit_action_delivered(events::new_action_delivered(object::id(action), who, 0, 0, clock.timestamp_ms()));
}

/// Permissionless settlement after delivery's dispute window; recipients are
/// fixed at listing/claim time, so callers cannot redirect any balance.
public fun finalize_action<K>(action: &mut HaulAction, dao: &DAO, clock: &Clock, ctx: &mut TxContext) {
    assert_network<K>(action, dao);
    let (who, delivered_at_ms) = match (action.status) {
        ActionStatus::Delivered { hauler, delivered_at_ms } => (hauler, delivered_at_ms),
        _ => abort errors::action_wrong_status(),
    };
    assert!(clock.timestamp_ms() >= delivered_at_ms
        && clock.timestamp_ms() - delivered_at_ms >= action.dispute_window_ms, errors::settlement_too_early());
    pay_success(action, who, ctx);
    action.status = ActionStatus::Settled { hauler: who };
}

public fun cancel_action<P, K>(
    _permit: std::internal::Permit<P>, action: &mut HaulAction, dao: &DAO,
    req: &ExecutionRequest<P>, ctx: &mut TxContext,
) {
    assert_network<K>(action, dao);
    assert!(req.req_dao_id() == action.network_id, errors::wrong_dao());
    assert!(is_open(action), errors::action_wrong_status());
    refund_open(action, ctx);
    action.status = ActionStatus::Cancelled;
    events::emit_action_cancelled(events::new_action_cancelled(object::id(action), ctx.sender()));
}

public fun expire_action<K>(action: &mut HaulAction, dao: &DAO, clock: &Clock, ctx: &mut TxContext) {
    assert_network<K>(action, dao);
    let now = clock.timestamp_ms();
    let was_open = is_open(action);
    if (was_open) {
        assert!(now >= action.listing_expires_at_ms, errors::invalid_deadline());
        refund_open(action, ctx);
        action.status = ActionStatus::Expired;
    } else {
        let who = match (action.status) {
            ActionStatus::Claimed { hauler, .. } | ActionStatus::Collected { hauler, .. } => hauler,
            _ => abort errors::action_wrong_status(),
        };
        assert!(now >= action.haul_deadline_ms, errors::invalid_deadline());
        open_dispute(action, who, now, ctx.sender());
    };
    events::emit_action_expired(events::new_action_expired(object::id(action), was_open));
}

public fun dispute_action<K>(action: &mut HaulAction, dao: &DAO, clock: &Clock, ctx: &TxContext) {
    assert_network<K>(action, dao);
    let now = clock.timestamp_ms();
    let who = match (action.status) {
        ActionStatus::Collected { hauler, .. } => hauler,
        ActionStatus::Delivered { hauler, delivered_at_ms } => {
            assert!(now >= delivered_at_ms && now - delivered_at_ms < action.dispute_window_ms,
                errors::dispute_window_closed());
            hauler
        },
        _ => abort errors::action_wrong_status(),
    };
    assert!(ctx.sender() == action.lister || ctx.sender() == who
        || armature::dao::is_governance_member(dao, ctx.sender()), errors::not_dispute_arbiter());
    open_dispute(action, who, now, ctx.sender());
}

public fun resolve_dispute<P, K>(
    _permit: std::internal::Permit<P>, action: &mut HaulAction, dao: &DAO,
    award_to_hauler: bool, slash_bps: u16, req: &ExecutionRequest<P>, ctx: &mut TxContext,
) {
    assert_network<K>(action, dao);
    assert!(req.req_dao_id() == action.network_id, errors::wrong_dao());
    let who = match (action.status) {
        ActionStatus::Disputed { hauler, .. } => hauler,
        _ => abort errors::action_wrong_status(),
    };
    assert!(slash_bps <= 10000, errors::invalid_bps());
    if (award_to_hauler) {
        assert!(slash_bps == 0, errors::invalid_ruling());
        pay_success(action, who, ctx);
    } else {
        let (lister, treasury) = escrow::slash(&mut action.escrow, &mut action.id, slash_bps, ctx);
        send(lister, action.lister);
        send(treasury, action.treasury);
    };
    refund_cargo(action);
    action.status = ActionStatus::Resolved { hauler: who, award_to_hauler };
    events::emit_action_resolved(events::new_action_resolved(object::id(action), award_to_hauler, slash_bps));
}

fun assert_network<K>(action: &HaulAction, dao: &DAO) {
    assert!(action.network_id == dao.id(), errors::wrong_dao());
    assert!(action.network_key == type_name::with_defining_ids<K>(), errors::network_key_mismatch());
}

fun transfer_endpoints(kind: &ActionKind): (ID, ID) {
    match (kind) {
        ActionKind::Transfer { src_ssu, dst_ssu } => (*src_ssu, *dst_ssu),
        _ => abort errors::unsupported_action(),
    }
}

fun assert_before_deadline(action: &HaulAction, clock: &Clock) {
    assert!(clock.timestamp_ms() < action.haul_deadline_ms, errors::action_expired());
}

fun collected_hauler(action: &HaulAction): address {
    match (action.status) {
        ActionStatus::Collected { hauler, .. } => hauler,
        _ => abort errors::action_wrong_status(),
    }
}

fun send(balance: McBalance, recipient: address) {
    if (multicoin::value(&balance) == 0) multicoin::destroy_zero(balance)
    else transfer::public_transfer(balance, recipient);
}

fun refund_cargo(action: &mut HaulAction) {
    action.cargo_manifest.do_ref!(|line| {
        let key = CargoKey { collection_id: line.collection_id, asset_id: line.asset_id };
        if (dof::exists(&action.id, key)) send(dof::remove(&mut action.id, key), action.lister);
    });
}

fun refund_open(action: &mut HaulAction, ctx: &mut TxContext) {
    send(escrow::refund_reward(&mut action.escrow, &mut action.id, ctx), action.lister);
    refund_cargo(action);
}

fun pay_success(action: &mut HaulAction, who: address, ctx: &mut TxContext) {
    let (reward, treasury, mut collateral) = escrow::payout_success(&mut action.escrow, &mut action.id, ctx);
    let hauler_amount = multicoin::value(&reward);
    let treasury_amount = multicoin::value(&treasury);
    send(reward, who);
    send(treasury, action.treasury);
    if (collateral.is_some()) send(collateral.extract(), who);
    collateral.destroy_none();
    events::emit_action_settled(object::id(action), who, hauler_amount, treasury_amount);
}

fun open_dispute(action: &mut HaulAction, who: address, now: u64, opener: address) {
    action.status = ActionStatus::Disputed { hauler: who, opened_at_ms: now, opener };
    events::emit_action_disputed(events::new_action_disputed(object::id(action), opener, who, now));
}

public fun manifest_hash(action: &HaulAction): vector<u8> {
    sui::hash::blake2b256(&sui::bcs::to_bytes(&action.cargo_manifest))
}

// === Views ===

public fun id(self: &HaulAction): ID { object::id(self) }
public fun network_id(self: &HaulAction): ID { self.network_id }
public fun kind(self: &HaulAction): &ActionKind { &self.kind }
public fun status(self: &HaulAction): &ActionStatus { &self.status }
public fun lister(self: &HaulAction): address { self.lister }
public fun created_at_ms(self: &HaulAction): u64 { self.created_at_ms }
public fun listing_expires_at_ms(self: &HaulAction): u64 { self.listing_expires_at_ms }
public fun haul_deadline_ms(self: &HaulAction): u64 { self.haul_deadline_ms }
public fun cargo_manifest(self: &HaulAction): &vector<CargoLine> { &self.cargo_manifest }
public fun escrow(self: &HaulAction): &Escrow { &self.escrow }
public fun source_ssu(self: &HaulAction): ID {
    let (source, _) = transfer_endpoints(&self.kind);
    source
}
public fun destination_ssu(self: &HaulAction): ID {
    let (_, destination) = transfer_endpoints(&self.kind);
    destination
}

public fun is_open(self: &HaulAction): bool {
    match (&self.status) {
        ActionStatus::Open => true,
        _ => false,
    }
}

public fun is_collected(self: &HaulAction): bool {
    match (&self.status) {
        ActionStatus::Collected { .. } => true,
        _ => false,
    }
}

public fun is_delivered(self: &HaulAction): bool {
    match (&self.status) {
        ActionStatus::Delivered { .. } => true,
        _ => false,
    }
}

public fun has_cargo(action: &HaulAction, collection_id: ID, asset_id: u64): bool {
    dof::exists(&action.id, CargoKey { collection_id, asset_id })
}

// === Domain constructors ===

public fun new_cargo_line(collection_id: ID, asset_id: u64, qty: u64): CargoLine {
    CargoLine { collection_id, asset_id, qty }
}

public fun cargo_line_collection(self: &CargoLine): ID { self.collection_id }
public fun cargo_line_asset_id(self: &CargoLine): u64 { self.asset_id }
public fun cargo_line_qty(self: &CargoLine): u64 { self.qty }

public fun new_inject(source: InjectionSource, dst_ssu: ID): ActionKind {
    ActionKind::Inject { source, dst_ssu }
}
public fun new_transfer(src_ssu: ID, dst_ssu: ID): ActionKind {
    ActionKind::Transfer { src_ssu, dst_ssu }
}
public fun new_extract(src_ssu: ID, sink: ExtractionSink): ActionKind {
    ActionKind::Extract { src_ssu, sink }
}

public fun source_offchain_import(import_id: vector<u8>): InjectionSource {
    InjectionSource::OffchainImport { import_id }
}
public fun source_member_deposit(depositor: address): InjectionSource {
    InjectionSource::MemberDeposit { depositor }
}
public fun source_mining_output(source_ssu: ID): InjectionSource {
    InjectionSource::MiningOutput { source_ssu }
}

public fun sink_offchain_export(export_id: vector<u8>): ExtractionSink {
    ExtractionSink::OffchainExport { export_id }
}
public fun sink_member_wallet(recipient: address): ExtractionSink {
    ExtractionSink::MemberWallet { recipient }
}
public fun sink_treasury(): ExtractionSink {
    ExtractionSink::Treasury
}


public fun is_settled(action: &HaulAction): bool {
    match (&action.status) { ActionStatus::Settled { .. } => true, _ => false }
}

public fun is_cancelled(action: &HaulAction): bool {
    match (&action.status) { ActionStatus::Cancelled => true, _ => false }
}

public fun is_expired(action: &HaulAction): bool {
    match (&action.status) { ActionStatus::Expired => true, _ => false }
}

public fun is_resolved(action: &HaulAction): bool {
    match (&action.status) { ActionStatus::Resolved { .. } => true, _ => false }
}

public fun is_disputed(action: &HaulAction): bool {
    match (&action.status) { ActionStatus::Disputed { .. } => true, _ => false }
}
