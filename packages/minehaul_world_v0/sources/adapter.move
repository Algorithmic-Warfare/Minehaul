/// World-v0 adapter — publish-time init that mints the package's single
/// `AdapterAuth`.
///
/// The auth is shared so clients can pass it to adapter calls and any network can
/// register it. A governance proposal in `minehaul_armature` registers its ID into
/// the network's `AdapterRegistry`; revoking only removes it from that registry.
/// This package exposes no `witnesses::retire_auth` path, so the auth cannot be
/// disabled globally. After registration, modules in this package
/// use their private compiler permit to mint witnesses (see `ssu::verify_ssu`).
module minehaul_world_v0::adapter;

use std::internal;
use sui::tx_context::TxContext;
use sui::transfer;
use minehaul_core::witnesses::{Self, AdapterAuth};

/// Marker whose compiler-issued permit cannot be created outside this module.
public struct WorldV0 {}

/// Constant tag stored on `AdapterAuth.world_version`.
const WORLD_VERSION: u8 = 0;

/// Auto-run by the Sui runtime at publish. Mints and shares one `AdapterAuth`.
fun init(ctx: &mut TxContext) {
    let auth = witnesses::new_auth(internal::permit<WorldV0>(), @minehaul_world_v0, WORLD_VERSION, ctx);
    transfer::public_share_object(auth);
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext): AdapterAuth {
    witnesses::new_auth(internal::permit<WorldV0>(), @minehaul_world_v0, WORLD_VERSION, ctx)
}

public fun world_version(): u8 { WORLD_VERSION }

public(package) fun mint_ssu(
    auth: &AdapterAuth, registry: &witnesses::AdapterRegistry,
    ssu_id: ID, owner_char_id: ID, clock: &sui::clock::Clock,
): witnesses::VerifiedSsu {
    witnesses::mint_verified_ssu(internal::permit<WorldV0>(), auth, registry, ssu_id, owner_char_id, clock)
}
