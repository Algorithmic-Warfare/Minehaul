import { render, icon, describe, int } from "../_lib.js";
import { iconNames } from "../../js/icons.js";
import { minCollateral } from "../../js/job.js";
import { JOBS } from "../../demo/jobs.js";

const job0248 = JOBS.find((j) => j.id === "MH-0248");

const cells = `<span class="mh-button__cells" aria-hidden="true"><i></i><i></i><i></i></span>`;

/** One button as markup. */
function button({ label, variant = "primary", size = "md", busy = false, disabled = false, iconName = "none", iconPosition = "end" }) {
  const cls = ["mh-plate", "mh-button", variant !== "primary" && `mh-button--${variant}`, size !== "md" && `mh-button--${size}`].filter(Boolean).join(" ");
  const glyph = iconName && iconName !== "none" ? icon(iconName) : "";
  const inner = iconPosition === "start" ? `${glyph}${label}` : `${label}${glyph}`;
  return `<button type="button" class="${cls}"${busy ? ' aria-busy="true"' : ""}${disabled ? " disabled" : ""}>
    <span class="mh-button__label" style="display:inline-flex;align-items:center;gap:8px">${inner}</span>${cells}
  </button>`;
}

export default {
  title: "Actions/Button",
  parameters: describe(
    "An asymmetric octagon on `.mh-plate`. Hover or keyboard focus sweeps the keyline once round the edge (a `conic-gradient` animated through `@property`). " +
      "`aria-busy=\"true\"` swaps the label for a radar sweep and three pulsing cells while staying focusable; `disabled` hatches the fill. " +
      "Variants: primary (signal fill) for the one action that moves a job forward, secondary for neutral actions, brand for governance and evidence, ghost for risky or low-emphasis actions such as opening a dispute.",
  ),
  argTypes: {
    label: { control: "text" },
    variant: { control: "inline-radio", options: ["primary", "secondary", "brand", "ghost"] },
    size: { control: "inline-radio", options: ["sm", "md", "lg"] },
    busy: { control: "boolean", description: "Sets `aria-busy=\"true\"`" },
    disabled: { control: "boolean" },
    iconName: { name: "icon", control: "select", options: ["none", ...iconNames] },
    iconPosition: { control: "inline-radio", options: ["start", "end"] },
  },
  args: { label: "Claim job", variant: "primary", size: "md", busy: false, disabled: false, iconName: "none", iconPosition: "end" },
  render: (args) => render(`<div class="sb-row">${button(args)}</div>`),
};

export const Playground = {};

export const Variants = {
  render: () =>
    render(`<div class="sb-stack">
      <div class="sb-row">
        ${button({ label: "Claim job" })}
        ${button({ label: "Manifest", variant: "secondary" })}
        ${button({ label: "Propose", variant: "brand" })}
        ${button({ label: "Open dispute", variant: "ghost" })}
      </div>
      <p class="sb-caption">Use one primary action per job. Brand is reserved for governance and evidence; ghost carries actions whose consequences need a second thought.</p>
    </div>`),
};

export const Sizes = {
  render: () =>
    render(`<div class="sb-stack">
      <div class="sb-row" style="align-items:end">
        ${button({ label: "Small", size: "sm" })}
        ${button({ label: "Medium", size: "md" })}
        ${button({ label: "Large", size: "lg" })}
      </div>
      <div class="sb-row" style="align-items:end">
        ${button({ label: "Small", size: "sm", variant: "secondary" })}
        ${button({ label: "Medium", size: "md", variant: "secondary" })}
        ${button({ label: "Large", size: "lg", variant: "secondary" })}
      </div>
      <p class="sb-caption">Medium is floored at 44px, the WCAG 2.5.5 target size. Small (32px) is for dense desktop tables and toolbars only.</p>
    </div>`),
};

export const States = {
  render: () =>
    render(`<div class="sb-stack">
      <div class="sb-grid" style="--sb-min: 180px">
        <div><span class="mh-label sb-label">Rest</span>${button({ label: "Claim job" })}</div>
        <div><span class="mh-label sb-label">Hover · focus</span>${button({ label: "Hover me" })}<p class="sb-caption">The keyline sweeps round and thickens to 2px; keyboard focus sweeps more slowly and turns the edge to the foreground colour.</p></div>
        <div><span class="mh-label sb-label">Busy</span>${button({ label: "Claiming", busy: true })}<p class="sb-caption">Stays focusable; activation is the caller's job to block.</p></div>
        <div><span class="mh-label sb-label">Disabled</span>${button({ label: "Finalize", disabled: true })}<p class="sb-caption">Hatched fill, muted label.</p></div>
      </div>
    </div>`),
  parameters: describe(null, "Press any button to see the 1px press offset. Busy and disabled buttons don't move."),
};

export const WithIcons = {
  name: "With icons",
  render: () =>
    render(`<div class="sb-row">
      ${button({ label: "Claim job", iconName: "arrow-right" })}
      ${button({ label: "Refresh board", variant: "secondary", iconName: "refresh", iconPosition: "start" })}
      ${button({ label: "Deliver to SSU-05", iconName: "cargo", iconPosition: "start" })}
      ${button({ label: "Explorer", variant: "ghost", iconName: "external" })}
    </div>`),
  parameters: describe(null, "Icons sit inside the label at 1em. Use them to reinforce the verb, never instead of it."),
};

export const MinehaulActions = {
  name: "Minehaul actions",
  render: () => {
    const rows = [
      ["open", "Open", `${button({ label: `Claim · post ${int.format(minCollateral(job0248))} CR` })}${button({ label: "Manifest", variant: "secondary" })}`, "MH-0248 · minimum collateral is 50% of 19,000 CR, rounded up"],
      ["claimed", "Claimed", button({ label: "Confirm collection" }), "MH-0244 · collect at SSU-05 first"],
      ["collected", "Collected", button({ label: "Deliver to SSU-05", iconName: "cargo", iconPosition: "start" }), "MH-0246 · needs a delivery adapter to certify the handoff"],
      ["delivered", "Delivered", `${button({ label: "Finalize", disabled: true })}${button({ label: "Open dispute", variant: "ghost" })}`, "MH-0242 · finalize unlocks when the 24h window closes"],
      ["disputed", "Disputed", button({ label: "Add evidence", variant: "brand", iconName: "shield", iconPosition: "start" }), "MH-0233 · awaiting governance resolution"],
    ];
    return render(`<div class="sb-stack">${rows
      .map(
        ([status, label, actions, note]) => `<div class="sb-section">
          <div class="sb-row"><span class="mh-plate mh-plate--xs mh-status" data-status="${status}">${label}</span><span class="sb-caption">${note}</span></div>
          <div class="sb-row">${actions}</div>
        </div>`,
      )
      .join("")}</div>`);
  },
  parameters: describe(null, "The action row a job card shows for each `ActionStatus`. Exactly one primary action moves the job forward."),
};
