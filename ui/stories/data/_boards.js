/* Stacks configurations shared by Data/Stacks and the Pages stories. Not a story file. */
import { int } from "../_lib.js";
import { JOBS } from "../../demo/jobs.js";
import { NETWORK_DETAIL } from "../../demo/network.js";
import { rate, units } from "../../js/job.js";

export const RATE_BANDS = [
  { key: "bulk", label: "Bulk", code: "< 5 CR/u", range: [0, 5] },
  { key: "standard", label: "Standard", code: "5–12 CR/u", range: [5, 12] },
  { key: "priority", label: "Priority", code: "12–20 CR/u", range: [12, 20] },
  { key: "express", label: "Express", code: "≥ 20 CR/u", range: [20, Infinity] },
];

export const STAGES = [
  { key: "open", label: "Open", code: "reward" },
  { key: "claimed", label: "Claimed", code: "reward + collateral" },
  { key: "collected", label: "Collected", code: "reward + collateral" },
  { key: "delivered", label: "Dispute window", code: "until finalized" },
];

export const escrowOf = (j) => j.reward + (j.status === "open" ? 0 : j.collateral ?? 0);

/** The open board by reward rate: 1 square = `per` units of cargo. */
export function boardConfig({ items = JOBS.filter((j) => j.status === "open"), per = 100, perRow = 12, lens = 12, order = "metric", strip = true, ...rest } = {}) {
  return {
    title: "Open board · reward rate",
    subtitle: `Every square is ${int.format(per)} units of cargo and every job is one contiguous run, so a band split into many small jobs looks busy instead of thin.`,
    items,
    id: (j) => j.id,
    size: units,
    sizeUnit: "u",
    unit: { per, label: `${int.format(per)} u` },
    perRow,
    metric: rate,
    metricFormat: (v) => v.toFixed(2),
    groups: RATE_BANDS,
    lens: { value: lens, min: 0, max: 30, step: 0.5, label: "Floor", format: (v) => `${v.toFixed(1)} CR/u` },
    match: (_job, l, metric) => metric >= l,
    matchLabel: "Meets your floor",
    hazard: (j) => j.risk ?? null,
    hazardLabel: "Risk trait",
    strip: strip
      ? { domain: [0, 30], ticks: [0, 5, 10, 15, 20, 25, 30], tickFormat: (v) => v.toFixed(0), label: "Where each job sits · true scale (CR per unit) · bar height = cargo units" }
      : null,
    order,
    orderLabels: { metric: "Order · rate", size: "Order · size" },
    ...rest,
  };
}

/** Escrow held, grouped by lifecycle stage: 1 square = `per` CR. Matches are the viewer's hauls. */
export function escrowConfig({ items = JOBS, per = 2000, perRow = 10, ...rest } = {}) {
  return {
    title: "Escrow held by Minehaul",
    items,
    id: (j) => j.id,
    size: escrowOf,
    sizeUnit: "CR",
    sizeFormat: (v) => int.format(v),
    unit: { per, label: `${int.format(per)} CR` },
    perRow,
    metric: rate,
    groups: STAGES,
    groupOf: (j) => j.status,
    match: (j) => j.mine,
    matchLabel: "Your hauls",
    hazard: (j) => j.risk ?? null,
    hazardLabel: "Risk trait",
    orderLabels: { metric: "Order · rate", size: "Order · escrow" },
    ...rest,
  };
}

/** Cargo on the board by network: 1 square = `per` units. */
export function networkConfig({ items = JOBS, per = 100, ...rest } = {}) {
  return {
    title: "Cargo by network",
    subtitle: "Open and live jobs, grouped by the network that listed them.",
    items,
    id: (j) => j.id,
    size: units,
    sizeUnit: "u",
    unit: { per, label: `${int.format(per)} u` },
    perRow: 12,
    metric: rate,
    groups: NETWORK_DETAIL.map((n) => ({ key: n.tag, label: n.name, code: n.paused ? `${n.tag} · paused` : n.tag })),
    groupOf: (j) => j.network.tag,
    match: (j) => j.status !== "open",
    matchLabel: "In progress",
    hazard: (j) => j.risk ?? null,
    hazardLabel: "Risk trait",
    ...rest,
  };
}
