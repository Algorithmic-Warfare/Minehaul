module minehaul_armature::cancel_haul_action;

use std::internal;
use armature::{dao::DAO, proposal::ExecutionTicket};
use minehaul_core::action::{Self, HaulAction};
use minehaul_armature::configure_network::ConfigureLogisticNetwork;

public struct CancelHaulAction has store, drop { action_id: ID }

public fun new(action_id: ID): CancelHaulAction { CancelHaulAction { action_id } }

public fun execute(dao: &DAO, action: &mut HaulAction, ticket: ExecutionTicket<CancelHaulAction>, ctx: &mut TxContext) {
    assert!(dao.id() == ticket.ticket_dao_id(), 0);
    assert!(ticket.ticket_payload().action_id == action::id(action), 1);
    action::cancel_action<CancelHaulAction, ConfigureLogisticNetwork>(
        internal::permit(), action, dao, ticket.ticket_request(), ctx,
    );
    ticket.discharge();
}
