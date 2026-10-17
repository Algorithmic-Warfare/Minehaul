/// Uses real world StorageUnit, Character and OwnerCap objects. Governance
/// requests are synthesized, but registry creation and authorization are real.
#[test_only]
module minehaul_world_v0::ssu_tests;

use std::internal;
use sui::{clock, test_scenario as ts, transfer};
use armature::{dao::{Self, DAO}, governance, proposal};
use minehaul_core::{network, witnesses::{Self, AdapterRegistry}};
use minehaul_world_v0::{adapter, ssu};
use world::{access::{AdminACL, OwnerCap}, character::{Self, Character},
    network_node, object_registry::ObjectRegistry,
    storage_unit::{Self, StorageUnit}, test_helpers};

public struct NetworkKey {}
const OWNER: address = @0xC;

#[test]
fun real_ssu_capability_verifies_and_registers() {
    let mut s = ts::begin(test_helpers::governor());
    test_helpers::setup_world(&mut s);
    s.next_tx(test_helpers::admin());
    let acl = s.take_shared<AdminACL>();
    let mut objects = s.take_shared<ObjectRegistry>();
    let character = character::create_character(&mut objects, &acl, 1234, b"TEST".to_string(),
        100, OWNER, b"Owner".to_string(), s.ctx());
    let character_id = object::id(&character);
    let mut node = network_node::anchor(&mut objects, &character, &acl,
        5000, 111000, x"0000000000000000000000000000000000000000000000000000000000000000", 1000, 3600000, 100, s.ctx());
    let storage = storage_unit::anchor(&mut objects, &mut node, &character, &acl,
        90002, 5555, 100000, x"0000000000000000000000000000000000000000000000000000000000000000", s.ctx());
    let storage_id = object::id(&storage);
    storage.share_storage_unit(&acl, s.ctx());
    node.share_network_node(&acl, s.ctx());
    character.share_character(&acl, s.ctx());
    ts::return_shared(objects);
    ts::return_shared(acl);
    s.next_tx(OWNER);
    let init = governance::init_board(vector[OWNER]);
    dao::create(&init, b"World integration".to_string(), b"".to_string(), s.ctx());
    s.next_tx(OWNER);
    let mut dao = s.take_shared<DAO>();
    let req = proposal::new_execution_request_for_testing<NetworkKey>(dao.id(), storage_id);
    let cfg = network::new_config(storage_id, 0, 2000, 16, 100, false, OWNER);
    network::init_network(internal::permit<NetworkKey>(), &mut dao, cfg, &req, s.ctx());
    proposal::consume_execution_request_for_testing(req);
    ts::return_shared(dao);
    s.next_tx(OWNER);
    let mut dao = s.take_shared<DAO>();
    let req = proposal::new_execution_request_for_testing<NetworkKey>(dao.id(), storage_id);
    let mut registry = s.take_shared<AdapterRegistry>();
    let auth = adapter::init_for_testing(s.ctx());
    witnesses::register_adapter(internal::permit<NetworkKey>(), &mut registry, &auth, &req);
    let mut character = s.take_shared_by_id<Character>(character_id);
    let (owner_cap, receipt) = character.borrow_owner_cap<StorageUnit>(
        ts::most_recent_receiving_ticket<OwnerCap<StorageUnit>>(&character_id), s.ctx());
    let storage = s.take_shared<StorageUnit>();
    let c = clock::create_for_testing(s.ctx());
    let verified = ssu::verify_ssu(&storage, &owner_cap, &character, &auth, &registry, &c);
    assert!(witnesses::vssu_id(&verified) == storage_id, 0);
    // This adapter retains the existing advisory character-cap metadata.
    assert!(witnesses::vssu_owner(&verified) == character::owner_cap_id(&character), 1);
    network::register_ssu(internal::permit<NetworkKey>(), &mut dao, verified,
        network::new_vaulted(object::id(&owner_cap)), &req, s.ctx());
    assert!(network::is_ssu_registered(network::borrow<NetworkKey>(&dao), storage_id), 2);
    character.return_owner_cap(owner_cap, receipt);
    c.destroy_for_testing();
    proposal::consume_execution_request_for_testing(req);
    transfer::public_transfer(auth, OWNER);
    ts::return_shared(dao);
    ts::return_shared(registry);
    ts::return_shared(character);
    ts::return_shared(storage);
    s.end();
}
