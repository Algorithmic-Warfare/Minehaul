/// World-v0 adapter — publish-time init that mints the package's single
/// `AdapterAuth`.
///
/// The auth is transferred to the publisher; the publisher then deposits
/// it into a DAO's capability_vault and a governance proposal in
/// `minehaul_armature` (future PR) registers its ID into the network's
/// `AdapterRegistry`. After registration, any module in this package
/// holding `&AdapterAuth + &AdapterRegistry` can mint verification
/// witnesses (see `ssu::verify_ssu`).
module minehaul_world_v0::adapter;

use sui::tx_context::{Self, TxContext};
use sui::transfer;
use minehaul_core::witnesses::{Self, AdapterAuth};

/// Constant tag stored on `AdapterAuth.world_version`. v1 adapters will use 1.
const WORLD_VERSION: u8 = 0;

/// Auto-run by the Sui runtime at publish. Mints one `AdapterAuth` for this
/// package and transfers it to the publisher.
fun init(ctx: &mut TxContext) {
    let auth = witnesses::new_auth(@minehaul_world_v0, WORLD_VERSION, ctx);
    transfer::public_transfer(auth, tx_context::sender(ctx));
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext): AdapterAuth {
    witnesses::new_auth(@minehaul_world_v0, WORLD_VERSION, ctx)
}

public fun world_version(): u8 { WORLD_VERSION }
