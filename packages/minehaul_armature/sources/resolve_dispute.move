/// Governed resolution: the target action and financial outcome are approved
/// together. Keep this proposal type separate from bypass-eligible listing.
module minehaul_armature::resolve_dispute;

use std::internal;
use armature::{dao::DAO, proposal::ExecutionTicket};
use minehaul_core::action::{Self, HaulAction};
use minehaul_armature::configure_network::ConfigureLogisticNetwork;

public struct ResolveDispute has store, drop {
    action_id: ID,
    award_to_hauler: bool,
    slash_bps: u16,
}

public fun new(action_id: ID, award_to_hauler: bool, slash_bps: u16): ResolveDispute {
    ResolveDispute { action_id, award_to_hauler, slash_bps }
}

public fun execute(dao: &DAO, action: &mut HaulAction, ticket: ExecutionTicket<ResolveDispute>, ctx: &mut TxContext) {
    assert!(dao.id() == ticket.ticket_dao_id(), 0);
    let p = ticket.ticket_payload();
    assert!(p.action_id == action::id(action), 1);
    action::resolve_dispute<ResolveDispute, ConfigureLogisticNetwork>(
        internal::permit(), action, dao, p.award_to_hauler, p.slash_bps, ticket.ticket_request(), ctx,
    );
    ticket.discharge();
}
