import { render, icon, describe, int } from "../_lib.js";
import { minCollateral } from "../../js/job.js";
import { JOBS } from "../../demo/jobs.js";

const job0248 = JOBS.find((j) => j.id === "MH-0248");
const minimum = minCollateral(job0248);

let n = 0;
const uid = (p) => `${p}-${++n}`;

export default {
  title: "Inputs",
  parameters: describe(
    "Form controls in the plate language. Text inputs sit in an octagon `.mh-field` that thickens its keyline on focus and hatches when disabled. " +
      "Checkboxes, radios and toggles are native inputs restyled with `appearance: none`, so they keep keyboard and form behaviour. " +
      "Radios use a diamond cell: circles are reserved for network nodes.",
  ),
  render: () => render(""),
};

export const Field = {
  args: { placeholder: "Search jobs, SSUs, cargo", value: "", prefix: "", disabled: false },
  argTypes: {
    placeholder: { control: "text" },
    value: { control: "text" },
    prefix: { control: "text" },
    disabled: { control: "boolean" },
  },
  render: ({ placeholder, value, prefix, disabled }) => {
    const id = uid("field");
    return render(`<div class="sb-stack" style="max-width: 460px">
      <div>
        <label class="mh-label sb-label" for="${id}">Playground</label>
        <label class="mh-plate mh-field">${prefix ? `<span class="mh-field__prefix">${prefix}</span>` : ""}<input id="${id}" placeholder="${placeholder}" value="${value}"${disabled ? " disabled" : ""}></label>
      </div>
      <div>
        <span class="mh-label sb-label">Search with shortcut</span>
        <label class="mh-plate mh-field"><span class="mh-field__prefix">${icon("search")}</span><input type="search" placeholder="Search jobs" aria-label="Search jobs" aria-keyshortcuts="/"><span class="mh-kbd" aria-hidden="true">/</span></label>
      </div>
      <div>
        <span class="mh-label sb-label">Prefix and suffix</span>
        <label class="mh-plate mh-field"><span class="mh-field__prefix">CR</span><input inputmode="numeric" placeholder="Minimum reward" aria-label="Minimum reward" value="12,000"><span class="mh-field__suffix">reward</span></label>
      </div>
      <div>
        <span class="mh-label sb-label">Disabled</span>
        <label class="mh-plate mh-field"><span class="mh-field__prefix">SSU</span><input aria-label="Destination SSU" value="SSU-05" disabled></label>
        <p class="sb-caption">Destination is fixed at listing, so it is shown but can't be edited.</p>
      </div>
    </div>`);
  },
};

export const Select = {
  render: () => {
    const a = uid("sort");
    const b = uid("net");
    return render(`<div class="sb-row" style="align-items:end">
      <div>
        <label class="mh-label sb-label" for="${a}">Sort</label>
        <span class="mh-plate mh-field mh-select" style="min-width: 220px"><select id="${a}">
          <option>Newest</option><option>Reward</option><option selected>Rate (CR/u)</option><option>Collateral</option>
        </select></span>
      </div>
      <div>
        <label class="mh-label sb-label" for="${b}">Network</label>
        <span class="mh-plate mh-field mh-select" style="min-width: 240px"><select id="${b}">
          <option>All networks</option><option>AST · Aster Collective</option><option>MRD · Meridian Union</option><option>ORG · Outer Rim Guild (paused)</option>
        </select></span>
      </div>
    </div>`);
  },
};

export const Stepper = {
  render: () => {
    const id = uid("collateral");
    const el = render(`<div class="sb-stack" style="max-width: 360px">
      <div>
        <label class="mh-label sb-label" for="${id}">Collateral for MH-0248</label>
        <div class="mh-plate mh-field mh-stepper" data-mh-stepper>
          <span class="mh-field__prefix">CR</span>
          <input id="${id}" type="number" min="${minimum}" step="500" value="${minimum}" aria-describedby="${id}-hint">
          <button type="button" class="mh-plate mh-iconbtn" data-step="-1" aria-label="Decrease by 500 CR">${icon("minus")}</button>
          <button type="button" class="mh-plate mh-iconbtn" data-step="1" aria-label="Increase by 500 CR">${icon("plus")}</button>
        </div>
        <p class="sb-caption" id="${id}-hint">Minimum ${int.format(minimum)} CR: 50% of the 19,000 CR reward, rounded up. Collateral is posted in the reward asset and is not a valuation of the cargo.</p>
      </div>
    </div>`);
    return el;
  },
  parameters: describe(null, "`data-mh-stepper` wires the − and + buttons to the input's `step`, `min` and `max`, and fires `input` and `change`."),
};

export const Checkbox = {
  render: () => {
    const el = render(`<fieldset style="border:0;padding:0;margin:0" class="sb-stack">
      <legend class="mh-label sb-label">Board filters</legend>
      <label class="mh-check"><input type="checkbox" checked> Only claimable by me</label>
      <label class="mh-check"><input type="checkbox"> <span>Hide leased endpoints<small>Leased SSUs can leave the network when the lease ends.</small></span></label>
      <label class="mh-check"><input type="checkbox" data-indeterminate> All networks</label>
      <label class="mh-check"><input type="checkbox" disabled> Include paused networks</label>
    </fieldset>`);
    el.querySelector("[data-indeterminate]").indeterminate = true;
    return el;
  },
};

export const Radio = {
  render: () => {
    const name = uid("order");
    return render(`<fieldset style="border:0;padding:0;margin:0" class="sb-stack">
      <legend class="mh-label sb-label">Sort the board by</legend>
      <label class="mh-check"><input type="radio" name="${name}" checked> Reward rate (CR per unit)</label>
      <label class="mh-check"><input type="radio" name="${name}"> Total reward</label>
      <label class="mh-check"><input type="radio" name="${name}"> Listing expiry</label>
      <label class="mh-check"><input type="radio" name="${name}" disabled> Distance (not tracked: Minehaul makes no travel-path claim)</label>
    </fieldset>`);
  },
};

export const Toggle = {
  render: () =>
    render(`<div class="sb-stack">
      <label class="mh-toggle"><input type="checkbox" role="switch" checked> Auto-finalize when the dispute window closes</label>
      <label class="mh-toggle"><input type="checkbox" role="switch"> Notify me when a job meets my floor</label>
      <label class="mh-toggle"><input type="checkbox" role="switch" disabled> Accept open-marketplace jobs (network policy)</label>
    </div>`),
  parameters: describe(null, "Native checkboxes with `role=\"switch\"`, for settings that apply immediately."),
};

export const Range = {
  render: () => {
    const id = uid("floor");
    const el = render(`<div class="sb-stack" style="max-width: 420px">
      <div class="sb-row" style="justify-content: space-between">
        <label class="mh-label" for="${id}">Rate floor</label>
        <output class="mh-num" for="${id}" style="color: var(--mh-accent-text); font-weight: 700">12.0 CR/u</output>
      </div>
      <input id="${id}" type="range" class="mh-range" min="0" max="30" step="0.5" value="12" style="--mh-range-cells: 30">
      <div class="sb-row mh-num mh-muted" style="justify-content: space-between; font-size: var(--mh-text-2xs)"><span>0</span><span>15</span><span>30</span></div>
    </div>`);
    const input = el.querySelector("input");
    input.addEventListener("input", () => (el.querySelector("output").textContent = `${Number(input.value).toFixed(1)} CR/u`));
    return el;
  },
  parameters: describe(null, "`--mh-range-cells` sets how many cells the track is drawn with; one cell per CR/u here."),
};

export const FilterBar = {
  name: "Filter bar",
  render: () => {
    const s = uid("q");
    const sort = uid("sort");
    const floor = uid("floor");
    const el = render(`<div class="mh-plate mh-plate--lg" style="--mh-plate-fill: var(--mh-bg); padding: var(--mh-space-4); display: flex; flex-wrap: wrap; gap: var(--mh-space-3) var(--mh-space-5); align-items: end" role="search" aria-label="Filter the job board">
      <div style="flex: 1 1 240px; min-width: 0">
        <label class="mh-label sb-label" for="${s}">Search</label>
        <label class="mh-plate mh-field"><span class="mh-field__prefix">${icon("search")}</span><input id="${s}" type="search" placeholder="Job, SSU or cargo"><span class="mh-kbd" aria-hidden="true">/</span></label>
      </div>
      <div>
        <span class="mh-label sb-label" id="${s}-net">Network</span>
        <div class="mh-seg" role="group" aria-labelledby="${s}-net" data-seg>
          <button type="button" aria-pressed="true">All</button><button type="button" aria-pressed="false">AST</button><button type="button" aria-pressed="false">MRD</button><button type="button" aria-pressed="false">ORG</button>
        </div>
      </div>
      <div>
        <label class="mh-label sb-label" for="${sort}">Sort</label>
        <span class="mh-plate mh-field mh-select" style="min-height: 36px; min-width: 170px"><select id="${sort}" style="font-size: var(--mh-text-sm); padding: 4px 2px"><option>Rate</option><option>Reward</option><option>Newest</option><option>Collateral</option></select></span>
      </div>
      <div style="flex: 0 1 220px">
        <div class="sb-row" style="justify-content: space-between"><label class="mh-label" for="${floor}">Floor</label><output class="mh-num" for="${floor}" style="font-size: var(--mh-text-xs); color: var(--mh-accent-text)">12.0 CR/u</output></div>
        <input id="${floor}" type="range" class="mh-range" min="0" max="30" step="0.5" value="12" style="--mh-range-cells: 15">
      </div>
      <label class="mh-toggle" style="min-height: 36px"><input type="checkbox" role="switch"> Hide risky</label>
    </div>`);
    const input = el.querySelector(`#${floor}`);
    input.addEventListener("input", () => (el.querySelector("output").textContent = `${Number(input.value).toFixed(1)} CR/u`));
    el.addEventListener("click", (e) => {
      const b = e.target.closest("[data-seg] button");
      if (b) for (const x of b.parentElement.children) x.setAttribute("aria-pressed", String(x === b));
    });
    return el;
  },
  parameters: { layout: "padded", ...describe(null, "A job-board toolbar composed from field, segmented control, select, range and toggle.") },
};
