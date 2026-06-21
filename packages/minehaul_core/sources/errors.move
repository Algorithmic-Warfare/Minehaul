/// Abort code constants for minehaul_core.
module minehaul_core::errors;

const ENotNetworkMember: u64        = 1;
const ENetworkPaused: u64           = 2;
const ESsuNotRegistered: u64        = 3;
const ESsuNetworkMismatch: u64      = 4;
const EGateNetworkMismatch: u64     = 5;
const EActionWrongStatus: u64       = 6;
const EActionExpired: u64           = 7;
const ENotClaimer: u64              = 8;
const ERouteHashMismatch: u64       = 9;
const EHopOutOfOrder: u64           = 10;
const EHopAlreadyRecorded: u64      = 11;
const EPermitExpired: u64           = 12;
const EPermitHaulerMismatch: u64    = 13;
const ECargoMismatch: u64           = 14;
const ECargoEmpty: u64              = 15;
const EInsufficientReward: u64      = 16;
const EInsufficientCollateral: u64  = 17;
const EAdapterRevoked: u64          = 18;
const EAdapterNotRegistered: u64    = 19;
const EAdapterNetworkMismatch: u64  = 20;
const EOwnershipModeMismatch: u64   = 21;
const ELeaseExpired: u64            = 22;
const ENotDisputeArbiter: u64       = 23;
const ERouteEmpty: u64              = 24;
const EUnauthorizedRouteMint: u64   = 25;
const EWrongDao: u64                = 26;
const ERouteTooLong: u64            = 27;
const ECargoLinesExceedMax: u64     = 28;
const EAlreadyRegistered: u64       = 29;
const ENotRegistered: u64           = 30;
const EEscrowNotEmpty: u64          = 31;

public fun not_network_member(): u64       { ENotNetworkMember }
public fun network_paused(): u64           { ENetworkPaused }
public fun ssu_not_registered(): u64       { ESsuNotRegistered }
public fun ssu_network_mismatch(): u64     { ESsuNetworkMismatch }
public fun gate_network_mismatch(): u64    { EGateNetworkMismatch }
public fun action_wrong_status(): u64      { EActionWrongStatus }
public fun action_expired(): u64           { EActionExpired }
public fun not_claimer(): u64              { ENotClaimer }
public fun route_hash_mismatch(): u64      { ERouteHashMismatch }
public fun hop_out_of_order(): u64         { EHopOutOfOrder }
public fun hop_already_recorded(): u64     { EHopAlreadyRecorded }
public fun permit_expired(): u64           { EPermitExpired }
public fun permit_hauler_mismatch(): u64   { EPermitHaulerMismatch }
public fun cargo_mismatch(): u64           { ECargoMismatch }
public fun cargo_empty(): u64              { ECargoEmpty }
public fun insufficient_reward(): u64      { EInsufficientReward }
public fun insufficient_collateral(): u64  { EInsufficientCollateral }
public fun adapter_revoked(): u64          { EAdapterRevoked }
public fun adapter_not_registered(): u64   { EAdapterNotRegistered }
public fun adapter_network_mismatch(): u64 { EAdapterNetworkMismatch }
public fun ownership_mode_mismatch(): u64  { EOwnershipModeMismatch }
public fun lease_expired(): u64            { ELeaseExpired }
public fun not_dispute_arbiter(): u64      { ENotDisputeArbiter }
public fun route_empty(): u64              { ERouteEmpty }
public fun unauthorized_route_mint(): u64  { EUnauthorizedRouteMint }
public fun wrong_dao(): u64                { EWrongDao }
public fun route_too_long(): u64           { ERouteTooLong }
public fun cargo_lines_exceed_max(): u64   { ECargoLinesExceedMax }
public fun already_registered(): u64       { EAlreadyRegistered }
public fun not_registered(): u64           { ENotRegistered }
public fun escrow_not_empty(): u64         { EEscrowNotEmpty }
