import { render, describe, icon, int } from "../_lib.js";
import { JOBS } from "../../demo/jobs.js";
import { rate, units } from "../../js/job.js";

export default {
  title: "Effects/Decorations",
  parameters: describe(
    "Effects and decorations from `components/decor.css`. Plates clip their own pseudo-elements, so put scan, brackets and glow on a wrapper around a plate. All motion stops under `prefers-reduced-motion`; use one effect per view so it stays a signal, not noise.",
  ),
};

const statPlate = (label, value, unit, note) => `<div class="mh-plate mh-stat">
  <span class="mh-label">${label}</span>
  <b class="mh-stat__value">${value}<small>${unit}</small></b>
  ${note ? `<span class="mh-stat__delta">${note}</span>` : ""}
</div>`;

/** Re-mounts the first child of `host` so its entrance animation plays again. */
const replay = (host) => {
  const child = host.firstElementChild;
  const clone = child.cloneNode(true);
  child.replaceWith(clone);
};

export const ScanLine = {
  name: "Scan line",
  parameters: describe(null, "AWAR's signature: a slow signal line sweeping down a panel. `.mh-scan--trail` adds a faint wake. Set `--mh-scan-duration` to change the speed."),
  render: () =>
    render(`<div class="sb-split">
      <div class="mh-scan" style="--mh-scan-duration: 6s">
        <div class="mh-plate mh-plate--lg" style="padding: 24px; min-height: 220px; display:grid; align-content: end; gap: 8px; --mh-plate-fill: var(--mh-bg)">
          <span class="mh-label">Scanning board</span>
          <b class="mh-num" style="font-size: var(--mh-text-2xl)">11 open jobs</b>
          <span class="mh-muted" style="font-size: var(--mh-text-sm)">Aster Collective · Meridian Union · Outer Rim Guild</span>
        </div>
      </div>
      <div class="mh-scan mh-scan--trail" style="--mh-scan-duration: 9s">
        <div class="mh-plate mh-plate--lg mh-gridfield" style="padding: 24px; min-height: 220px; display:grid; align-content: end; gap: 8px">
          <span class="mh-label">.mh-scan--trail</span>
          <b class="mh-display" style="font-size: var(--mh-text-xl)">Endpoint survey</b>
          <span class="mh-muted" style="font-size: var(--mh-text-sm)">8 SSUs registered · 3 leased</span>
        </div>
      </div>
    </div>`),
};

export const Brackets = {
  parameters: describe(null, "Corner brackets frame one thing worth attention. `--lock` starts loose and tightens on hover or focus; `--muted` uses the trim colour."),
  render: () =>
    render(`<div class="sb-grid" style="--sb-min: 220px; gap: 36px; padding: 16px">
      <div class="mh-brackets">${statPlate("Escrow held", "253,630", "CR", "3 networks")}</div>
      <div class="mh-brackets mh-brackets--lock" tabindex="0" aria-label="Selected job, hover or focus to lock on">${statPlate("Selected", "MH-0246", "", "Hover or focus to lock on")}</div>
      <div class="mh-brackets mh-brackets--muted">${statPlate("Dispute window", "14h 24m", "left", "MH-0242")}</div>
    </div>`),
};

export const GridField = {
  name: "Grid field",
  parameters: describe(null, "A coordinate grid with a major line every five cells, for empty canvases and schematic panels. `--drift` moves it slowly. Set `--_cell` to change the pitch."),
  render: () =>
    render(`<div class="sb-split">
      <div class="mh-gridfield" style="min-height: 220px; border: 1px solid var(--mh-line); display:grid; place-items:center">
        <span class="mh-label">.mh-gridfield</span>
      </div>
      <div class="mh-gridfield mh-gridfield--drift" style="--_cell: 16px; min-height: 220px; border: 1px solid var(--mh-line); display:grid; place-items:center">
        <span class="mh-label">.mh-gridfield--drift · 16px cells</span>
      </div>
    </div>`),
};

export const Ticker = {
  parameters: describe(null, "A rolling strip of open jobs. The content is rendered twice so the loop is seamless, and it pauses on hover or focus."),
  render: () => {
    const items = JOBS.filter((j) => j.status === "open")
      .map((j) => `<span class="mh-ticker__item"><b>${j.id}</b><span class="mh-muted">${j.network.tag}</span><span>${rate(j).toFixed(2)} CR/u</span><span class="mh-muted">${int.format(j.reward)} CR · ${int.format(units(j))} u</span></span>`)
      .join("");
    return render(`<div class="mh-ticker" tabindex="0" aria-label="Open jobs ticker, paused while focused">
      <div class="mh-ticker__track"><div style="display:flex">${items}</div><div style="display:flex" aria-hidden="true">${items}</div></div>
    </div>`);
  },
};

export const Rule = {
  parameters: describe(null, "A divider with ruler ticks. Give it a label, leave it empty for a plain ruler, or use `--start` to push the label left."),
  render: () =>
    render(`<div class="sb-stack">
      <div class="mh-rule">Open board</div>
      <div class="mh-rule mh-rule--start">Live hauls · 5</div>
      <div class="mh-rule"></div>
    </div>`),
};

export const Dither = {
  parameters: describe(null, "A cell-checker fill for empty regions and artwork. `--sparse` doubles the pitch; `--accent` tints it with the signal colour."),
  render: () =>
    render(`<div class="sb-grid" style="--sb-min: 200px">
      <div class="mh-dither" style="min-height: 140px; border: 1px solid var(--mh-line); display:grid; place-items:center"><span class="mh-label" style="background: var(--mh-bg); padding: 4px 8px">Default</span></div>
      <div class="mh-dither mh-dither--sparse" style="min-height: 140px; border: 1px solid var(--mh-line); display:grid; place-items:center"><span class="mh-label" style="background: var(--mh-bg); padding: 4px 8px">--sparse</span></div>
      <div class="mh-dither mh-dither--accent" style="min-height: 140px; border: 1px solid var(--mh-line); display:grid; place-items:center"><span class="mh-label" style="background: var(--mh-bg); padding: 4px 8px">--accent</span></div>
      <div class="mh-dither mh-dither--sparse" style="min-height: 140px; border: 1px dashed var(--mh-trim); display:grid; place-items:center; text-align:center; padding: 12px">
        <span style="background: var(--mh-bg); padding: 8px 10px; font-size: var(--mh-text-xs)">${icon("cargo")} No cargo in this band</span>
      </div>
    </div>`),
};

export const Crosshair = {
  parameters: describe(null, "A target mark with an optional coordinate label from `data-coord`. Use it to pin a point on a schematic, not as a bullet."),
  render: () =>
    render(`<div class="mh-gridfield" style="position: relative; height: 220px; overflow: hidden; border: 1px solid var(--mh-line)">
      <span class="mh-crosshair" data-coord="SSU-04 · Meridian Outpost" style="position:absolute; left: 22%; top: 30%"></span>
      <span class="mh-crosshair" data-coord="SSU-05 · Kepler Station" style="position:absolute; left: 58%; top: 62%; --_c: var(--mh-warn)"></span>
    </div>`),
};

export const Glow = {
  parameters: describe(null, "Signal glow, reserved for active orange indicators. `--pulse` breathes slowly for a live state."),
  render: () =>
    render(`<div class="sb-row" style="gap: 28px">
      <span class="mh-glow" style="display:inline-flex"><span class="mh-lamp" data-lit></span></span>
      <span class="mh-glow mh-glow--pulse" style="display:inline-flex; align-items:center; gap: 8px; font-size: var(--mh-text-sm)"><span class="mh-lamp" data-lit></span> Live on Aster Collective</span>
      <span class="mh-glow mh-glow--pulse" style="display:inline-flex"><button type="button" class="mh-plate mh-button"><span class="mh-button__label">Deliver to SSU-05</span></button></span>
    </div>`),
};

export const Reveal = {
  parameters: describe(null, "Staggered entrance. Put `.mh-reveal` on the parent and `--i` on each child to set its order."),
  render: () => {
    const el = render(`<div class="sb-stack">
      <div><ol class="mh-reveal" style="list-style:none; margin:0; padding:0; display:grid; gap: 8px; max-width: 520px">
        ${JOBS.slice(0, 6)
          .map((j, i) => `<li class="mh-plate" style="--i: ${i}; padding: 10px 14px; display:flex; justify-content: space-between; gap: 12px; font-size: var(--mh-text-sm)"><b>${j.id}</b><span class="mh-muted">${j.source.ssu} → ${j.destination.ssu}</span><span class="mh-num">${int.format(j.reward)} CR</span></li>`)
          .join("")}
      </ol></div>
      <div><button type="button" class="mh-plate mh-button mh-button--secondary mh-button--sm" data-replay><span class="mh-button__label">${icon("refresh")} Replay</span></button></div>
    </div>`);
    el.querySelector("[data-replay]").addEventListener("click", () => replay(el.querySelector(".sb-stack > div")));
    return el;
  },
};

export const Draw = {
  parameters: describe(null, "A plate whose keyline draws round once, for a newly created or just-confirmed object."),
  render: () => {
    const el = render(`<div class="sb-stack">
      <div><div class="mh-plate mh-plate--lg mh-draw" style="padding: 24px; max-width: 420px; display:grid; gap: 6px">
        <span class="mh-label">Listed just now</span>
        <b class="mh-display" style="font-size: var(--mh-text-xl)">MH-0249 · Fuel cells</b>
        <span class="mh-muted" style="font-size: var(--mh-text-sm)">SSU-02 Halcyon Depot → SSU-04 Meridian Outpost</span>
      </div></div>
      <div><button type="button" class="mh-plate mh-button mh-button--secondary mh-button--sm" data-replay><span class="mh-button__label">${icon("refresh")} Replay</span></button></div>
    </div>`);
    el.querySelector("[data-replay]").addEventListener("click", () => replay(el.querySelector(".sb-stack > div")));
    return el;
  },
};

export const SignalField = {
  name: "Signal field",
  parameters: { layout: "fullscreen", ...describe(null, "A composed AWAR-style hero: grid field, scan line, brackets, crosshair, the brand mark and display type. One expressive moment per page, everything else flat.") },
  render: () =>
    render(`<div class="mh-scan mh-scan--trail" style="--mh-scan-duration: 8s">
      <section class="mh-gridfield" style="position: relative; min-height: 420px; padding: 48px max(24px, 5vw); display:grid; align-content: end; gap: 20px">
        <span class="mh-crosshair" data-coord="47.21 · −3.08" style="position:absolute; right: 12%; top: 18%"></span>
        <span class="mh-crosshair" data-coord="SSU-04" style="position:absolute; right: 30%; top: 46%; --_c: var(--mh-fg)"></span>
        <span class="mh-mark mh-mark--lg" aria-hidden="true"><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i></span>
        <span class="mh-label" style="color: var(--mh-accent-text)">Algorithmic Warfare · logistics</span>
        <h1 class="mh-display" style="margin:0; font-size: clamp(2.4rem, 1.6rem + 4vw, 5rem); max-width: 14ch">Move cargo between registered endpoints</h1>
        <div class="sb-row" style="gap: 28px">
          <div class="mh-brackets mh-brackets--lock" tabindex="0" style="padding: 4px 8px" aria-label="Open jobs">
            <span class="mh-label">Open jobs</span><br><b class="mh-num" style="font-size: var(--mh-text-2xl)">11</b>
          </div>
          <button type="button" class="mh-plate mh-button mh-button--lg"><span class="mh-button__label">Open the board ${icon("arrow-right")}</span></button>
        </div>
      </section>
    </div>`),
};
