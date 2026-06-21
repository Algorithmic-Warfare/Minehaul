/// Proposals that register SSUs and Gates into a DAO's LogisticNetwork.
///
/// Design choice — both handlers run as `ConfigureLogisticNetwork`
/// proposals (NOT distinct proposal types). Reason: armature keys DAO
/// type-state by the proposal-type marker P passed to
/// `init_type_state<P, S>` / `borrow_type_state_mut<P, S>`. The
/// LogisticNetwork is initialized under `ConfigureLogisticNetwork` (see
/// configure_network.move); any subsequent writes must come through an
/// `ExecutionRequest<ConfigureLogisticNetwork>` to land on the same
/// state. Defining `RegisterSsu` / `RegisterGate` as separate proposal
/// types would key their writes to a different type-state slot — a
/// split-brain that buys nothing.
///
/// Instead, `RegisterSsu` and `RegisterGate` here are PAYLOAD shapes for
/// the ConfigureLogisticNetwork ticket: the governance layer passes an
/// `ExecutionTicket<ConfigureLogisticNetwork>` plus the matching intent
/// struct + adapter-minted hot potato. The handler asserts the payload's
/// expected_ssu_id (or expected_gate_id) matches the witness, then
/// invokes `network::register_*` with the ticket's request.
///
/// The hot potato (`VerifiedSsu` / `VerifiedGate`) must arrive as a
/// PTB-level argument because hot potatoes lack `store` and cannot live
/// inside a payload struct.
module minehaul_armature::register_assets;

use sui::event;
use armature::dao::DAO;
use armature::proposal::ExecutionTicket;
use minehaul_core::network;
use minehaul_core::witnesses::{Self, VerifiedSsu, VerifiedGate};
use minehaul_armature::configure_network::ConfigureLogisticNetwork;

const EDaoMismatch: u64 = 0;

// === Payloads ===

/// Marker; the actual VerifiedSsu hot potato arrives separately via the
/// PTB rather than being embedded in this payload (hot potatoes can't have
/// `store`). The payload records the intent for the audit trail.
public struct RegisterSsu has drop, store {
    expected_ssu_id: ID,
    mode_vaulted_cap_id: Option<ID>,        // some => Vaulted, else Leased
    leased_lease_id: Option<ID>,
    leased_expires_at_ms: u64,
}

public struct RegisterGate has drop, store {
    expected_gate_id: ID,
}

// === Events ===

public struct SsuRegistered has copy, drop {
    dao_id: ID,
    ssu_id: ID,
}

public struct GateRegistered has copy, drop {
    dao_id: ID,
    gate_id: ID,
}

// === Constructors ===

public fun new_register_ssu_vaulted(expected_ssu_id: ID, cap_id: ID): RegisterSsu {
    RegisterSsu {
        expected_ssu_id,
        mode_vaulted_cap_id: option::some(cap_id),
        leased_lease_id: option::none(),
        leased_expires_at_ms: 0,
    }
}

public fun new_register_ssu_leased(
    expected_ssu_id: ID,
    lease_id: ID,
    expires_at_ms: u64,
): RegisterSsu {
    RegisterSsu {
        expected_ssu_id,
        mode_vaulted_cap_id: option::none(),
        leased_lease_id: option::some(lease_id),
        leased_expires_at_ms: expires_at_ms,
    }
}

public fun new_register_gate(expected_gate_id: ID): RegisterGate {
    RegisterGate { expected_gate_id }
}

// === Handlers ===

/// Execute a RegisterSsu proposal. The ticket is keyed by
/// ConfigureLogisticNetwork (the proposal MUST be a config proposal in
/// this PR — see module-level doc for the design tradeoff). The payload
/// type RegisterSsu is embedded in the config-key ticket through the
/// `with_payload` pattern, which armature's
/// privileged_create_for_testing supports.
///
/// For this PR, we accept ExecutionTicket<ConfigureLogisticNetwork> with
/// a payload that asserts the embedded RegisterSsu intent matches the
/// supplied VerifiedSsu.
public fun execute_register_ssu(
    dao: &mut DAO,
    ticket: ExecutionTicket<ConfigureLogisticNetwork>,
    intent: RegisterSsu,
    vssu: VerifiedSsu,
    ctx: &mut TxContext,
) {
    assert!(dao.id() == ticket.ticket_dao_id(), EDaoMismatch);
    let dao_id = dao.id();
    let req = ticket.ticket_request();

    // Audit-trail consistency: payload intent must match the witness.
    let ssu_id = witnesses::vssu_id(&vssu);
    assert!(ssu_id == intent.expected_ssu_id, EDaoMismatch);

    let mode = if (intent.mode_vaulted_cap_id.is_some()) {
        network::new_vaulted(*intent.mode_vaulted_cap_id.borrow())
    } else {
        network::new_leased(
            *intent.leased_lease_id.borrow(),
            intent.leased_expires_at_ms,
        )
    };

    network::register_ssu<ConfigureLogisticNetwork>(dao, vssu, mode, req, ctx);
    event::emit(SsuRegistered { dao_id, ssu_id });

    ticket.discharge();
}

public fun execute_register_gate(
    dao: &mut DAO,
    ticket: ExecutionTicket<ConfigureLogisticNetwork>,
    intent: RegisterGate,
    vgate: VerifiedGate,
) {
    assert!(dao.id() == ticket.ticket_dao_id(), EDaoMismatch);
    let dao_id = dao.id();
    let req = ticket.ticket_request();

    let gate_id = witnesses::vgate_id(&vgate);
    assert!(gate_id == intent.expected_gate_id, EDaoMismatch);

    network::register_gate<ConfigureLogisticNetwork>(dao, vgate, req);
    event::emit(GateRegistered { dao_id, gate_id });

    ticket.discharge();
}
