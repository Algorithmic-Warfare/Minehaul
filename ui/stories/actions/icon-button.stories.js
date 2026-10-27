import { render, icon, describe } from "../_lib.js";

export default {
  title: "Actions/Icon button & segmented",
  parameters: describe(
    "Compact actions for toolbars and dense rows. `.mh-iconbtn` is a small octagon that always needs an `aria-label`; wrap it in `.mh-badge-wrap` to attach a `.mh-count`. " +
      "`.mh-seg` is a segmented control for mutually exclusive views or sorts (buttons with `aria-pressed`). `.mh-link` is a text-weight action for toasts and banners, and `.mh-kbd` shows a keyboard shortcut.",
  ),
  render: () => render(""),
};

export const IconButton = {
  name: "Icon button",
  render: () =>
    render(`<div class="sb-stack">
      <div class="sb-section">
        <span class="mh-label">Sizes</span>
        <div class="sb-row">
          <button type="button" class="mh-plate mh-iconbtn" aria-label="Refresh board">${icon("refresh")}</button>
          <button type="button" class="mh-plate mh-iconbtn mh-iconbtn--sm" aria-label="Refresh board">${icon("refresh")}</button>
          <button type="button" class="mh-plate mh-iconbtn" aria-label="Filter jobs">${icon("filter")}</button>
          <button type="button" class="mh-plate mh-iconbtn" aria-label="More actions">${icon("dots")}</button>
          <button type="button" class="mh-plate mh-iconbtn" aria-label="Copy job ID">${icon("copy")}</button>
        </div>
      </div>
      <div class="sb-section">
        <span class="mh-label">States</span>
        <div class="sb-row">
          <button type="button" class="mh-plate mh-iconbtn" aria-label="Show stacks view" aria-pressed="true">${icon("stacks")}</button>
          <button type="button" class="mh-plate mh-iconbtn" aria-label="Show list view" aria-pressed="false">${icon("menu")}</button>
          <button type="button" class="mh-plate mh-iconbtn" aria-label="Pause network" disabled>${icon("pause")}</button>
        </div>
        <p class="sb-caption">Pressed fills with the foreground colour, for view toggles. Disabled is hatched.</p>
      </div>
      <div class="sb-section">
        <span class="mh-label">With a count badge</span>
        <div class="sb-row" style="gap: var(--mh-space-5)">
          <span class="mh-badge-wrap"><button type="button" class="mh-plate mh-iconbtn" aria-label="Notifications, 3 unread">${icon("bell")}</button><span class="mh-count" aria-hidden="true">3</span></span>
          <span class="mh-badge-wrap"><button type="button" class="mh-plate mh-iconbtn" aria-label="Hauls needing action, 1">${icon("cargo")}</button><span class="mh-count" aria-hidden="true">1</span></span>
          <span class="mh-badge-wrap"><button type="button" class="mh-plate mh-iconbtn" aria-label="Disputes, new activity">${icon("shield")}</button><span class="mh-count" aria-hidden="true"></span></span>
        </div>
        <p class="sb-caption">The count is decorative; put the number in the button's <code>aria-label</code>. An empty <code>.mh-count</code> becomes a dot.</p>
      </div>
    </div>`),
};

export const Segmented = {
  render: () =>
    render(`<div class="sb-stack">
      <div class="sb-section">
        <span class="mh-label" id="seg-order">Stack order</span>
        <div class="mh-seg" role="group" aria-labelledby="seg-order" data-seg>
          <button type="button" aria-pressed="true">Order · rate</button>
          <button type="button" aria-pressed="false">Order · size</button>
        </div>
      </div>
      <div class="sb-section">
        <span class="mh-label" id="seg-net">Network</span>
        <div class="mh-seg" role="group" aria-labelledby="seg-net" data-seg>
          <button type="button" aria-pressed="true">All <span class="mh-count">16</span></button>
          <button type="button" aria-pressed="false">AST <span class="mh-count">7</span></button>
          <button type="button" aria-pressed="false">MRD <span class="mh-count">5</span></button>
          <button type="button" aria-pressed="false">ORG <span class="mh-count">4</span></button>
        </div>
      </div>
      <p class="sb-caption">Each segment is a real button with <code>aria-pressed</code>, so Tab moves between them and Space or Enter selects. Selection logic is yours; this story toggles <code>aria-pressed</code> on click.</p>
    </div>`),
  decorators: [
    (story) => {
      const el = story();
      el.addEventListener("click", (e) => {
        const b = e.target.closest("[data-seg] button");
        if (!b) return;
        for (const s of b.parentElement.children) s.setAttribute("aria-pressed", String(s === b));
      });
      return el;
    },
  ],
};

export const LinkAndKbd = {
  name: "Link & keyboard hint",
  render: () =>
    render(`<div class="sb-stack">
      <div class="sb-row">
        <button type="button" class="mh-link">View job</button>
        <button type="button" class="mh-link">Undo</button>
        <button type="button" class="mh-link">Renew lease</button>
      </div>
      <div class="sb-row mh-muted" style="font-size: var(--mh-text-sm)">
        Press <span class="mh-kbd">/</span> to search · <span class="mh-kbd">C</span> to claim the selected job · <span class="mh-kbd">Esc</span> to close
      </div>
    </div>`),
};
