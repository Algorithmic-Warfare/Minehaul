/**
 * Fictional networks, endpoints, characters and protocol events for stories
 * and the specimen. Shapes follow minehaul_core (NetworkConfig, RegisteredSsu,
 * events.move). Nothing here is on chain.
 */
import { NOW } from "./jobs.js";

const HOUR = 3_600_000;
const at = (hours) => NOW + hours * HOUR;

export const CHARACTERS = {
  vex: { name: "Vex Harrow", address: "0x4f2a9c71e08b3d55a6c1f09e7d24b8a3c5e1d602" },
  ilse: { name: "Ilse Morrow", address: "0x91ab03fe5c7d2846b1e9a0c3d7f5e2b4a8c6d0f1" },
  oduya: { name: "Oduya Kest", address: "0x2c7e48b19af0d3c5e6b2a7f8d4c1e9b0a3f5d7c2" },
  ran: { name: "Ran Okafor", address: "0xd03f7a2b9c4e1f8a6b5d2c0e7f3a9b1c4d8e6f20" },
};

export const short = (hex, head = 6, tail = 4) => `${hex.slice(0, head)}…${hex.slice(-tail)}`;

export const NETWORK_DETAIL = [
  {
    tag: "AST",
    name: "Aster Collective",
    description: "Keeping the industrial heart of the frontier supplied.",
    id: "0x5e1c8a4f2b9d7e3c6a0f1b8d4e2c9a7f3b5d1e08",
    treasury: "0x8b3d1f6e9a2c4b7d0e5f8a1c3b6d9e2f4a7c0b15",
    paused: false,
    config: { minCollateralRatioBps: 5000, maxCargoLines: 8, disputeWindowMs: 24 * HOUR, openMarketplace: true, rewardAsset: "CR" },
    ssus: ["SSU-01", "SSU-02", "SSU-03"],
    adapters: [{ name: "Warehouse receipt v0", status: "test-only", id: "0x7c2e…91aa" }],
  },
  {
    tag: "MRD",
    name: "Meridian Union",
    description: "Connecting independent manufacturing and storage.",
    id: "0x3a9f2c7e1b5d8a4f6c0e9b2d7a1f5c3e8b4d6a29",
    treasury: "0x6d2a8f4c1e7b3d9a5f0c2e8b6d4a1f7c3e9b5d02",
    paused: false,
    config: { minCollateralRatioBps: 5000, maxCargoLines: 6, disputeWindowMs: 24 * HOUR, openMarketplace: false, rewardAsset: "CR" },
    ssus: ["SSU-04", "SSU-05"],
    adapters: [{ name: "Warehouse receipt v0", status: "test-only", id: "0x7c2e…91aa" }],
  },
  {
    tag: "ORG",
    name: "Outer Rim Guild",
    description: "Essential cargo for communities on the outer edge.",
    id: "0x9d4b1e7a3c8f2d6b0a5e9c1f4d8b2a7e3c6f0d14",
    treasury: "0x1f8c3a6e9d2b5f7a0c4e8d1b6a3f9c2e7d5b0a36",
    paused: true,
    pausedNote: "Paused by governance proposal #31 while SSU-08's lease is renewed.",
    config: { minCollateralRatioBps: 6000, maxCargoLines: 4, disputeWindowMs: 36 * HOUR, openMarketplace: true, rewardAsset: "CR" },
    ssus: ["SSU-06", "SSU-07", "SSU-08"],
    adapters: [
      { name: "Warehouse receipt v0", status: "test-only", id: "0x7c2e…91aa" },
      { name: "Manual attest (retired)", status: "revoked", id: "0x0b44…c3d9" },
    ],
  },
];

export const SSUS = {
  "SSU-01": { ssu: "SSU-01", name: "Aster Prime", mode: "vaulted", owner: CHARACTERS.vex, registeredAt: at(-900), live: true },
  "SSU-02": { ssu: "SSU-02", name: "Halcyon Depot", mode: "vaulted", owner: CHARACTERS.vex, registeredAt: at(-760), live: true },
  "SSU-03": { ssu: "SSU-03", name: "Cinder Relay", mode: "leased", owner: CHARACTERS.oduya, registeredAt: at(-300), leaseStartedAt: at(-300), leaseEndsAt: at(9) },
  "SSU-04": { ssu: "SSU-04", name: "Meridian Outpost", mode: "vaulted", owner: CHARACTERS.ilse, registeredAt: at(-1200), live: true },
  "SSU-05": { ssu: "SSU-05", name: "Kepler Station", mode: "leased", owner: CHARACTERS.ran, registeredAt: at(-200), leaseStartedAt: at(-200), leaseEndsAt: at(40) },
  "SSU-06": { ssu: "SSU-06", name: "Echo Anchorage", mode: "vaulted", owner: CHARACTERS.oduya, registeredAt: at(-500) },
  "SSU-07": { ssu: "SSU-07", name: "Vesper Terminal", mode: "vaulted", owner: CHARACTERS.ilse, registeredAt: at(-480) },
  "SSU-08": { ssu: "SSU-08", name: "Drift Exchange", mode: "leased", owner: CHARACTERS.ran, registeredAt: at(-150), leaseStartedAt: at(-150), leaseEndsAt: at(9), off: true },
};

/** Protocol events, newest first (minehaul_core::events) */
export const EVENTS = [
  { event: "delivered", name: "ActionDelivered", job: "MH-0242", actor: CHARACTERS.ilse, at: at(-0.2), tx: "0x8e1f…42ab", note: "Dispute window opens · 24h", fresh: true },
  { event: "claimed", name: "ActionClaimed", job: "MH-0239", actor: CHARACTERS.ran, at: at(-1), tx: "0x3c7d…09fe", note: "4,500 CR collateral" },
  { event: "listed", name: "ActionListed", job: "MH-0229", actor: CHARACTERS.oduya, at: at(-1.5), tx: "0xa41b…7c30", note: "19,800 CR reward · 900 u" },
  { event: "claimed", name: "ActionClaimed", job: "MH-0244", actor: CHARACTERS.vex, at: at(-2), tx: "0x5f02…e1d8", note: "8,000 CR collateral" },
  { event: "disputed", name: "ActionDisputed", job: "MH-0233", actor: CHARACTERS.oduya, at: at(-3), tx: "0x91e6…b5a2", note: "Opened by lister" },
  { event: "governance", name: "NetworkConfigured", job: "ORG", actor: CHARACTERS.ilse, at: at(-4), tx: "0x0d8a…63cf", note: "Paused · proposal #31" },
  { event: "settled", name: "ActionSettled", job: "MH-0234", actor: CHARACTERS.vex, at: at(-26), tx: "0x7b3e…a90d", note: "11,475 CR to hauler · 2,025 CR to treasury" },
  { event: "expired", name: "ActionExpired", job: "MH-0232", actor: null, at: at(-26), tx: "0x2a6f…d417", note: "Unclaimed · reward and cargo refunded" },
  { event: "revoked", name: "AdapterRevoked", job: "ORG", actor: CHARACTERS.ilse, at: at(-40), tx: "0xc5d1…8e2b", note: "Manual attest (retired)" },
];

export function ago(ms, now = NOW) {
  const m = Math.round((now - ms) / 60_000);
  if (m < 60) return `${m}m ago`;
  const h = Math.round(m / 60);
  return h < 48 ? `${h}h ago` : `${Math.round(h / 24)}d ago`;
}
