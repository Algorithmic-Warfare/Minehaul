/// Localnet-only bridge simulator and transaction wrappers.
///
/// These functions exercise production Minehaul and armature entry points on a
/// disposable chain. `deliver` simulates the unavailable game-server bridge by
/// transferring the complete tokenized manifest to a fixed receiver before it
/// certifies the non-droppable delivery request.
module minehaul_local::scenario;

use std::internal;
use sui::{clock::Clock, object, transfer, tx_context::TxContext};
use sui::transfer::Receiving;
use armature::{
    board_voting,
    capability_vault::CapabilityVault,
    dao::{Self, DAO},
    emergency::EmergencyFreeze,
    external_execution::{Self, EnableBypassType},
    governance,
    proposal::{Self, ExecutionTicket, ExternalExecutionCap},
};
use multicoin::multicoin::{Self, Balance, Collection};
use minehaul_core::{
    action::{Self, HaulAction},
    network,
    witnesses::{Self, AdapterAuth, AdapterRegistry},
};
use minehaul_armature::{
    cancel_haul_action::{Self, CancelHaulAction},
    configure_network::{Self, ConfigureLogisticNetwork},
    list_haul_action::{Self, ListHaulAction},
    resolve_dispute::{Self, ResolveDispute},
};
use minehaul_world_v0::ssu;
use world::{
    access::OwnerCap,
    character::{Self, Character},
    storage_unit::StorageUnit,
};

/// Compiler identity for the local delivery bridge.
public struct LocalDelivery {}

const LOCAL_ADAPTER_VERSION: u8 = 255;
const TYPE_KEY_CONFIGURE: vector<u8> = b"ConfigureLogisticNetwork";
const TYPE_KEY_LIST: vector<u8> = b"ListHaulAction";
const TYPE_KEY_CANCEL: vector<u8> = b"CancelHaulAction";
const TYPE_KEY_RESOLVE: vector<u8> = b"ResolveDispute";

fun init(ctx: &mut TxContext) {
    let auth = witnesses::new_auth(
        internal::permit<LocalDelivery>(),
        @minehaul_local,
        LOCAL_ADAPTER_VERSION,
        ctx,
    );
    transfer::public_share_object(auth);
}

/// Give each acceptance run an independent authorization so a revocation case
/// cannot poison later runs that reuse the same published package.
entry fun create_delivery_auth(ctx: &mut TxContext) {
    let auth = witnesses::new_auth(
        internal::permit<LocalDelivery>(),
        @minehaul_local,
        LOCAL_ADAPTER_VERSION,
        ctx,
    );
    transfer::public_share_object(auth);
}

/// Create a single-member board DAO for deterministic local execution.
entry fun create_dao(ctx: &mut TxContext) {
    let governance = governance::init_board(vector[ctx.sender()]);
    dao::create(
        &governance,
        b"Minehaul local flow".to_string(),
        b"localnet://minehaul".to_string(),
        ctx,
    );
}

/// Enable every governed Minehaul action used by the acceptance matrix through
/// armature's audited external-execution path.
entry fun enable_types(
    dao: &mut DAO,
    vault: &mut CapabilityVault,
    freeze: &EmergencyFreeze,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    enable_type<ConfigureLogisticNetwork>(
        dao, vault, freeze, TYPE_KEY_CONFIGURE.to_ascii_string(), clock, ctx,
    );
    enable_type<ListHaulAction>(
        dao, vault, freeze, TYPE_KEY_LIST.to_ascii_string(), clock, ctx,
    );
    enable_type<CancelHaulAction>(
        dao, vault, freeze, TYPE_KEY_CANCEL.to_ascii_string(), clock, ctx,
    );
    enable_type<ResolveDispute>(
        dao, vault, freeze, TYPE_KEY_RESOLVE.to_ascii_string(), clock, ctx,
    );
}

/// Create one collection and independently owned collateral balances so the
/// runner can exercise competing claims without test-only constructors.
entry fun create_assets(
    hauler: address,
    competitor: address,
    reward_amount: u64,
    cargo_amount: u64,
    collateral_amount: u64,
    ctx: &mut TxContext,
) {
    let (mut collection, cap) = multicoin::new_collection(ctx);
    let reward = multicoin::mint_balance(&cap, &mut collection, 0, reward_amount, ctx);
    let cargo = multicoin::mint_balance(&cap, &mut collection, 1, cargo_amount, ctx);
    let collateral = multicoin::mint_balance(&cap, &mut collection, 0, collateral_amount, ctx);
    let competitor_collateral = multicoin::mint_balance(
        &cap, &mut collection, 0, collateral_amount, ctx,
    );
    transfer::public_share_object(collection);
    transfer::public_transfer(cap, ctx.sender());
    transfer::public_transfer(reward, ctx.sender());
    transfer::public_transfer(cargo, ctx.sender());
    transfer::public_transfer(collateral, hauler);
    transfer::public_transfer(competitor_collateral, competitor);
}

entry fun configure(
    dao: &mut DAO,
    vault: &CapabilityVault,
    freeze: &EmergencyFreeze,
    collection: &Collection,
    treasury: address,
    min_collateral_ratio_bps: u16,
    dispute_window_ms: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let payload = configure_network::new_set_config(network::new_config(
        object::id(collection), 0, min_collateral_ratio_bps, 16,
        dispute_window_ms, true, treasury,
    ));
    let ticket = configure_ticket(dao, vault, freeze, payload, clock, ctx);
    configure_network::execute_configure_logistic_network(dao, ticket, ctx);
}

entry fun register_adapters(
    dao: &mut DAO,
    vault: &CapabilityVault,
    freeze: &EmergencyFreeze,
    registry: &mut AdapterRegistry,
    world_auth: &AdapterAuth,
    delivery_auth: &AdapterAuth,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    register_adapter(dao, vault, freeze, registry, world_auth, clock, ctx);
    register_adapter(dao, vault, freeze, registry, delivery_auth, clock, ctx);
}

/// Register both real world-contract SSUs using their child-owned OwnerCaps.
entry fun register_endpoints(
    dao: &mut DAO,
    vault: &CapabilityVault,
    freeze: &EmergencyFreeze,
    registry: &AdapterRegistry,
    world_auth: &AdapterAuth,
    character: &mut Character,
    source: &StorageUnit,
    source_cap_ticket: Receiving<OwnerCap<StorageUnit>>,
    destination: &StorageUnit,
    destination_cap_ticket: Receiving<OwnerCap<StorageUnit>>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    register_endpoint(
        dao, vault, freeze, registry, world_auth, character,
        source, source_cap_ticket, clock, ctx,
    );
    register_endpoint(
        dao, vault, freeze, registry, world_auth, character,
        destination, destination_cap_ticket, clock, ctx,
    );
}

entry fun list(
    dao: &mut DAO,
    vault: &CapabilityVault,
    freeze: &EmergencyFreeze,
    source: ID,
    destination: ID,
    cargo: Balance,
    reward: Balance,
    reward_to_hauler_bps: u16,
    listing_ttl_ms: u64,
    haul_ttl_ms: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let collection = multicoin::collection_id(&cargo);
    assert!(multicoin::collection_id(&reward) == collection, 0);
    let payload = list_haul_action::new(
        source,
        destination,
        vector[action::new_cargo_line(
            collection, multicoin::asset_id(&cargo), multicoin::value(&cargo),
        )],
        action::new_cargo_line(
            collection, multicoin::asset_id(&reward), multicoin::value(&reward),
        ),
        reward_to_hauler_bps,
        ctx.sender(),
        listing_ttl_ms,
        haul_ttl_ms,
    );
    let cap = external_cap<ListHaulAction>(vault, dao.id());
    let ticket = external_execution::ticket_from_cap(
        cap,
        dao,
        freeze,
        TYPE_KEY_LIST.to_ascii_string(),
        option::none(),
        payload,
        clock,
        ctx,
    );
    list_haul_action::execute(dao, ticket, vector[cargo], reward, clock, ctx);
}

entry fun claim(
    action: &mut HaulAction,
    dao: &DAO,
    collateral: Balance,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    action::claim_action<ConfigureLogisticNetwork>(action, dao, collateral, clock, ctx);
}

entry fun collect(
    action: &mut HaulAction,
    dao: &DAO,
    clock: &Clock,
    ctx: &TxContext,
) {
    action::confirm_collection<ConfigureLogisticNetwork>(action, dao, clock, ctx);
}

/// Local bridge simulation: move the whole manifest to `receiver`, then certify
/// the destination-bound request with this package's compiler identity.
entry fun deliver(
    action: &mut HaulAction,
    dao: &DAO,
    registry: &AdapterRegistry,
    delivery_auth: &AdapterAuth,
    receiver: address,
    expected_destination: ID,
    clock: &Clock,
    ctx: &TxContext,
) {
    let (cargo, request) = action::withdraw_cargo_for_delivery<ConfigureLogisticNetwork>(
        action, dao, clock, ctx,
    );
    assert!(witnesses::delivery_destination(&request) == expected_destination, 1);
    cargo.do!(|balance| transfer::public_transfer(balance, receiver));
    let proof = witnesses::certify_delivery(
        internal::permit<LocalDelivery>(), delivery_auth, registry, request,
    );
    action::complete_action<ConfigureLogisticNetwork>(action, dao, proof, clock, ctx);
}

entry fun settle(
    action: &mut HaulAction,
    dao: &DAO,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    action::finalize_action<ConfigureLogisticNetwork>(action, dao, clock, ctx);
}

entry fun cancel(
    dao: &mut DAO,
    vault: &CapabilityVault,
    freeze: &EmergencyFreeze,
    action: &mut HaulAction,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let payload = cancel_haul_action::new(action::id(action));
    let ticket = external_ticket<CancelHaulAction>(
        dao, vault, freeze, TYPE_KEY_CANCEL.to_ascii_string(), payload, clock, ctx,
    );
    cancel_haul_action::execute(dao, action, ticket, ctx);
}

entry fun expire(
    action: &mut HaulAction,
    dao: &DAO,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    action::expire_action<ConfigureLogisticNetwork>(action, dao, clock, ctx);
}

entry fun dispute(
    action: &mut HaulAction,
    dao: &DAO,
    clock: &Clock,
    ctx: &TxContext,
) {
    action::dispute_action<ConfigureLogisticNetwork>(action, dao, clock, ctx);
}

entry fun resolve(
    dao: &mut DAO,
    vault: &CapabilityVault,
    freeze: &EmergencyFreeze,
    action: &mut HaulAction,
    award_to_hauler: bool,
    slash_bps: u16,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let payload = resolve_dispute::new(action::id(action), award_to_hauler, slash_bps);
    let ticket = external_ticket<ResolveDispute>(
        dao, vault, freeze, TYPE_KEY_RESOLVE.to_ascii_string(), payload, clock, ctx,
    );
    resolve_dispute::execute(dao, action, ticket, ctx);
}

entry fun revoke_delivery_adapter(
    dao: &mut DAO,
    vault: &CapabilityVault,
    freeze: &EmergencyFreeze,
    registry: &mut AdapterRegistry,
    delivery_auth: &AdapterAuth,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let ticket = configure_ticket(
        dao,
        vault,
        freeze,
        configure_network::new_revoke_adapter(object::id(delivery_auth)),
        clock,
        ctx,
    );
    configure_network::execute_revoke_adapter(dao, ticket, registry, delivery_auth);
}

entry fun set_paused(
    dao: &mut DAO,
    vault: &CapabilityVault,
    freeze: &EmergencyFreeze,
    paused: bool,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let ticket = configure_ticket(
        dao, vault, freeze, configure_network::new_set_paused(paused), clock, ctx,
    );
    configure_network::execute_set_paused(dao, ticket);
}

fun enable_type<T: store>(
    dao: &mut DAO,
    vault: &mut CapabilityVault,
    freeze: &EmergencyFreeze,
    type_key: std::ascii::String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let config = proposal::new_config(1, 5_000, 0, 3_600_000, 0, 0);
    let payload = external_execution::new_enable_bypass_type(type_key, config);
    let ticket = board_voting::submit_vote_execute<EnableBypassType>(
        dao,
        b"EnableBypassType".to_ascii_string(),
        option::none(),
        payload,
        freeze,
        clock,
        ctx,
    );
    external_execution::execute_enable_bypass_type<T>(dao, vault, ticket, ctx);
}

fun external_cap<T: store>(
    vault: &CapabilityVault,
    dao_id: ID,
): &ExternalExecutionCap<T> {
    let ids = vault.ids_for_type<ExternalExecutionCap<T>>();
    assert!(ids.length() == 1, 2);
    vault.borrow_external_cap<T>(dao_id, ids[0])
}

fun configure_ticket(
    dao: &mut DAO,
    vault: &CapabilityVault,
    freeze: &EmergencyFreeze,
    payload: ConfigureLogisticNetwork,
    clock: &Clock,
    ctx: &mut TxContext,
): ExecutionTicket<ConfigureLogisticNetwork> {
    external_execution::ticket_from_cap(
        external_cap<ConfigureLogisticNetwork>(vault, dao.id()),
        dao,
        freeze,
        TYPE_KEY_CONFIGURE.to_ascii_string(),
        option::none(),
        payload,
        clock,
        ctx,
    )
}

fun external_ticket<T: store>(
    dao: &mut DAO,
    vault: &CapabilityVault,
    freeze: &EmergencyFreeze,
    type_key: std::ascii::String,
    payload: T,
    clock: &Clock,
    ctx: &mut TxContext,
): ExecutionTicket<T> {
    external_execution::ticket_from_cap(
        external_cap<T>(vault, dao.id()),
        dao,
        freeze,
        type_key,
        option::none(),
        payload,
        clock,
        ctx,
    )
}

fun register_adapter(
    dao: &mut DAO,
    vault: &CapabilityVault,
    freeze: &EmergencyFreeze,
    registry: &mut AdapterRegistry,
    auth: &AdapterAuth,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let ticket = configure_ticket(
        dao,
        vault,
        freeze,
        configure_network::new_register_adapter(object::id(auth)),
        clock,
        ctx,
    );
    configure_network::execute_register_adapter(dao, ticket, registry, auth);
}

fun register_endpoint(
    dao: &mut DAO,
    vault: &CapabilityVault,
    freeze: &EmergencyFreeze,
    registry: &AdapterRegistry,
    world_auth: &AdapterAuth,
    character: &mut Character,
    endpoint: &StorageUnit,
    owner_cap_ticket: Receiving<OwnerCap<StorageUnit>>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let (owner_cap, receipt) = character::borrow_owner_cap<StorageUnit>(
        character, owner_cap_ticket, ctx,
    );
    let cap_id = object::id(&owner_cap);
    let verified = ssu::verify_ssu(endpoint, &owner_cap, character, world_auth, registry, clock);
    character::return_owner_cap(character, owner_cap, receipt);
    let ticket = configure_ticket(
        dao,
        vault,
        freeze,
        configure_network::new_register_ssu_vaulted(object::id(endpoint), cap_id),
        clock,
        ctx,
    );
    configure_network::execute_register_ssu(dao, ticket, verified, ctx);
}
