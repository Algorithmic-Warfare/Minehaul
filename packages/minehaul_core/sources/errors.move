/// Abort code constants for minehaul_core.
module minehaul_core::errors;

const ENotNetworkMember: u64        = 1;
const ENetworkPaused: u64           = 2;
const ESsuNotRegistered: u64        = 3;
const ESsuNetworkMismatch: u64      = 4;
const EActionWrongStatus: u64       = 6;
const EActionExpired: u64           = 7;
const ENotClaimer: u64              = 8;
const ECargoMismatch: u64           = 14;
const ECargoEmpty: u64              = 15;
const EInsufficientReward: u64      = 16;
const EInsufficientCollateral: u64  = 17;
const EAdapterRevoked: u64          = 18;
const EAdapterNotRegistered: u64    = 19;
const EAdapterNetworkMismatch: u64  = 20;
const ELeaseExpired: u64            = 22;
const ENotDisputeArbiter: u64       = 23;
const EWrongDao: u64                = 26;
const ECargoLinesExceedMax: u64     = 28;
const EAlreadyRegistered: u64       = 29;
const ENotRegistered: u64           = 30;
const EEscrowNotEmpty: u64          = 31;
const EInvalidBps: u64              = 39;
const EWrongRewardAsset: u64        = 40;
const EWrongCollateralAsset: u64    = 41;
const ESameEndpoints: u64           = 42;
const EInvalidRuling: u64           = 43;
const ECollateralAlreadyPosted: u64 = 44;

public fun not_network_member(): u64       { ENotNetworkMember }
public fun network_paused(): u64           { ENetworkPaused }
public fun ssu_not_registered(): u64       { ESsuNotRegistered }
public fun ssu_network_mismatch(): u64     { ESsuNetworkMismatch }
public fun action_wrong_status(): u64      { EActionWrongStatus }
public fun action_expired(): u64           { EActionExpired }
public fun not_claimer(): u64              { ENotClaimer }
public fun cargo_mismatch(): u64           { ECargoMismatch }
public fun cargo_empty(): u64              { ECargoEmpty }
public fun insufficient_reward(): u64      { EInsufficientReward }
public fun insufficient_collateral(): u64  { EInsufficientCollateral }
public fun adapter_revoked(): u64          { EAdapterRevoked }
public fun adapter_not_registered(): u64   { EAdapterNotRegistered }
public fun adapter_network_mismatch(): u64 { EAdapterNetworkMismatch }
public fun lease_expired(): u64            { ELeaseExpired }
public fun not_dispute_arbiter(): u64      { ENotDisputeArbiter }
public fun wrong_dao(): u64                { EWrongDao }
public fun cargo_lines_exceed_max(): u64   { ECargoLinesExceedMax }
public fun already_registered(): u64       { EAlreadyRegistered }
public fun not_registered(): u64           { ENotRegistered }
public fun escrow_not_empty(): u64         { EEscrowNotEmpty }
public fun invalid_bps(): u64              { EInvalidBps }
public fun wrong_reward_asset(): u64       { EWrongRewardAsset }
public fun wrong_collateral_asset(): u64   { EWrongCollateralAsset }
public fun same_endpoints(): u64           { ESameEndpoints }
public fun invalid_ruling(): u64           { EInvalidRuling }
public fun collateral_already_posted(): u64 { ECollateralAlreadyPosted }

public fun invalid_config(): u64 { 32 }
public fun network_key_mismatch(): u64 { 33 }
public fun unsupported_action(): u64 { 34 }
public fun delivery_mismatch(): u64 { 35 }
public fun dispute_window_closed(): u64 { 36 }
public fun settlement_too_early(): u64 { 37 }
public fun invalid_deadline(): u64 { 38 }
