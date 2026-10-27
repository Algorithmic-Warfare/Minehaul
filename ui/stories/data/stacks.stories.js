import { describe, int } from "../_lib.js";
import { renderStacks } from "../../js/stacks.js";
import { renderJobCard } from "../../js/job.js";
import { JOBS, NOW } from "../../demo/jobs.js";
import { boardConfig, escrowConfig, networkConfig, RATE_BANDS } from "./_boards.js";

/** A fresh element per render: renderStacks owns its root. */
function mount(config, { selectedCard = false, style = "" } = {}) {
  const wrap = document.createElement("div");
  wrap.style.cssText = `display: grid; gap: var(--mh-space-6); ${style}`;
  const host = document.createElement("div");
  wrap.append(host);
  let card;
  if (selectedCard) {
    card = document.createElement("div");
    card.setAttribute("aria-live", "polite");
    wrap.append(card);
  }
  const show = (job) => { if (card) card.innerHTML = renderJobCard(job, { now: NOW }); };
  renderStacks(host, { ...config, onSelect: show });
  if (card && config.selected) show(JOBS.find((j) => j.id === config.selected));
  return wrap;
}

export default {
  title: "Data/Stacks",
  parameters: describe(
    "Countable stacks: every square is a fixed quantity and every item is one contiguous run, so a band made of many small jobs looks busy instead of thin. Columns are bands of a metric, or any grouping via `groupOf`. A movable lens marks what meets a threshold, hatching marks risk, and an optional strip places each item on a true scale.\n\n```js\nimport { renderStacks } from \"@minehaul/ui/js/stacks.js\";\nconst board = renderStacks(el, { items, id, size, unit, metric, groups, lens, match, hazard, strip, onSelect });\nboard.select(\"MH-0246\");\n```\n\nThe full option list is in the README under *Stacks*. Grid squares and strip bars are `aria-hidden`; every item is also a button row, which is the accessible path for selection.",
  ),
};

export const Board = {
  name: "Board by reward rate",
  parameters: describe(null, "The open board. Drag the floor to see which jobs clear your rate; click a square, row or bar to open the job card below."),
  argTypes: {
    per: { name: "unit (u per square)", control: { type: "select" }, options: [50, 100, 200] },
    perRow: { control: { type: "range", min: 6, max: 16, step: 1 } },
    lens: { name: "floor (CR/u)", control: { type: "range", min: 0, max: 30, step: 0.5 } },
    order: { control: "inline-radio", options: ["metric", "size"] },
    strip: { control: "boolean" },
  },
  args: { per: 100, perRow: 12, lens: 12, order: "metric", strip: true },
  render: (args) => mount(boardConfig({ ...args, selected: "MH-0230" }), { selectedCard: true }),
};

export const Escrow = {
  name: "Escrow by stage",
  parameters: describe(
    null,
    "The same component grouped by lifecycle stage with `groupOf: (j) => j.status`. A square is 2,000 CR in escrow: the reward, plus collateral once claimed. The viewer's own hauls take the brand colour through one `--mh-data-match` override on the container.",
  ),
  argTypes: { per: { name: "CR per square", control: "select", options: [1000, 2000, 5000] } },
  args: { per: 2000 },
  render: ({ per }) => mount(escrowConfig({ per, selected: "MH-0246" }), { style: "--mh-data-match: var(--mh-brand-fill)" }),
};

export const ByNetwork = {
  name: "By network",
  parameters: describe(null, "Grouped by listing network. Matches here are jobs already in progress, so an operator can see how much of each network's board is moving."),
  render: () => mount(networkConfig()),
};

export const EmptyBand = {
  name: "Empty band",
  parameters: describe(
    null,
    "Columns keep their height when a band has no items, so the eye can compare bands across the row. The list says so in words. Here Express has no jobs because only low-rate listings are on the board.",
  ),
  render: () => {
    const items = JOBS.filter((j) => j.status === "open" && j.reward / j.manifest.reduce((s, l) => s + l.qty, 0) < 12);
    return mount(boardConfig({ items, strip: false, subtitle: `${items.length} jobs under 12 CR/u. The ${RATE_BANDS.slice(2).map((b) => b.label).join(" and ")} bands are empty.` }));
  },
};

export const Compact = {
  name: "Compact (no strip, no lens)",
  parameters: describe(null, "Omit `lens` and `strip` for a small summary, for example in a side panel. Squares follow the chamfer token, so switch the toolbar to Square for AWAR's flat look."),
  render: () => {
    const items = JOBS.filter((j) => j.status === "open");
    const config = boardConfig({ items, strip: false, per: 200, perRow: 8, title: "Board summary", subtitle: `${items.length} open jobs, ${int.format(items.reduce((s, j) => s + j.reward, 0))} CR in rewards.` });
    delete config.lens;
    config.match = undefined;
    return mount(config, { style: "max-width: 820px" });
  },
};
