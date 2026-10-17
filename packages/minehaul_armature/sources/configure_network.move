/// Umbrella proposal type that mutates a DAO's LogisticNetwork.
///
/// Why one proposal type instead of one per operation: armature keys DAO
/// type-state by the proposal-type marker P (`init_type_state<P, S>` /
/// `borrow_type_state_mut<P, S>`). All writes that touch the same
/// LogisticNetwork must come through `ExecutionRequest<ConfigureLogistic
/// Network>` or armature will look up a different storage slot. Rather
/// than splitting state across slots, we run every network mutation
/// (config update, endpoint registration, etc) as a `ConfigureLogisticNetwork`
/// proposal whose payload variant describes the exact operation.
///
/// Why an on-chain enum payload (not a runtime arg): voters approve the
/// ticket payload. If the SSU ID being registered lived in a
/// runtime argument the vote never saw, an execute-time caller could
/// pass any ID to a "ConfigureLogisticNetwork-approved" ticket. The
/// enum payload makes the operation auditable on-chain.
///
/// `VerifiedSsu` hot potatoes still arrive as PTB arguments — they lack
/// `store` and cannot live inside a payload —
/// but the execute handlers assert the witness's id matches the payload
/// variant's id, so voter-visible intent is the authoritative constraint.
module minehaul_armature::configure_network;

use std::internal;
use armature::dao::DAO;
use armature::proposal::ExecutionTicket;
use minehaul_core::network::{Self, NetworkConfig};
use minehaul_core::witnesses::{Self, VerifiedSsu};

// === Errors ===

const EDaoMismatch: u64 = 0;
const EWrongOpVariant: u64 = 1;
const EIntentWitnessMismatch: u64 = 2;

// === Payload ===

/// On-chain operation the ticket is approving. Voters see this.
public enum NetworkOp has drop, store {
    /// Lazy-init or update the network config.
    SetConfig { config: NetworkConfig },
    /// Register an SSU under Vaulted ownership (OwnerCap held in DAO vault).
    RegisterSsuVaulted { ssu_id: ID, cap_id: ID },
    /// Register an SSU under Leased ownership (time-bound, member-owned).
    RegisterSsuLeased { ssu_id: ID, lease_id: ID, expires_at_ms: u64 },
    RegisterAdapter { auth_id: ID },
    RevokeAdapter { auth_id: ID },
    SetPaused { paused: bool },
    UnregisterSsu { ssu_id: ID },
    AddAuxiliaryHauler { hauler: address },
    RemoveAuxiliaryHauler { hauler: address },
}

public struct ConfigureLogisticNetwork has drop, store {
    op: NetworkOp,
}

// Events: emitted from minehaul_core::network during state mutation
// (NetworkConfigured, SsuRegistered). Armature handlers
// don't duplicate them — the on-chain audit trail is owned by core.

// === Constructors ===

public fun new_set_config(config: NetworkConfig): ConfigureLogisticNetwork {
    ConfigureLogisticNetwork { op: NetworkOp::SetConfig { config } }
}

public fun new_register_ssu_vaulted(ssu_id: ID, cap_id: ID): ConfigureLogisticNetwork {
    ConfigureLogisticNetwork { op: NetworkOp::RegisterSsuVaulted { ssu_id, cap_id } }
}

public fun new_register_ssu_leased(
    ssu_id: ID,
    lease_id: ID,
    expires_at_ms: u64,
): ConfigureLogisticNetwork {
    ConfigureLogisticNetwork {
        op: NetworkOp::RegisterSsuLeased { ssu_id, lease_id, expires_at_ms },
    }
}

public fun op(self: &ConfigureLogisticNetwork): &NetworkOp { &self.op }

// === Handlers ===
//
// Each handler accepts the same ticket type but extracts a specific
// variant from the payload. Calling the wrong handler for a given ticket
// aborts with EWrongOpVariant.

/// SetConfig handler. Lazy-inits the LogisticNetwork on first call;
/// otherwise overwrites the existing config.
public fun execute_configure_logistic_network(
    dao: &mut DAO,
    ticket: ExecutionTicket<ConfigureLogisticNetwork>,
    ctx: &mut TxContext,
) {
    assert!(dao.id() == ticket.ticket_dao_id(), EDaoMismatch);
    let payload = ticket.ticket_payload();
    let req = ticket.ticket_request();

    let config = match (&payload.op) {
        NetworkOp::SetConfig { config } => *config,
        _ => abort EWrongOpVariant,
    };

    if (!network::has_network<ConfigureLogisticNetwork>(dao)) {
        let _nid = network::init_network<ConfigureLogisticNetwork>(internal::permit<ConfigureLogisticNetwork>(), dao, config, req, ctx);
    } else {
        network::set_config<ConfigureLogisticNetwork>(internal::permit<ConfigureLogisticNetwork>(), dao, config, req);
    };

    ticket.discharge();
}

/// RegisterSsu handler. Asserts the witness's ssu_id matches the
/// payload variant's ssu_id.
public fun execute_register_ssu(
    dao: &mut DAO,
    ticket: ExecutionTicket<ConfigureLogisticNetwork>,
    vssu: VerifiedSsu,
    ctx: &mut TxContext,
) {
    assert!(dao.id() == ticket.ticket_dao_id(), EDaoMismatch);
    let witness_ssu_id = witnesses::vssu_id(&vssu);
    let payload = ticket.ticket_payload();
    let req = ticket.ticket_request();

    let (expected_ssu_id, mode) = match (&payload.op) {
        NetworkOp::RegisterSsuVaulted { ssu_id, cap_id } => {
            (*ssu_id, network::new_vaulted(*cap_id))
        },
        NetworkOp::RegisterSsuLeased { ssu_id, lease_id, expires_at_ms } => {
            (*ssu_id, network::new_leased(*lease_id, *expires_at_ms))
        },
        _ => abort EWrongOpVariant,
    };
    assert!(witness_ssu_id == expected_ssu_id, EIntentWitnessMismatch);

    network::register_ssu<ConfigureLogisticNetwork>(internal::permit<ConfigureLogisticNetwork>(), dao, vssu, mode, req, ctx);
    ticket.discharge();
}

public fun new_register_adapter(auth_id: ID): ConfigureLogisticNetwork {
    ConfigureLogisticNetwork { op: NetworkOp::RegisterAdapter { auth_id } }
}

public fun new_revoke_adapter(auth_id: ID): ConfigureLogisticNetwork {
    ConfigureLogisticNetwork { op: NetworkOp::RevokeAdapter { auth_id } }
}

public fun new_set_paused(paused: bool): ConfigureLogisticNetwork {
    ConfigureLogisticNetwork { op: NetworkOp::SetPaused { paused } }
}

public fun execute_register_adapter(
    dao: &DAO, ticket: ExecutionTicket<ConfigureLogisticNetwork>,
    registry: &mut witnesses::AdapterRegistry, auth: &witnesses::AdapterAuth,
) {
    assert!(dao.id() == ticket.ticket_dao_id(), EDaoMismatch);
    assert!(network::registry_id(network::borrow<ConfigureLogisticNetwork>(dao)) == object::id(registry), EDaoMismatch);
    let expected = match (&ticket.ticket_payload().op) {
        NetworkOp::RegisterAdapter { auth_id } => *auth_id,
        _ => abort EWrongOpVariant,
    };
    assert!(expected == object::id(auth), EIntentWitnessMismatch);
    witnesses::register_adapter(internal::permit<ConfigureLogisticNetwork>(), registry, auth, ticket.ticket_request());
    ticket.discharge();
}

public fun execute_revoke_adapter(
    dao: &DAO, ticket: ExecutionTicket<ConfigureLogisticNetwork>,
    registry: &mut witnesses::AdapterRegistry, auth: &mut witnesses::AdapterAuth,
) {
    assert!(dao.id() == ticket.ticket_dao_id(), EDaoMismatch);
    assert!(network::registry_id(network::borrow<ConfigureLogisticNetwork>(dao)) == object::id(registry), EDaoMismatch);
    let expected = match (&ticket.ticket_payload().op) {
        NetworkOp::RevokeAdapter { auth_id } => *auth_id,
        _ => abort EWrongOpVariant,
    };
    assert!(expected == object::id(auth), EIntentWitnessMismatch);
    witnesses::revoke_adapter(internal::permit<ConfigureLogisticNetwork>(), registry, auth, ticket.ticket_request());
    ticket.discharge();
}

public fun execute_set_paused(dao: &mut DAO, ticket: ExecutionTicket<ConfigureLogisticNetwork>) {
    assert!(dao.id() == ticket.ticket_dao_id(), EDaoMismatch);
    let paused = match (&ticket.ticket_payload().op) {
        NetworkOp::SetPaused { paused } => *paused,
        _ => abort EWrongOpVariant,
    };
    network::set_paused(internal::permit<ConfigureLogisticNetwork>(), dao, paused, ticket.ticket_request());
    ticket.discharge();
}

public fun new_unregister_ssu(ssu_id: ID): ConfigureLogisticNetwork {
    ConfigureLogisticNetwork { op: NetworkOp::UnregisterSsu { ssu_id } }
}

public fun new_add_auxiliary_hauler(hauler: address): ConfigureLogisticNetwork {
    ConfigureLogisticNetwork { op: NetworkOp::AddAuxiliaryHauler { hauler } }
}

public fun new_remove_auxiliary_hauler(hauler: address): ConfigureLogisticNetwork {
    ConfigureLogisticNetwork { op: NetworkOp::RemoveAuxiliaryHauler { hauler } }
}

/// Operations without world witnesses still bind every argument to the payload.
public fun execute_membership_update(dao: &mut DAO, ticket: ExecutionTicket<ConfigureLogisticNetwork>) {
    assert!(dao.id() == ticket.ticket_dao_id(), EDaoMismatch);
    let req = ticket.ticket_request();
    match (&ticket.ticket_payload().op) {
        NetworkOp::UnregisterSsu { ssu_id } =>
            network::unregister_ssu(internal::permit<ConfigureLogisticNetwork>(), dao, *ssu_id, req),
        NetworkOp::AddAuxiliaryHauler { hauler } =>
            network::add_auxiliary_hauler(internal::permit<ConfigureLogisticNetwork>(), dao, *hauler, req),
        NetworkOp::RemoveAuxiliaryHauler { hauler } =>
            network::remove_auxiliary_hauler(internal::permit<ConfigureLogisticNetwork>(), dao, *hauler, req),
        _ => abort EWrongOpVariant,
    };
    ticket.discharge();
}
