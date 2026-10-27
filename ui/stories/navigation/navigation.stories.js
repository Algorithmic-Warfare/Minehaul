import { render, icon, identicon, describe } from "../_lib.js";
import { CHARACTERS } from "../../demo/network.js";

let n = 0;
const uid = (p) => `${p}-${++n}`;

const mark = `<span class="mh-mark" aria-hidden="true">${"<i></i>".repeat(9)}</span>`;
const item = (label, { current = false, count } = {}) =>
  `<li><a class="mh-plate mh-navitem" href="#"${current ? ' aria-current="page"' : ""}><span class="mh-lamp" aria-hidden="true"></span>${label}${count != null ? `<span class="mh-count">${count}</span>` : ""}</a></li>`;

const stopLinks = (el) => {
  el.addEventListener("click", (e) => {
    if (e.target.closest('a[href="#"]')) e.preventDefault();
  });
  return el;
};

export default {
  title: "Navigation",
  parameters: describe(
    "Wayfinding for a Minehaul client. The top bar carries the brand mark (the 3 × 3 stack with one lit cell), an interlocking nav list and the account actions. " +
      "Nav items notch into each other the same way lifecycle steps do; the current page gets the card fill and a lit lamp. " +
      "Tabs, menus and breadcrumbs are wired by `js/behaviors.js` (`data-mh-tabs`, `data-mh-menu`).",
  ),
  render: () => render(""),
};

export const TopBar = {
  name: "Top bar",
  parameters: { layout: "fullscreen" },
  render: () =>
    stopLinks(
      render(`<header class="mh-topbar" style="position: relative">
        <a class="mh-topbar__brand" href="#">${mark}Minehaul <span class="mh-plate mh-plate--xs mh-tag">Testnet</span></a>
        <nav class="mh-topbar__nav" aria-label="Primary"><ul class="mh-navlist">
          ${item("Board", { current: true })}${item("My hauls", { count: 3 })}${item("Networks")}${item("Governance")}
        </ul></nav>
        <div class="mh-topbar__actions">
          <span class="mh-badge-wrap"><button type="button" class="mh-plate mh-iconbtn" aria-label="Notifications, 2 unread">${icon("bell")}</button><span class="mh-count" aria-hidden="true">2</span></span>
          <button type="button" class="mh-plate mh-wallet">
            ${identicon(CHARACTERS.vex.address, { size: 28 })}
            <span>Vex Harrow<small>42,180 CR</small></span>
          </button>
        </div>
      </header>
      <div style="padding: var(--mh-space-5) var(--mh-space-4)"><p class="sb-caption">The bar is sticky in an app; here it's static so it doesn't cover the docs. On narrow screens the nav list scrolls sideways inside the bar.</p></div>`),
    ),
};

export const NavList = {
  name: "Nav list",
  render: () =>
    stopLinks(
      render(`<div class="sb-stack">
        <nav aria-label="Primary"><ul class="mh-navlist">${item("Board", { current: true })}${item("My hauls", { count: 3 })}${item("Networks")}${item("Governance")}</ul></nav>
        <nav aria-label="Network sections"><ul class="mh-navlist">${item("Overview")}${item("Endpoints", { current: true, count: 3 })}${item("Adapters")}${item("Treasury")}</ul></nav>
        <p class="sb-caption">Each item after the first notches into the previous one's corner, with a 6px seam (<code>--mh-seam</code>). Hover and focus light the lamp; <code>aria-current="page"</code> keeps it lit and fills the plate.</p>
      </div>`),
    ),
};

export const Tabs = {
  render: () => {
    const id = uid("tabs");
    return render(`<div class="mh-tabs" data-mh-tabs>
      <div class="mh-tabs__list" role="tablist" aria-label="Jobs by stage">
        <button type="button" class="mh-tab" role="tab" id="${id}-t1" aria-controls="${id}-p1" aria-selected="true">Open <span class="mh-count">11</span></button>
        <button type="button" class="mh-tab" role="tab" id="${id}-t2" aria-controls="${id}-p2" aria-selected="false">Live <span class="mh-count mh-count--accent">5</span></button>
        <button type="button" class="mh-tab" role="tab" id="${id}-t3" aria-controls="${id}-p3" aria-selected="false">Ended <span class="mh-count">5</span></button>
      </div>
      <div class="mh-tabpanel" role="tabpanel" id="${id}-p1" aria-labelledby="${id}-t1" tabindex="0">
        <p class="sb-caption">11 funded Transfers waiting for a hauler. 135,730 CR in rewards across AST, MRD and ORG; the highest rate is MH-0245 at 26.72 CR/u.</p>
      </div>
      <div class="mh-tabpanel" role="tabpanel" id="${id}-p2" aria-labelledby="${id}-t2" tabindex="0" hidden>
        <p class="sb-caption">5 hauls in progress: 2 claimed, 2 collected, 1 in its dispute window (MH-0242, 14h 24m left).</p>
      </div>
      <div class="mh-tabpanel" role="tabpanel" id="${id}-p3" aria-labelledby="${id}-t3" tabindex="0" hidden>
        <p class="sb-caption">1 settled, 1 resolved for the hauler, 1 disputed, 1 expired unclaimed, 1 cancelled by its lister.</p>
      </div>
    </div>`);
  },
  parameters: describe(null, "Arrow keys move between tabs, Home and End jump to the ends; the selected tab's underline grows from the left."),
};

export const Breadcrumbs = {
  render: () =>
    stopLinks(
      render(`<nav class="mh-crumbs" aria-label="Breadcrumb"><ol>
        <li><a href="#">Networks</a></li>
        <li><a href="#">Meridian Union</a></li>
        <li><a href="#">Jobs</a></li>
        <li aria-current="page">MH-0246</li>
      </ol></nav>`),
    ),
};

export const Menu = {
  render: () => {
    const id = uid("menu");
    return render(`<div class="sb-stack" style="min-height: 280px; align-content: start">
      <div class="mh-menu-anchor">
        <button type="button" class="mh-plate mh-button mh-button--secondary mh-button--sm" data-mh-menu aria-haspopup="menu" aria-expanded="false" aria-controls="${id}">
          <span class="mh-button__label" style="display:inline-flex;gap:8px;align-items:center">MH-0246 ${icon("caret-down")}</span>
        </button>
        <div class="mh-plate mh-plate--sm mh-menu" id="${id}" role="menu" aria-label="Job actions" hidden>
          <span class="mh-label mh-menu__label">Transfer · MH-0246</span>
          <button type="button" class="mh-menu__item" role="menuitem"><span class="mh-lamp mh-lamp--sm" aria-hidden="true"></span>Copy job ID<span class="mh-kbd">⌘C</span></button>
          <button type="button" class="mh-menu__item" role="menuitem"><span class="mh-lamp mh-lamp--sm" aria-hidden="true"></span>View on explorer ${icon("external")}</button>
          <button type="button" class="mh-menu__item" role="menuitem"><span class="mh-lamp mh-lamp--sm" aria-hidden="true"></span>Show manifest</button>
          <hr class="mh-menu__sep">
          <button type="button" class="mh-menu__item mh-menu__item--danger" role="menuitem"><span class="mh-lamp mh-lamp--sm" aria-hidden="true"></span>Open dispute</button>
          <button type="button" class="mh-menu__item" role="menuitem" disabled><span class="mh-lamp mh-lamp--sm" aria-hidden="true"></span>Cancel listing (claimed)</button>
        </div>
      </div>
      <p class="sb-caption">Click the trigger. Arrow keys move between items, Escape closes and returns focus, clicking outside closes.</p>
    </div>`);
  },
};

export const Pager = {
  render: () =>
    render(`<nav class="mh-pager" aria-label="Job pages">
      <button type="button" class="mh-plate mh-iconbtn mh-iconbtn--sm" aria-label="Previous page">${icon("arrow-left")}</button>
      <button type="button" class="mh-pager__page">1</button>
      <button type="button" class="mh-pager__page" aria-current="page">2</button>
      <button type="button" class="mh-pager__page">3</button>
      <span class="mh-pager__gap" aria-hidden="true">…</span>
      <button type="button" class="mh-pager__page">7</button>
      <button type="button" class="mh-plate mh-iconbtn mh-iconbtn--sm" aria-label="Next page">${icon("arrow-right")}</button>
    </nav>`),
};
