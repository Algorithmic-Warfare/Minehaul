/// HaulAction — one shared-object lifecycle covering all three logistic
/// actions (Inject / Transfer / Extract).
///
/// Storage layout:
///   - The `HaulAction` shared object holds escrow metadata, route, and
///     status enum.
///   - Cargo `multicoin::Balance` objects hang off the action's UID as
///     dynamic object fields keyed by `(collection_id, asset_id)`.
///   - Reward + collateral `Balance` objects also hang as DOFs (keyed in
///     `escrow.move`).
///   - The `HaulerCap` is attached as a DOF keyed by hauler address once
///     `claim_action` runs; subsequent hops borrow it mutably.
module minehaul_core::action;

use sui::object::{Self, ID, UID};
use sui::clock::Clock;
use sui::tx_context::TxContext;
use sui::dynamic_object_field as dof;
use armature::dao::DAO;
use armature::proposal::ExecutionRequest;
use multicoin::multicoin::Balance as McBalance;
use minehaul_core::route::Route;
use minehaul_core::escrow::Escrow;
use minehaul_core::hauler::HaulerCap;
use minehaul_core::witnesses::{VerifiedSsu, MintedPermit};

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

/// DOF key for the active `HaulerCap` on a HaulAction.
public struct HaulerCapKey has copy, drop, store {
    hauler: address,
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
    InFlight { hauler: address, hops_completed: u16 },
    Delivered { hauler: address, delivered_at_ms: u64 },
    Disputed { hauler: address, opened_at_ms: u64, opener: address },
    Expired,
    Cancelled,
}

public struct HaulAction has key {
    id: UID,
    network_id: ID,
    kind: ActionKind,
    cargo_manifest: vector<CargoLine>,
    route: Route,
    escrow: Escrow,
    status: ActionStatus,
    created_at_ms: u64,
    listing_expires_at_ms: u64,
    haul_deadline_ms: u64, // 0 until claimed
    lister: address,
}

// === Lifecycle entries ===

/// List a new action. Cargo `Balance`s for Transfer/Extract are pre-funded
/// by the caller (passed in `cargo_balances`); for Inject{OffchainImport},
/// the adapter is expected to have minted them and they are passed in here.
/// Returns the new HaulAction's ID; the object is shared via
/// `transfer::share_object`.
public(package) fun create_action<P>(
    dao: &mut DAO,
    kind: ActionKind,
    cargo: vector<CargoLine>,
    cargo_balances: vector<McBalance>,
    route: Route,
    reward: McBalance,
    reward_to_hauler_bps: u16,
    listing_ttl_ms: u64,
    req: &ExecutionRequest<P>,
    clock: &Clock,
    ctx: &mut TxContext,
): ID {
    abort 0
}

/// Open marketplace claim path. Attaches a `HaulerCap` as a DOF keyed by the
/// claimer's address. Posts collateral via `escrow::post_collateral`.
/// Transitions `Open -> Claimed`.
public fun claim_action(
    action: &mut HaulAction,
    dao: &DAO,
    collateral: McBalance,
    haul_ttl_ms: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    abort 0
}

/// Transition `Claimed -> InFlight`. Consumes a `VerifiedSsu` for the source
/// (Transfer/Extract). Adapter must mint it same-tx.
public fun start_haul(
    action: &mut HaulAction,
    src_ssu: VerifiedSsu,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    abort 0
}

/// Consume a permit hot-potato for the next hop on the route. Increments
/// `InFlight.hops_completed`. Asserts the sender is the bound hauler via
/// the attached `HaulerCap`.
public fun record_hop(
    action: &mut HaulAction,
    permit: MintedPermit,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    abort 0
}

/// Transition `InFlight -> Delivered`. Asserts cursor done, consumes
/// destination `VerifiedSsu`, pays out escrow. Detaches and destroys the
/// `HaulerCap`.
public fun complete_action(
    action: &mut HaulAction,
    dst_ssu: VerifiedSsu,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    abort 0
}

/// Withdraw a single cargo Balance for delivery — called by the world
/// adapter inside the same PTB as `complete_action` so the items land in
/// the destination SSU atomically. Asserts the sender is the bound hauler.
public fun withdraw_cargo_for_delivery(
    action: &mut HaulAction,
    collection_id: ID,
    asset_id: u64,
    ctx: &mut TxContext,
): McBalance {
    abort 0
}

/// DAO-vote cancel (Open only). Refunds reward to lister.
public(package) fun cancel_action<P>(
    action: &mut HaulAction,
    req: &ExecutionRequest<P>,
    ctx: &mut TxContext,
) {
    abort 0
}

/// Permissionless expiry. If `Open` and now past `listing_expires_at_ms`,
/// transitions to `Expired` and refunds reward. If `Claimed`/`InFlight` and
/// now past `haul_deadline_ms`, transitions to `Disputed` (collateral on the
/// line; resolution via `resolve_dispute`).
public fun expire_action(action: &mut HaulAction, clock: &Clock, ctx: &mut TxContext) {
    abort 0
}

/// Open a dispute. Callable by lister, hauler, or any DAO governance member
/// within `config.dispute_window_ms` of delivery (or anytime while
/// InFlight). Transitions to `Disputed`.
public fun dispute_action(
    action: &mut HaulAction,
    dao: &DAO,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    abort 0
}

/// DAO-vote dispute resolution. `award_to_hauler = true` -> pay out;
/// `false` -> slash collateral with `slash_bps`. Transitions to a terminal
/// state.
public(package) fun resolve_dispute<P>(
    action: &mut HaulAction,
    award_to_hauler: bool,
    slash_bps: u16,
    req: &ExecutionRequest<P>,
    ctx: &mut TxContext,
) {
    abort 0
}

// === Views ===

public fun id(self: &HaulAction): ID { object::id(self) }
public fun network_id(self: &HaulAction): ID { self.network_id }
public fun kind(self: &HaulAction): &ActionKind { &self.kind }
public fun route(self: &HaulAction): &Route { &self.route }
public fun status(self: &HaulAction): &ActionStatus { &self.status }
public fun lister(self: &HaulAction): address { self.lister }
public fun created_at_ms(self: &HaulAction): u64 { self.created_at_ms }
public fun listing_expires_at_ms(self: &HaulAction): u64 { self.listing_expires_at_ms }
public fun haul_deadline_ms(self: &HaulAction): u64 { self.haul_deadline_ms }
public fun cargo_manifest(self: &HaulAction): &vector<CargoLine> { &self.cargo_manifest }
public fun escrow(self: &HaulAction): &Escrow { &self.escrow }

public fun is_open(self: &HaulAction): bool {
    match (&self.status) {
        ActionStatus::Open => true,
        _ => false,
    }
}

public fun is_delivered(self: &HaulAction): bool {
    match (&self.status) {
        ActionStatus::Delivered { .. } => true,
        _ => false,
    }
}

public fun has_hauler_cap(action: &HaulAction, hauler: address): bool {
    dof::exists_(&action.id, HaulerCapKey { hauler })
}

public fun has_cargo(action: &HaulAction, collection_id: ID, asset_id: u64): bool {
    dof::exists_(&action.id, CargoKey { collection_id, asset_id })
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

