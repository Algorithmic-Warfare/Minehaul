import { render, describe, icon, identicon } from "../_lib.js";
import { iconNames } from "../../js/icons.js";
import { CHARACTERS, short } from "../../demo/network.js";

const SEEDS = [
  "0x7a3ec1f0", "0x2b9104d7", "0x9c0fe83a", "0x5e1c8a4f", "0x3a9f2c7e", "0x9d4b1e7a",
  "0x8b3d1f6e", "0x6d2a8f4c", "0x1f8c3a6e", "0x0b44c3d9", "0x7c2e91aa", "0xa41b7c30",
];

export default {
  title: "Foundations/Icons",
  parameters: describe(
    "Pixel icons on a 7 × 7 grid, compiled to one crisp SVG path by `icon(name, { label, size })` in `js/icons.js`. Size them at 14, 21 or 28px so every cell lands on whole pixels. Icons are decorative unless you pass `label`.",
  ),
};

export const AllIcons = {
  name: "All icons",
  render: () =>
    render(`<div class="sb-grid" style="--sb-min: 150px">${iconNames
      .map(
        (name) => `<figure class="mh-plate" style="margin:0; padding: 14px; display:grid; gap: 10px; --mh-plate-fill: var(--mh-bg)">
          <div class="sb-row" style="gap: 14px; align-items: end">${icon(name, { size: 14 })}${icon(name, { size: 21 })}${icon(name, { size: 28 })}</div>
          <figcaption style="display:flex; justify-content: space-between; align-items: center; gap: 6px">
            <code style="font: var(--mh-text-xs) / 1.2 var(--mh-font-mono)">${name}</code>
            <button type="button" class="mh-id__copy" data-mh-copy='icon("${name}")' aria-label="Copy usage for ${name}">${icon("copy")}</button>
          </figcaption>
        </figure>`,
      )
      .join("")}</div>`),
};

export const Icon = {
  parameters: describe(null, "One icon with its size and colour token. Colour follows `currentColor`."),
  args: { name: "cargo", size: 28, colour: "--mh-fg", label: "" },
  argTypes: {
    name: { control: "select", options: iconNames },
    size: { control: "inline-radio", options: [14, 21, 28, 56] },
    colour: { control: "select", options: ["--mh-fg", "--mh-muted", "--mh-accent", "--mh-accent-text", "--mh-brand-text", "--mh-ok", "--mh-warn", "--mh-alert"] },
    label: { control: "text", description: "Accessible name; empty means decorative" },
  },
  render: ({ name, size, colour, label }) =>
    render(`<div class="sb-stack" style="justify-items: start">
      <span style="color: var(${colour})">${icon(name, { size, label: label || undefined })}</span>
      <code style="font: var(--mh-text-xs) / 1.4 var(--mh-font-mono); color: var(--mh-muted)">icon("${name}"${label ? `, { label: "${label}" }` : ""})</code>
    </div>`),
};

export const InContext = {
  name: "In context",
  parameters: describe(null, "Icons inside buttons, statuses and notices inherit size from the text and colour from the component."),
  render: () =>
    render(`<div class="sb-stack">
      <div class="sb-row">
        <button type="button" class="mh-plate mh-button"><span class="mh-button__label">${icon("cargo")} Claim job</span></button>
        <button type="button" class="mh-plate mh-button mh-button--secondary"><span class="mh-button__label">${icon("route")} Route</span></button>
        <button type="button" class="mh-plate mh-iconbtn" aria-label="Refresh board">${icon("refresh")}</button>
        <button type="button" class="mh-plate mh-iconbtn" aria-label="Filter jobs">${icon("filter")}</button>
      </div>
      <div class="sb-row" style="font-size: var(--mh-text-sm); gap: 20px">
        <span style="color: var(--mh-warn)">${icon("hourglass")} 1h 36m to deadline</span>
        <span style="color: var(--mh-ok)">${icon("check")} Settled</span>
        <span style="color: var(--mh-alert)">${icon("alert")} Delivery rejected</span>
        <span class="mh-muted">${icon("lock")} Collateral escrowed</span>
      </div>
    </div>`),
};

export const Identicons = {
  parameters: describe(
    null,
    "`identicon(seed)` draws a mirrored 5 × 5 mark for an address or character. Colours come from tokens, so marks follow the palette and theme. They identify, they don't authenticate: always show the address alongside.",
  ),
  render: () =>
    render(`<div class="sb-stack">
      <section class="sb-section">
        <span class="mh-label">Characters</span>
        <div class="sb-row" style="gap: 12px">${Object.values(CHARACTERS)
          .map((c) => `<span class="mh-id">${identicon(c.address, { size: 22 })}<span>${c.name}</span><code title="${c.address}">${short(c.address)}</code><button type="button" class="mh-id__copy" data-mh-copy="${c.address}" aria-label="Copy ${c.name}'s address">${icon("copy")}</button></span>`)
          .join("")}</div>
      </section>
      <section class="sb-section">
        <span class="mh-label">Object IDs</span>
        <div class="sb-row" style="gap: 14px">${SEEDS.map((s) => `<span style="display:grid; gap: 4px; justify-items: center">${identicon(s, { size: 42, label: `Identicon for ${s}` })}<code style="font: var(--mh-text-2xs) / 1 var(--mh-font-mono); color: var(--mh-muted)">${s}</code></span>`).join("")}</div>
      </section>
    </div>`),
};
