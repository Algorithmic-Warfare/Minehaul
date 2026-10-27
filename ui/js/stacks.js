/**
 * Stacks: columns of square cells, one contiguous run per item, with an
 * optional true-scale strip and a movable "lens" threshold.
 *
 * @example
 * const stacks = renderStacks(el, {
 *   title: "Open board by reward rate",
 *   items: jobs,
 *   id: (job) => job.id,
 *   size: (job) => job.units,             // what a square counts
 *   unit: { per: 100, label: "100 u" },   // one square = 100 units
 *   metric: (job) => job.reward / job.units,
 *   groups: [{ key: "bulk", label: "Bulk", code: "< 5 CR/u", range: [0, 5] }, …],
 *   lens: { value: 12, min: 0, max: 30, step: 0.5, label: "Floor" },
 *   match: (job, lens, metric) => metric >= lens,
 *   hazard: (job) => job.risk ?? null,
 *   strip: { domain: [0, 30], ticks: [0, 5, 10, 15, 20, 25, 30] },
 *   onSelect: (job) => …,
 *   headingLevel: 3,                      // title level; columns use the next one
 * });
 * stacks.select("MH-0246");
 */

const esc = (value) =>
  String(value).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

const int = new Intl.NumberFormat("en-US", { maximumFractionDigits: 0 });

const defaults = {
  perRow: 12,
  busyAt: 4,
  busyLabel: "busy",
  order: "metric",
  orderLabels: { metric: "Order · rate", size: "Order · size" },
  sizeFormat: (v) => int.format(v),
  sizeUnit: "",
  metricFormat: (v) => v.toFixed(2),
  matchLabel: "Meets lens",
  hazardLabel: "Risk trait",
  itemLabel: ["job", "jobs"],
};

export function renderStacks(root, options) {
  const cfg = { ...defaults, ...options };
  const state = {
    order: cfg.order,
    selected: cfg.selected ?? null,
    lens: cfg.lens?.value,
  };

  // Heading levels follow the page outline: the title, then one level down per column
  const level = Math.min(6, Math.max(1, cfg.headingLevel ?? 3));
  const sub = Math.min(6, level + 1);

  root.classList.add("mh-stacks");
  root.style.setProperty("--per-row", cfg.perRow);

  const inBand = (group, metric) => {
    const [lo = -Infinity, hi = Infinity] = group.range ?? [];
    return metric >= lo && metric < hi;
  };

  function model() {
    const items = cfg.items.map((item) => {
      const metric = cfg.metric(item);
      const size = cfg.size(item);
      return {
        item,
        id: cfg.id(item),
        metric,
        size,
        cells: Math.max(1, Math.round(size / cfg.unit.per)),
        hazard: cfg.hazard?.(item) ?? null,
        match: cfg.match ? Boolean(cfg.match(item, state.lens, metric)) : false,
        group: cfg.groupOf ? cfg.groupOf(item, metric) : cfg.groups.find((g) => inBand(g, metric))?.key,
      };
    });
    // Stacks build from the bottom: lowest rate (or largest job) first
    const by = state.order === "size" ? (a, b) => b.size - a.size : (a, b) => a.metric - b.metric;
    const cols = cfg.groups.map((group) => {
      const lots = items.filter((i) => i.group === group.key).sort(by);
      lots.forEach((lot, i) => (lot.shade = i % 2 ? "b" : "a"));
      const cells = lots.flatMap((lot) => Array(lot.cells).fill(lot));
      return {
        group,
        lots,
        cells,
        total: lots.reduce((sum, lot) => sum + lot.size, 0),
        rows: Math.ceil(cells.length / cfg.perRow),
      };
    });
    return { items, cols, maxRows: Math.max(1, ...cols.map((c) => c.rows)) };
  }

  const attrs = (lot, withId = true) =>
    `${withId ? `data-id="${esc(lot.id)}" ` : ""}data-shade="${lot.shade}"${lot.match ? " data-match" : ""}${lot.hazard ? " data-hazard" : ""}${lot.id === state.selected ? " data-selected" : ""}`;

  function gridHtml(col, maxRows) {
    const rows = [];
    for (let r = 0; r < maxRows; r++) rows.push(col.cells.slice(r * cfg.perRow, (r + 1) * cfg.perRow));
    // Top row first in the DOM; partial rows fill from the left
    return rows
      .reverse()
      .map((row) =>
        Array.from({ length: cfg.perRow }, (_, i) =>
          row[i] ? `<i class="mh-sq" ${attrs(row[i])}></i>` : `<i class="mh-sq" data-empty></i>`,
        ).join(""),
      )
      .join("");
  }

  function rowsHtml(col) {
    if (!col.lots.length) return `<li class="mh-stacks__empty">No ${esc(cfg.itemLabel[1])}</li>`;
    // Listed top to bottom in the order they appear in the stack
    return [...col.lots]
      .reverse()
      .map((lot) => {
        const flag = lot.hazard ? "⚠" : lot.match ? "✓" : "";
        const note = [lot.match ? cfg.matchLabel : "", lot.hazard ?? ""].filter(Boolean).join(" · ");
        return `<li><button type="button" class="mh-stacks__row" data-select-id="${esc(lot.id)}" aria-pressed="${lot.id === state.selected}"${note ? ` title="${esc(note)}"` : ""}>
          <i class="mh-sq" ${attrs(lot, false)}></i>
          <span>${esc(lot.id)}</span>
          <span class="mh-stacks__row-metric">${esc(cfg.metricFormat(lot.metric))}</span>
          <span class="mh-stacks__row-size">${esc(cfg.sizeFormat(lot.size))}</span>
          <span class="mh-stacks__row-flag"${lot.hazard ? " data-hazard" : ""}>${flag}${note ? `<span class="mh-sr">${esc(note)}</span>` : ""}</span>
        </button></li>`;
      })
      .join("");
  }

  function colHtml(col, maxRows) {
    const n = col.lots.length;
    const avg = n ? col.total / n : 0;
    const busy = n >= cfg.busyAt;
    return `<section class="mh-stacks__col" aria-label="${esc(col.group.label)}">
      <div class="mh-stacks__col-head"><h${sub}>${esc(col.group.label)}</h${sub}><span>${esc(col.group.code ?? "")}</span></div>
      <div class="mh-stacks__total"><b>${esc(cfg.sizeFormat(col.total))}</b><small>${esc(cfg.sizeUnit)}</small>
        <small>${n} ${esc(cfg.itemLabel[n === 1 ? 0 : 1])}${n ? ` · avg ${esc(cfg.sizeFormat(avg))}` : ""}${busy ? ` · <span class="mh-stacks__busy">${esc(cfg.busyLabel)}</span>` : ""}</small></div>
      <div class="mh-stacks__grid" aria-hidden="true">${gridHtml(col, maxRows)}</div>
      <ul class="mh-stacks__rows">${rowsHtml(col)}</ul>
    </section>`;
  }

  function stripHtml(m) {
    const s = cfg.strip;
    if (!s) return "";
    const [d0, d1] = s.domain;
    const x = (v) => Math.min(100, Math.max(0, ((v - d0) / (d1 - d0)) * 100));
    const fmt = s.tickFormat ?? ((v) => String(v));
    const maxSize = Math.max(...m.items.map((i) => i.size));
    // Place on the true scale, then nudge apart bars that would touch
    const placed = [...m.items].sort((a, b) => a.metric - b.metric).map((lot) => ({ lot, x: x(lot.metric) }));
    let nudged = false;
    for (let i = 1; i < placed.length; i++) {
      if (placed[i].x - placed[i - 1].x < 1.4) {
        placed[i].x = Math.min(100, placed[i - 1].x + 1.4);
        nudged = true;
      }
    }
    const shades = new Map(m.cols.flatMap((c) => c.lots.map((l) => [l.id, l.shade])));
    const bars = placed
      .map(({ lot, x: left }) => {
        const h = Math.max(4, (lot.size / maxSize) * 100);
        return `<i class="mh-sq mh-strip__bar" style="left:${left}%;height:${h}%" ${attrs({ ...lot, shade: shades.get(lot.id) ?? "a" })} data-x="${left}" data-h="${h}"></i>`;
      })
      .join("");
    const bands = cfg.groups
      .map((g) => g.range?.[0])
      .filter((v) => v != null && v > d0 && v < d1)
      .map((v) => `<span class="mh-strip__band" style="left:${x(v)}%"><em>${esc(fmt(v))}</em></span>`)
      .join("");
    const lens =
      state.lens != null && cfg.lens
        ? `<span class="mh-strip__lens" style="left:${x(state.lens)}%"><em>${esc(cfg.lens.label)} ≥ ${esc(fmt(state.lens))} →</em></span>`
        : "";
    const ticks = (s.ticks ?? [d0, d1]).map((t) => `<span style="left:${x(t)}%">${esc(fmt(t))}</span>`).join("");
    return `<div class="mh-strip">
      <span class="mh-label">${esc(s.label ?? "Where each item sits · true scale · bar height = size")}</span>
      <div class="mh-strip__plot" aria-hidden="true">${bands}${bars}${lens}<b class="mh-strip__tag" hidden></b></div>
      <div class="mh-strip__axis" aria-hidden="true">${ticks}</div>
      ${nudged ? `<span class="mh-strip__note">Bars that would overlap are nudged apart by up to one bar width.</span>` : ""}
    </div>`;
  }

  // Head renders once, so the lens input keeps focus while dragging
  const legendSq = (a) => `<i class="mh-sq" ${a}></i>`;
  root.innerHTML = `<div class="mh-stacks__head">
      <div>
        ${cfg.title ? `<h${level} class="mh-stacks__title">${esc(cfg.title)}</h${level}>` : ""}
        ${cfg.subtitle ? `<p class="mh-stacks__sub">${esc(cfg.subtitle)}</p>` : ""}
      </div>
      <div class="mh-stacks__controls">
        ${cfg.lens ? `<label class="mh-plate mh-plate--xs mh-stacks__lens">${esc(cfg.lens.label)}
          <input type="range" min="${cfg.lens.min}" max="${cfg.lens.max}" step="${cfg.lens.step ?? 1}" value="${state.lens}" data-lens>
          <output>${esc((cfg.lens.format ?? String)(state.lens))}</output></label>` : ""}
        <div class="mh-seg" role="group" aria-label="Stack order">
          <button type="button" data-order="metric" aria-pressed="${state.order === "metric"}">${esc(cfg.orderLabels.metric)}</button>
          <button type="button" data-order="size" aria-pressed="${state.order === "size"}">${esc(cfg.orderLabels.size)}</button>
        </div>
      </div>
    </div>
    <ul class="mh-stacks__legend">
      <li>${legendSq('data-shade="b"')} 1 = ${esc(cfg.unit.label)}</li>
      ${cfg.match ? `<li>${legendSq("data-match")} ${esc(cfg.matchLabel)} (✓)</li>` : ""}
      <li>${legendSq('data-shade="a"')}${legendSq('data-shade="b"')} ${esc(cfg.itemLabel[1])} alternate light / dark</li>
      ${cfg.hazard ? `<li>${legendSq("data-hazard")} ${esc(cfg.hazardLabel)} (⚠)</li>` : ""}
      <li>${legendSq("data-selected")} Selected</li>
    </ul>
    <div data-body></div>`;

  const body = root.querySelector("[data-body]");
  let current;

  function render() {
    current = model();
    body.innerHTML = `<div class="mh-stacks__cols">${current.cols.map((c) => colHtml(c, current.maxRows)).join("")}</div>${stripHtml(current)}`;
    placeTag();
  }

  function placeTag() {
    const tag = body.querySelector(".mh-strip__tag");
    if (!tag) return;
    const bar = body.querySelector(`.mh-strip__bar[data-selected]`);
    tag.hidden = !bar;
    if (bar) {
      tag.textContent = state.selected;
      tag.style.left = `${bar.dataset.x}%`;
      tag.style.bottom = `${bar.dataset.h}%`;
    }
  }

  function select(id, notify = true) {
    state.selected = id;
    for (const el of body.querySelectorAll(".mh-sq[data-id]")) el.toggleAttribute("data-selected", el.dataset.id === id);
    for (const el of body.querySelectorAll("[data-select-id]")) {
      el.setAttribute("aria-pressed", String(el.dataset.selectId === id));
      el.querySelector(".mh-sq")?.toggleAttribute("data-selected", el.dataset.selectId === id);
    }
    placeTag();
    const lot = current.items.find((i) => i.id === id);
    if (notify && lot) cfg.onSelect?.(lot.item);
  }

  root.addEventListener("click", (event) => {
    const order = event.target.closest("[data-order]");
    if (order) {
      state.order = order.dataset.order;
      for (const b of root.querySelectorAll("[data-order]")) b.setAttribute("aria-pressed", String(b === order));
      render();
      return;
    }
    const pick = event.target.closest("[data-select-id], .mh-sq[data-id]");
    if (pick) select(pick.dataset.selectId ?? pick.dataset.id);
  });

  root.querySelector("[data-lens]")?.addEventListener("input", (event) => {
    state.lens = Number(event.target.value);
    root.querySelector(".mh-stacks__lens output").textContent = (cfg.lens.format ?? String)(state.lens);
    render();
  });

  render();
  return { select: (id) => select(id, false), render };
}
