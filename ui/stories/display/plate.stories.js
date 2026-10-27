import { render, describe } from "../_lib.js";

const CORNERS = ["tr-bl", "tl", "tr", "br", "bl", "tl-br", "all"];
const CUTS = ["xs", "sm", "md", "lg"];
const FILLS = ["default", "ground", "raised", "accent", "brand", "hatch"];

const plateClass = ({ corners, cut, fill, octagon }) =>
  [
    "mh-plate",
    corners && corners !== "tr-bl" ? `mh-plate--${corners}` : "",
    cut && cut !== "md" ? `mh-plate--${cut}` : "",
    fill && fill !== "default" ? `mh-plate--${fill}` : "",
    octagon ? "mh-plate--octagon" : "",
  ]
    .filter(Boolean)
    .join(" ");

export default {
  title: "Display/Plate",
  parameters: describe(
    "The primitive under every Minehaul component: a keyline and a fill clipped to chamfered corners. The keyline paints under the fill, so a translucent fill shows it through. The clip removes outlines and shadows too, so focus is drawn as a thicker keyline. Corner depth follows `--mh-cut-scale`; switch the toolbar to **Square** for AWAR's square corners.\n\n```html\n<div class=\"mh-plate mh-plate--tl-br mh-plate--lg\">…</div>\n<div class=\"mh-plate\" style=\"--mh-plate-fill: …; --mh-plate-keyline: …\">…</div>\n```",
  ),
  argTypes: {
    corners: { control: "select", options: CORNERS, description: "Which corners are cut. Default is tr-bl." },
    cut: { control: "inline-radio", options: CUTS, description: "Cut depth token: xs, sm, md (default) or lg." },
    fill: { control: "select", options: FILLS, description: "Fill modifier." },
    octagon: { control: "boolean", description: "Big cuts top-left/bottom-right, small on the others (overrides corners)." },
    keyline: { control: "select", options: ["--mh-line", "--mh-trim", "--mh-accent", "--mh-brand-fill", "--mh-ok", "--mh-warn", "--mh-alert"], description: "Keyline colour token (sets `--mh-plate-keyline`)." },
    keylineWidth: { control: { type: "range", min: 1, max: 4, step: 1 }, description: "`--mh-plate-keyline-width` in px." },
    label: { control: "text" },
  },
  args: { corners: "tr-bl", cut: "md", fill: "default", octagon: false, keyline: "--mh-line", keylineWidth: 1, label: "Meridian Outpost · SSU-04" },
  render: (args) =>
    render(`<div class="${plateClass(args)}" style="--mh-plate-keyline: var(${args.keyline}); --mh-plate-keyline-width: ${args.keylineWidth}px; max-width: 360px; min-height: 120px; padding: 20px; display: grid; align-content: end; gap: 4px;">
      <span class="mh-label">Plate</span><b style="font-family: var(--mh-font-display); font-size: var(--mh-text-lg)">${args.label}</b>
      <code style="font-size: var(--mh-text-2xs); opacity: .7">${plateClass(args)}</code>
    </div>`),
};

export const Playground = {};

const tile = (cls, title, note) =>
  `<div class="${cls}" style="min-height: 96px; padding: 12px 14px; display: grid; align-content: end; gap: 2px; font-size: var(--mh-text-sm)"><b>${title}</b><code style="font-size: var(--mh-text-2xs); opacity: .7">${note}</code></div>`;

export const Corners = {
  parameters: describe(null, "Each corner can be cut alone, as a diagonal pair, or all four. tr-bl is the default and the house shape for cards."),
  render: () =>
    render(`<div class="sb-grid" style="--sb-min: 150px">${CORNERS.map((c) => tile(plateClass({ corners: c }), c === "tr-bl" ? "Default" : c, c === "tr-bl" ? ".mh-plate" : `.mh-plate--${c}`)).join("")}${tile("mh-plate mh-plate--octagon", "Octagon", ".mh-plate--octagon")}</div>`),
};

export const Depths = {
  parameters: describe(null, "Cut depths are tokens (`--mh-cut-xs/sm/md/lg`) multiplied by `--mh-cut-scale`. Small depths suit chips and tags; large ones suit page-level cards."),
  render: () =>
    render(`<div class="sb-grid" style="--sb-min: 150px">${CUTS.map((c) => tile(plateClass({ cut: c, corners: "all" }), c, `--mh-cut-${c}`)).join("")}</div>`),
};

export const Fills = {
  parameters: describe(null, "Fill modifiers set `--mh-plate-fill` (and the keyline where it needs to match). Hatch uses the soft hatch so text stays readable."),
  render: () =>
    render(`<div class="sb-grid" style="--sb-min: 150px">${FILLS.map((f) => tile(plateClass({ fill: f }), f, f === "default" ? "surface" : `.mh-plate--${f}`)).join("")}
      <div class="mh-plate" style="--mh-plate-fill: color-mix(in srgb, var(--mh-ok) 14%, var(--mh-bg)); --mh-plate-keyline: var(--mh-ok); color: var(--mh-ok); min-height: 96px; padding: 12px 14px; display: grid; align-content: end; gap: 2px; font-size: var(--mh-text-sm)"><b>Custom</b><code style="font-size: var(--mh-text-2xs); opacity: .7">--mh-plate-fill / keyline</code></div>
    </div>`),
};

export const NotchedRow = {
  name: "Notched row",
  parameters: describe(
    null,
    "An octagon followed by `.mh-plate--notch` plates. Each notched plate cuts its left edge inward so it sits under the previous plate's bottom-right corner; pull it back by the big cut less the seam (`margin-left: calc(var(--mh-seam) - var(--mh-cut-md))`). This is the geometry behind the lifecycle track and the interlocking nav list.",
  ),
  render: () => {
    const step = (cls, text, first) =>
      `<div class="${cls}" style="padding: 12px 20px 12px ${first ? "16px" : "calc(16px + var(--mh-cut-md))"}; ${first ? "" : "margin-left: calc(var(--mh-seam) - var(--mh-cut-md));"} font: 700 var(--mh-text-sm)/1.2 var(--mh-font-mono); white-space: nowrap">${text}</div>`;
    return render(`<div style="overflow-x: auto"><div style="display: flex; min-width: max-content">
      ${step("mh-plate mh-plate--octagon", "Source · SSU-04", true)}
      ${step("mh-plate mh-plate--notch mh-plate--raised", "Cargo · 1,600 u")}
      ${step("mh-plate mh-plate--notch mh-plate--accent", "Destination · SSU-05")}
    </div></div>`);
  },
};

export const Nested = {
  name: "Nested plates",
  parameters: describe(null, "Plate variables don't inherit, so a nested plate starts clean: its own default corners, keyline and fill."),
  render: () =>
    render(`<div class="mh-plate mh-plate--lg mh-plate--tl-br" style="padding: 20px; display: grid; gap: 12px; max-width: 520px">
      <span class="mh-label">Network · Meridian Union</span>
      <div class="sb-grid" style="--sb-min: 150px">
        <div class="mh-plate mh-plate--ground" style="padding: 12px"><span class="mh-label">SSU-04</span><div>Meridian Outpost</div></div>
        <div class="mh-plate mh-plate--ground" style="padding: 12px; --mh-plate-keyline: var(--mh-warn)"><span class="mh-label">SSU-05 · leased</span><div>Kepler Station</div></div>
      </div>
    </div>`),
};
