/// A funded Transfer listing with voter-visible terms. On the pinned armature
/// version ticket creation may write the DAO; this handler only reads it.
module minehaul_armature::list_haul_action;

use std::internal;
use armature::{dao::DAO, proposal::ExecutionTicket};
use multicoin::multicoin::{Self, Balance};
use sui::clock::Clock;
use minehaul_core::action::{Self, CargoLine};
use minehaul_armature::configure_network::ConfigureLogisticNetwork;

public struct ListHaulAction has store, drop {
    src_ssu: ID,
    dst_ssu: ID,
    cargo: vector<CargoLine>,
    reward: CargoLine,
    reward_to_hauler_bps: u16,
    lister: address,
    listing_ttl_ms: u64,
    haul_ttl_ms: u64,
}

public fun new(
    src_ssu: ID, dst_ssu: ID, cargo: vector<CargoLine>,
    reward: CargoLine, reward_to_hauler_bps: u16, lister: address,
    listing_ttl_ms: u64, haul_ttl_ms: u64,
): ListHaulAction {
    ListHaulAction { src_ssu, dst_ssu, cargo, reward, reward_to_hauler_bps,
        lister, listing_ttl_ms, haul_ttl_ms }
}

public fun execute(
    dao: &DAO, ticket: ExecutionTicket<ListHaulAction>, cargo: vector<Balance>,
    reward: Balance, clock: &Clock, ctx: &mut TxContext,
): ID {
    assert!(dao.id() == ticket.ticket_dao_id(), 0);
    let p = ticket.ticket_payload();
    assert!(multicoin::collection_id(&reward) == action::cargo_line_collection(&p.reward)
        && multicoin::asset_id(&reward) == action::cargo_line_asset_id(&p.reward)
        && multicoin::value(&reward) == action::cargo_line_qty(&p.reward), 1);
    let id = action::create_action<ListHaulAction, ConfigureLogisticNetwork>(
        internal::permit(), dao, action::new_transfer(p.src_ssu, p.dst_ssu),
        p.cargo, cargo, reward, p.reward_to_hauler_bps, p.lister,
        p.listing_ttl_ms, p.haul_ttl_ms, ticket.ticket_request(), clock, ctx,
    );
    ticket.discharge();
    id
}
