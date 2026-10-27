import { render, describe } from "../_lib.js";

const LADDER = [1, 2, 3, 4, 5, 6, 7, 8];
const CUTS = [
  ["--mh-cut-xs", "4px", "Small octagon corners, tags"],
  ["--mh-cut-sm", "8px", "Endpoints, icon buttons"],
  ["--mh-cut-md", "14px", "Default plate, buttons"],
  ["--mh-cut-lg", "22px", "Job cards, panels"],
];

export default {
  title: "Foundations/Space & shape",
  parameters: describe(
    "AWAR's 4px spacing ladder and the chamfer tokens. Every chamfer is multiplied by `--mh-cut-scale`; at `0` plates go square, AWAR's native look.",
  ),
};

export const Spacing = {
  render: () =>
    render(`<div class="sb-stack" style="gap: 10px">${LADDER.map(
      (n) => `<div style="display:grid; grid-template-columns: 9rem 4rem minmax(0, 1fr); gap: 12px; align-items: center">
        <code style="font: var(--mh-text-xs) / 1 var(--mh-font-mono); color: var(--mh-accent-text)">--mh-space-${n}</code>
        <span class="mh-num mh-muted" style="font-size: var(--mh-text-xs)" data-space="${n}"></span>
        <i style="display:block; height: 12px; width: var(--mh-space-${n}); background: var(--mh-accent)"></i>
      </div>`,
    ).join("")}</div>
    <p class="sb-caption" style="margin-top: 16px">Values: 4, 8, 12, 16, 24, 32, 48, 64 px. Lay out sibling groups with <code>gap</code> from this ladder.</p>`),
  play: ({ canvasElement }) => {
    for (const el of canvasElement.querySelectorAll("[data-space]")) {
      el.textContent = getComputedStyle(document.documentElement).getPropertyValue(`--mh-space-${el.dataset.space}`).trim();
    }
  },
};

export const Cuts = {
  parameters: describe(null, "The four chamfer depths, each on a plate cut at all four corners."),
  render: () =>
    render(`<div class="sb-grid" style="--sb-min: 180px">${CUTS.map(
      ([token, px, use]) => `<div class="mh-plate mh-plate--all" style="--_cut: var(${token}); --mh-cut-tl: var(${token}); --mh-cut-tr: var(${token}); --mh-cut-br: var(${token}); --mh-cut-bl: var(${token}); min-height: 110px; padding: 14px; display:grid; align-content:end; gap: 4px">
        <code style="font: 700 var(--mh-text-xs) / 1.2 var(--mh-font-mono)">${token}</code>
        <span class="mh-muted" style="font-size: var(--mh-text-2xs)">${px} at 1× · ${use}</span>
      </div>`,
    ).join("")}</div>`),
};

export const CutScale = {
  name: "Cut scale",
  parameters: describe(null, "Drag `scale` to see every chamfer move together. The container carries `data-mh-theme` so derived cut tokens recompute inside it."),
  args: { scale: 1 },
  argTypes: { scale: { control: { type: "range", min: 0, max: 2, step: 0.25 }, description: "--mh-cut-scale" } },
  render: ({ scale }) => {
    const theme = document.documentElement.dataset.mhTheme ?? "ink";
    return render(`<div data-mh-theme="${theme}" style="--mh-cut-scale: ${scale}; display:grid; gap: 20px">
      <span class="mh-label">--mh-cut-scale: ${scale}</span>
      <div class="sb-row" style="gap: 16px">
        <button type="button" class="mh-plate mh-button"><span class="mh-button__label">Claim job</span></button>
        <button type="button" class="mh-plate mh-button mh-button--secondary"><span class="mh-button__label">Manifest</span></button>
        <span class="mh-plate mh-plate--xs mh-status" data-status="open">Open</span>
        <span class="mh-plate mh-plate--xs mh-tag">MRD</span>
      </div>
      <div class="sb-grid" style="--sb-min: 160px">
        <div class="mh-plate" style="min-height: 90px; padding: 12px">Default plate</div>
        <div class="mh-plate mh-plate--tl-br mh-plate--lg" style="min-height: 90px; padding: 12px">Large diagonal</div>
        <div class="mh-plate mh-plate--brand mh-plate--all" style="min-height: 90px; padding: 12px">Brand, all corners</div>
      </div>
    </div>`);
  },
};

export const KeylineAndSeam = {
  name: "Keyline and seam",
  parameters: describe(null, "`--mh-keyline` (1px) is the plate outline; components thicken it to 2px for focus and current state. `--mh-seam` (6px) is the gap between interlocked plates in tracks and navigation."),
  render: () =>
    render(`<div class="sb-stack">
      <div class="sb-row" style="gap: 16px">
        <div class="mh-plate" style="padding: 16px 20px">1px keyline</div>
        <div class="mh-plate" style="--mh-plate-keyline-width: 2px; --mh-plate-keyline: var(--mh-fg); padding: 16px 20px">2px focus keyline</div>
        <div class="mh-plate" style="--mh-plate-keyline-width: 2px; --mh-plate-keyline: var(--mh-accent); padding: 16px 20px">2px current</div>
      </div>
      <div class="mh-track-scroll" style="max-width: 640px"><ol class="mh-track" aria-label="Seam example">
        <li class="mh-plate mh-track__step" data-step="done"><span class="mh-lamp" aria-hidden="true"></span><span>Listed</span></li>
        <li class="mh-plate mh-track__step" data-step="current" aria-current="step"><span class="mh-lamp" aria-hidden="true"></span><span>Claimed</span></li>
        <li class="mh-plate mh-track__step" data-step="todo"><span class="mh-lamp" aria-hidden="true"></span><span>Collected</span></li>
      </ol></div>
      <p class="sb-caption">Each step after the first notches into the previous one's corner, <code>--mh-seam</code> apart.</p>
    </div>`),
};
