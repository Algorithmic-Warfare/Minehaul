/**
 * Fictional demo records for the specimen page. Network, endpoint and job
 * names follow mockup/dist/app.js; nothing here is on chain. Times are fixed
 * against NOW so the page renders the same everywhere.
 */
export const NOW = Date.UTC(2026, 9, 21, 16, 0);
const HOUR = 3_600_000;
const at = (hours) => NOW + hours * HOUR;

export const NETWORKS = {
  AST: { tag: "AST", name: "Aster Collective" },
  MRD: { tag: "MRD", name: "Meridian Union" },
  ORG: { tag: "ORG", name: "Outer Rim Guild" },
};

const SSU = {
  "SSU-01": { ssu: "SSU-01", name: "Aster Prime", mode: "vaulted" },
  "SSU-02": { ssu: "SSU-02", name: "Halcyon Depot", mode: "vaulted" },
  "SSU-03": { ssu: "SSU-03", name: "Cinder Relay", mode: "leased", leaseEndsAt: at(9) },
  "SSU-04": { ssu: "SSU-04", name: "Meridian Outpost", mode: "vaulted" },
  "SSU-05": { ssu: "SSU-05", name: "Kepler Station", mode: "leased", leaseEndsAt: at(40) },
  "SSU-06": { ssu: "SSU-06", name: "Echo Anchorage", mode: "vaulted" },
  "SSU-07": { ssu: "SSU-07", name: "Vesper Terminal", mode: "vaulted" },
  "SSU-08": { ssu: "SSU-08", name: "Drift Exchange", mode: "leased", leaseEndsAt: at(9) },
};

const COLLECTION = { ore: "0x7a3e…c1f0", parts: "0x2b91…04d7", fuel: "0x9c0f…e83a" };

const line = (label, kind, asset, qty) => ({ label, collection: COLLECTION[kind], asset, qty });

const job = (id, net, src, dst, manifest, reward, haulHours, extra = {}) => ({
  id,
  network: NETWORKS[net],
  kind: "transfer",
  source: SSU[src],
  destination: SSU[dst],
  manifest,
  reward,
  rewardAsset: "CR",
  rewardToHaulerBps: 8500,
  minCollateralRatioBps: 5000,
  haulDurationMs: haulHours * HOUR,
  disputeWindowMs: 24 * HOUR,
  status: "open",
  listedAt: at(-4),
  listingExpiresAt: at(20),
  ...extra,
});

export const JOBS = [
  // Open board
  job("MH-0248", "AST", "SSU-01", "SSU-04", [line("Refined ore", "ore", 1101, 2400)], 19000, 8, { listedAt: at(-5), listingExpiresAt: at(19) }),
  job("MH-0247", "AST", "SSU-02", "SSU-01", [line("Fuel cells", "fuel", 2201, 800)], 11400, 6, { listedAt: at(-3), listingExpiresAt: at(21) }),
  job("MH-0245", "ORG", "SSU-06", "SSU-07", [line("Electronic parts", "parts", 3305, 320)], 8550, 4, { listedAt: at(-9), listingExpiresAt: at(3) }),
  job("MH-0243", "AST", "SSU-01", "SSU-02", [line("Carbon materials", "ore", 1140, 3200)], 9500, 6),
  job("MH-0241", "AST", "SSU-03", "SSU-01", [line("Fuel cells", "fuel", 2201, 450)], 6650, 4, { source: { ...SSU["SSU-03"], leaseEndsAt: at(60) } }),
  job("MH-0240", "MRD", "SSU-04", "SSU-05", [line("Carbon materials", "ore", 1140, 2800)], 12600, 10,
    { listedAt: at(-23.2), listingExpiresAt: at(0.8), risk: "Listing expires in 48m" }),
  job("MH-0238", "AST", "SSU-02", "SSU-03", [line("Refined ore", "ore", 1101, 2100)], 11550, 12,
    { risk: "SSU-03 lease ends before the haul deadline" }),
  job("MH-0237", "ORG", "SSU-06", "SSU-08", [line("Lens components", "parts", 3410, 160), line("Optical housings", "parts", 3411, 100)], 6240, 4,
    { destination: { ...SSU["SSU-08"], leaseEndsAt: at(70) } }),
  job("MH-0235", "AST", "SSU-01", "SSU-03", [line("Feldspar", "ore", 1003, 3600)], 12240, 12,
    { destination: { ...SSU["SSU-03"], leaseEndsAt: at(60) } }),
  job("MH-0230", "MRD", "SSU-05", "SSU-04", [line("Structural alloy", "parts", 3120, 1000), line("Fasteners", "parts", 3127, 400)], 18200, 10),
  job("MH-0229", "ORG", "SSU-07", "SSU-08", [line("Salvage components", "parts", 3502, 900)], 19800, 12,
    { risk: "SSU-08 lease ends before the haul deadline" }),

  // Live hauls
  job("MH-0244", "MRD", "SSU-05", "SSU-04", [line("Industrial tools", "parts", 3220, 640)], 14250, 10,
    { status: "claimed", mine: true, listedAt: at(-6), claimedAt: at(-2), collateral: 8000 }),
  job("MH-0239", "ORG", "SSU-08", "SSU-06", [line("Salvage components", "parts", 3502, 1200)], 7800, 8,
    { status: "claimed", listedAt: at(-5), claimedAt: at(-1), collateral: 4500, source: { ...SSU["SSU-08"], leaseEndsAt: at(30) } }),
  job("MH-0246", "MRD", "SSU-04", "SSU-05", [line("Structural alloy", "parts", 3120, 1200), line("Fasteners", "parts", 3127, 400)], 23750, 12,
    { status: "collected", mine: true, listedAt: at(-10), claimedAt: at(-7), collectedAt: at(-5), collateral: 13000 }),
  job("MH-0236", "MRD", "SSU-05", "SSU-04", [line("Fuel cells", "fuel", 2201, 1000)], 13000, 10,
    { status: "collected", listedAt: at(-12), claimedAt: at(-8.4), collectedAt: at(-6), collateral: 7000, risk: "Haul deadline in 1h 36m" }),
  job("MH-0242", "ORG", "SSU-07", "SSU-08", [line("Refined ore", "ore", 1101, 1900)], 17100, 8,
    { status: "delivered", mine: true, listedAt: at(-26), claimedAt: at(-20), collectedAt: at(-16), deliveredAt: at(-9.6), collateral: 9500,
      destination: { ...SSU["SSU-08"], leaseEndsAt: at(70) } }),
];

/** Ended jobs, for the lifecycle gallery. */
export const ENDED = [
  job("MH-0234", "AST", "SSU-02", "SSU-01", [line("Refined ore", "ore", 1101, 1500)], 13500, 8,
    { status: "settled", mine: true, listedAt: at(-60), claimedAt: at(-58), collectedAt: at(-55), deliveredAt: at(-50), settledAt: at(-26), collateral: 7000 }),
  job("MH-0233", "ORG", "SSU-06", "SSU-07", [line("Electronic parts", "parts", 3305, 400)], 9600, 6,
    { status: "disputed", exitFrom: "delivered", exitNote: "Opened by lister", listedAt: at(-40), claimedAt: at(-38), collectedAt: at(-35), deliveredAt: at(-30), collateral: 5000 }),
  job("MH-0228", "MRD", "SSU-04", "SSU-05", [line("Fuel cells", "fuel", 2201, 900)], 11700, 8,
    { status: "resolved", exitFrom: "delivered", exitNote: "Awarded to hauler", listedAt: at(-90), claimedAt: at(-88), collectedAt: at(-85), deliveredAt: at(-80), collateral: 6000 }),
  job("MH-0232", "MRD", "SSU-05", "SSU-04", [line("Feldspar", "ore", 1003, 2000)], 6000, 8,
    { status: "expired", exitFrom: "open", exitNote: "Unclaimed · refunded", listedAt: at(-50), listingExpiresAt: at(-26) }),
  job("MH-0231", "AST", "SSU-01", "SSU-02", [line("Carbon materials", "ore", 1140, 1200)], 4200, 6,
    { status: "cancelled", exitFrom: "open", exitNote: "By lister", listedAt: at(-30) }),
];
