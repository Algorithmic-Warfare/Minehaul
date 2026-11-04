/// Localnet-only warehouse-receipts fixture.
///
/// Turns a seeded SSU into a depot as ADR 0009 defines it: a warehouse-receipts
/// vault with the extension installed and frozen. Then mints receipts from
/// items in the SSU owner's inventory and sends them to the actor the scenario
/// names. The owner cap stays with its Character; each call borrows and returns it.
module minehaul_local::receipts;

use sui::{transfer, tx_context::TxContext};
use sui::transfer::Receiving;
use multicoin::multicoin::Collection;
use warehouse_receipts::{receipt::{Self, VaultAuth}, vault::VaultConfig};
use world::{
    access::OwnerCap,
    character::{Self, Character},
    storage_unit::StorageUnit,
};

/// Create the SSU's vault, install warehouse receipts as its extension and
/// freeze the extension configuration.
public fun setup_depot(
    storage_unit: &mut StorageUnit,
    character: &mut Character,
    owner_cap_ticket: Receiving<OwnerCap<StorageUnit>>,
    ctx: &mut TxContext,
) {
    let (owner_cap, receipt) = character::borrow_owner_cap<StorageUnit>(
        character, owner_cap_ticket, ctx,
    );
    receipt::initialize_vault(storage_unit, &owner_cap, ctx);
    storage_unit.authorize_extension<VaultAuth>(&owner_cap);
    storage_unit.freeze_extension_config(&owner_cap);
    character::return_owner_cap(character, owner_cap, receipt);
}

/// Deposit items from the SSU owner's inventory for receipts and send them to
/// `holder`.
public fun deposit_for_holder(
    storage_unit: &mut StorageUnit,
    character: &mut Character,
    owner_cap_ticket: Receiving<OwnerCap<StorageUnit>>,
    vault_config: &VaultConfig,
    collection: &mut Collection,
    type_id: u64,
    quantity: u32,
    holder: address,
    ctx: &mut TxContext,
) {
    let (owner_cap, receipt) = character::borrow_owner_cap<StorageUnit>(
        character, owner_cap_ticket, ctx,
    );
    let balance = receipt::deposit_for_receipt<StorageUnit>(
        storage_unit, character, &owner_cap, vault_config, collection, type_id, quantity, ctx,
    );
    character::return_owner_cap(character, owner_cap, receipt);
    transfer::public_transfer(balance, holder);
}
