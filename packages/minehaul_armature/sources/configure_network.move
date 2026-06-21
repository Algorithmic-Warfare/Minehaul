/// Umbrella proposal type that mutates a DAO's LogisticNetwork.
///
/// Why one proposal type instead of one per operation: armature keys DAO
/// type-state by the proposal-type marker P (`init_type_state<P, S>` /
/// `borrow_type_state_mut<P, S>`). All writes that touch the same
/// LogisticNetwork must come through `ExecutionRequest<ConfigureLogistic
/// Network>` or armature will look up a different storage slot. Rather
/// than splitting state across slots, we run every network mutation
/// (config update, SSU/gate register, etc) as a `ConfigureLogisticNetwork`
/// proposal whose payload variant describes the exact operation.
///
/// Why an on-chain enum payload (not a runtime arg): voters approve the
/// ticket payload. If the SSU/gate ID being registered lived in a
/// runtime argument the vote never saw, an execute-time caller could
/// pass any ID to a "ConfigureLogisticNetwork-approved" ticket. The
/// enum payload makes the operation auditable on-chain.
///
/// Hot potatoes (`VerifiedSsu` / `VerifiedGate`) still arrive as PTB
/// arguments — they lack `store` and cannot live inside a payload —
/// but the execute handlers assert the witness's id matches the payload
/// variant's id, so voter-visible intent is the authoritative gate.
module minehaul_armature::configure_network;

use armature::dao::DAO;
use armature::proposal::ExecutionTicket;
use minehaul_core::network::{Self, NetworkConfig};
use minehaul_core::witnesses::{Self, VerifiedSsu, VerifiedGate};

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
    /// Register a gate into the network.
    RegisterGate { gate_id: ID },
}

public struct ConfigureLogisticNetwork has drop, store {
    op: NetworkOp,
}

// Events: emitted from minehaul_core::network during state mutation
// (NetworkConfigured, SsuRegistered, GateRegistered). Armature handlers
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

public fun new_register_gate(gate_id: ID): ConfigureLogisticNetwork {
    ConfigureLogisticNetwork { op: NetworkOp::RegisterGate { gate_id } }
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
        let _nid = network::init_network<ConfigureLogisticNetwork>(dao, config, req, ctx);
    } else {
        network::set_config<ConfigureLogisticNetwork>(dao, config, req);
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

    network::register_ssu<ConfigureLogisticNetwork>(dao, vssu, mode, req, ctx);
    ticket.discharge();
}

/// RegisterGate handler. Asserts the witness's gate_id matches the
/// payload variant's gate_id.
public fun execute_register_gate(
    dao: &mut DAO,
    ticket: ExecutionTicket<ConfigureLogisticNetwork>,
    vgate: VerifiedGate,
) {
    assert!(dao.id() == ticket.ticket_dao_id(), EDaoMismatch);
    let witness_gate_id = witnesses::vgate_id(&vgate);
    let payload = ticket.ticket_payload();
    let req = ticket.ticket_request();

    let expected_gate_id = match (&payload.op) {
        NetworkOp::RegisterGate { gate_id } => *gate_id,
        _ => abort EWrongOpVariant,
    };
    assert!(witness_gate_id == expected_gate_id, EIntentWitnessMismatch);

    network::register_gate<ConfigureLogisticNetwork>(dao, vgate, req);
    ticket.discharge();
}
