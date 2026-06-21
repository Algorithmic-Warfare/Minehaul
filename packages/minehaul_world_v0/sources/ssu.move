/// SSU verification slice.
///
/// Given a live `world::storage_unit::StorageUnit`, its matching
/// `OwnerCap<StorageUnit>`, and the player's `Character`, verify ownership
/// against world-contracts and mint a `VerifiedSsu` hot potato that
/// `minehaul_core::network::register_ssu` can consume in the same PTB.
///
/// The PTB shape (once `minehaul_armature` lands):
///
///   1. armature mints ExecutionTicket<RegisterSsu> via proposal
///   2. caller borrows ExecutionRequest from the ticket
///   3. caller calls `ssu::verify_ssu` here → VerifiedSsu
///   4. caller calls `network::register_ssu(dao, vssu, mode, req, ctx)`
///   5. armature consumes the ticket
///
/// This module owns step 3 only.
module minehaul_world_v0::ssu;

use sui::object;
use sui::clock::Clock;
use minehaul_core::witnesses::{Self, AdapterAuth, AdapterRegistry, VerifiedSsu};
use world::storage_unit::StorageUnit;
use world::access::{Self, OwnerCap};
use world::character::{Self, Character};

const EOwnerCapMismatch: u64 = 1;

/// Verify SSU ownership against world-contracts and mint a VerifiedSsu.
///
/// Asserts:
///   - `owner_cap` authorizes `ssu` (`world::access::is_authorized`)
///   - `auth` is non-revoked and registered on `registry`
///     (enforced by `witnesses::mint_verified_ssu`)
///
/// The character is recorded on the witness as `owner_char_id` for downstream
/// audit; we do NOT currently enforce that `character` is the SSU's owner —
/// the OwnerCap check is the authoritative ownership proof.
public fun verify_ssu(
    ssu: &StorageUnit,
    owner_cap: &OwnerCap<StorageUnit>,
    character: &Character,
    auth: &AdapterAuth,
    registry: &AdapterRegistry,
    clock: &Clock,
): VerifiedSsu {
    let ssu_id = object::id(ssu);
    assert!(access::is_authorized(owner_cap, ssu_id), EOwnerCapMismatch);
    let owner_char_id = character::owner_cap_id(character);
    witnesses::mint_verified_ssu(auth, registry, ssu_id, owner_char_id, clock)
}
