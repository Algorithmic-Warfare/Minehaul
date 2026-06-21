/// Board-voted proposal that initializes or updates a DAO's LogisticNetwork.
///
/// Lazy-init pattern (mirrored from armature_world_bridge::configure_autojoin):
/// the FIRST execution of this proposal type creates the LogisticNetwork
/// type-state with the provided config; subsequent executions update the
/// config in place. No separate "init" proposal needed between
/// EnableProposalType and the first config change.
///
/// Type-state key: `ConfigureLogisticNetwork`. All other minehaul proposal
/// types that need to touch the LogisticNetwork state — RegisterSsu,
/// RegisterGate, etc — re-execute under the SAME key by calling
/// `network::*` functions with their own ExecutionRequest<P>. Wait, no:
/// `init_type_state<P, S>` and `borrow_type_state<P, S>` key the state by
/// P, so they must all use ConfigureLogisticNetwork as the storage key.
/// We achieve this in handlers like `register_ssu` by accepting an
/// `ExecutionTicket<RegisterSsu>` at the boundary, then internally calling
/// `network::register_ssu<ConfigureLogisticNetwork>` — the proposal type
/// is the governance gate; the type-state key is the storage key. They
/// are NOT required to be the same. See `register_assets.move`.
module minehaul_armature::configure_network;

use sui::event;
use armature::dao::DAO;
use armature::proposal::ExecutionTicket;
use minehaul_core::network::{Self, NetworkConfig};

// === Errors ===

const EDaoMismatch: u64 = 0;

// === Payload ===

/// The single payload field is the new config. On first execution we lazy-init
/// the LogisticNetwork; subsequent executions overwrite the config.
public struct ConfigureLogisticNetwork has drop, store {
    config: NetworkConfig,
}

// === Events ===

public struct LogisticNetworkConfigured has copy, drop {
    dao_id: ID,
    initialized: bool, // true on the lazy-init call, false on subsequent updates
}

// === Constructor ===

public fun new(config: NetworkConfig): ConfigureLogisticNetwork {
    ConfigureLogisticNetwork { config }
}

public fun config(self: &ConfigureLogisticNetwork): &NetworkConfig { &self.config }

// === Handler ===

/// Execute a ConfigureLogisticNetwork proposal. Lazy-inits the
/// LogisticNetwork on first call, otherwise updates the existing config.
public fun execute_configure_logistic_network(
    dao: &mut DAO,
    ticket: ExecutionTicket<ConfigureLogisticNetwork>,
    ctx: &mut TxContext,
) {
    assert!(dao.id() == ticket.ticket_dao_id(), EDaoMismatch);
    let dao_id = dao.id();
    let payload = ticket.ticket_payload();
    let req = ticket.ticket_request();

    let initialized = if (!network::has_network<ConfigureLogisticNetwork>(dao)) {
        let _nid = network::init_network<ConfigureLogisticNetwork>(dao, payload.config, req, ctx);
        true
    } else {
        network::set_config<ConfigureLogisticNetwork>(dao, payload.config, req);
        false
    };

    event::emit(LogisticNetworkConfigured { dao_id, initialized });

    ticket.discharge();
}
