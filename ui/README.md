# Minehaul UI

Chamfered plates and countable stacks for Minehaul clients. The library is plain
CSS in cascade layers plus two small ES modules. There is no build step and no
framework dependency. The default palette is AWAR's
([awar.dev DESIGN.md](https://github.com/Algorithmic-Warfare/awar.dev/blob/main/DESIGN.md)).

Status: v0 alpha. Class names and the stacks API may still change.

## Storybook

Every component, state, animation and decoration has a story, plus composed
pages (job board, haul detail, network overview, my hauls).

```bash
cd ui
npm install          # Storybook 10.6.1 and Vite 8.3.3, pinned
npm run storybook    # http://localhost:6006
npm run build-storybook   # static site in ui/storybook-static/
```

The toolbar switches theme (ink or paper), palette preset and chamfer scale
for every story. Accessibility checks run in the a11y panel.

## Run the specimen

```bash
python3 -m http.server 4174 --directory ui
```

Open <http://localhost:4174>. ES modules don't load from `file://`. The
specimen has palette presets, swatch pickers, a theme switch and a chamfer
control, and it prints the CSS override for whatever you set.

## Use

```html
<link rel="stylesheet" href="ui/minehaul-ui.css">
<body class="mh-root">
  <button class="mh-plate mh-button">Claim job</button>
</body>
```

Fonts are not bundled. AWAR uses Space Grotesk (display) and JetBrains Mono
(everything else). Load them yourself, or point `--mh-font-display` and
`--mh-font-mono` at faces you already have.

The library needs browsers with `light-dark()`, `color-mix()` and cascade
layers (Baseline 2024: Chrome 123, Safari 17.5, Firefox 120). `@property`
and CSS `round()` improve motion and meter snapping where supported. Without
them the components degrade gracefully.

## Theming

Tokens come in three tiers (see [tokens.css](tokens.css)).

1. **Palette**: seven swatches on `:root`. These are the only values you need
   to change to rebrand.

   | Token | AWAR default | Role |
   | --- | --- | --- |
   | `--mh-ink` | `#171716` | ground in the ink theme, text in paper |
   | `--mh-ink-soft` | `#242321` | raised surface in ink |
   | `--mh-brand` | `#873a3c` | AWAR oxide: brand fills, "yours" |
   | `--mh-brand-deep` | `#63282b` | pressed brand |
   | `--mh-signal` | `#ff8d3a` | accent, focus, lens matches |
   | `--mh-paper` | `#f2eee6` | ground in paper, text in ink |
   | `--mh-paper-muted` | `#d6d0c5` | paper surfaces |

   Status hues have one swatch per theme: `--mh-ok-paper` and `--mh-ok-ink`,
   and the same pairs for `warn` and `alert`. `--mh-cut-scale` multiplies every
   chamfer, and `0` gives AWAR's square corners.

2. **Roles**, derived from the palette with `color-mix()` and `light-dark()`:
   `--mh-bg`, `--mh-surface`, `--mh-fg`, `--mh-muted`, `--mh-line`,
   `--mh-accent`, `--mh-accent-text`, `--mh-brand-fill`, the lifecycle colours
   `--mh-state-*`, and so on.

3. **Data**, for charts: `--mh-data-a` and `--mh-data-b` (alternating jobs),
   `--mh-data-hatch`, `--mh-data-match` and `--mh-data-select`.

```css
/* Rebrand: override the palette on :root, unlayered */
:root {
  --mh-brand: #3c6e78;
  --mh-signal: #e9ac78;
  --mh-cut-scale: 0.5;
}
```

Themes: `data-mh-theme="ink"` (dark, the default), `"paper"` (light) or
`"auto"` (follows the OS). The attribute works on any element, and roles are
recomputed inside that scope. A scope can also carry its own palette
overrides. Custom properties resolve `var()` and `light-dark()` where they
are declared, so put palette overrides on `:root` or on an element that also
has `data-mh-theme`. Don't redefine derived roles with `light-dark()` on an
element outside a themed scope.

All rules live in the `mh.tokens`, `mh.base` and `mh.components` layers, so
any unlayered rule in your app overrides them without `!important`.

## Components

| Class or module | What it is |
| --- | --- |
| `.mh-plate` | Chamfered keyline and fill. Corners `--tl --tr --br --bl --tl-br --all` (default tr-bl), depths `--xs --sm --lg`, fills `--ground --raised --accent --brand --hatch`. Set `--mh-plate-fill` and `--mh-plate-keyline` directly for anything else. |
| `.mh-button` | Octagon action with a keyline sweep on hover. Variants `--secondary --brand --ghost`, sizes `--sm --lg`. `aria-busy="true"` shows a radar sweep and pulsing cells, and `disabled` shows a hatch. |
| `.mh-tag`, `.mh-status`, `.mh-lamp` | Labels. `data-status` follows `ActionStatus`: open, claimed, collected, delivering, delivered, settled, resolved, disputed, expired, cancelled. Disputed, expired and cancelled are hatched, so they read without colour. |
| `.mh-field` | Input or select in an octagon frame, with `__prefix` and `__suffix`. |
| `.mh-table` | Dense mono rows. Use `__num` for right-aligned figures and `aria-selected` for the selected row. |
| `.mh-route`, `.mh-endpoint` | The two endpoint SSUs of a Transfer, with vaulted or leased mode. The link between them is schematic and makes no travel-path claim. |
| `.mh-track` | Lifecycle as interlocking plates, with `data-step="done|current|todo"` and a hatched `__exit` for disputes, resolutions, expiries and cancellations. |
| `.mh-meter` | Time or quantity as a ladder of square cells: `--mh-meter-value` (0–1), `--mh-meter-cells`, and `data-tone="deadline|window|settled|alert"`. |
| `.mh-split` | Shares of one amount, such as the reward split in bps or escrow composition. |
| `.mh-job` | A Transfer card. [js/job.js](js/job.js) `renderJobCard(job, { now })` builds it from a `HaulAction`-shaped record. |
| `.mh-stacks` | Countable stacks. [js/stacks.js](js/stacks.js) `renderStacks(el, options)` is described below. |
| `.mh-icon`, `.mh-identicon` | 7 × 7 pixel icons and 5 × 5 mirrored identicons. [js/icons.js](js/icons.js) `icon(name)` and `identicon(seed)` build them. |
| `.mh-iconbtn`, `.mh-seg`, `.mh-link`, `.mh-kbd` | Icon button, segmented control, text action, keyboard hint. |
| `.mh-check`, `.mh-toggle`, `.mh-range`, `.mh-stepper`, `.mh-select` | Checkbox and radio, switch, cell-ladder slider, number stepper, select. |
| `.mh-topbar`, `.mh-navlist`, `.mh-wallet`, `.mh-tabs`, `.mh-crumbs`, `.mh-menu`, `.mh-pager` | Top bar with an interlocking nav, wallet chip, tabs, breadcrumbs, menu, pager. `.mh-count` and `.mh-badge-wrap` add counts. |
| `.mh-stat`, `.mh-spark`, `.mh-kv`, `.mh-id`, `.mh-countdown` | Stat tile with a cell sparkline, key–value list with leaders, ID or address chip with copy, live countdown. |
| `.mh-network`, `.mh-ssu`, `.mh-nodes`, `.mh-feed` | Network card, SSU card, node strip (circles only for nodes), protocol event feed. |
| `.mh-toast`, `.mh-banner`, `.mh-notice`, `.mh-dialog`, `.mh-tip` | Notifications in six tones (info, ok, warn, alert, accent, brand). [js/toast.js](js/toast.js) `createToaster()` manages a live region, and timers pause on hover and focus. |
| `.mh-txflow`, `.mh-spinner`, `.mh-busybar`, `.mh-skel`, `.mh-empty` | Transaction steps, cell spinner, indeterminate bar, skeletons, empty states. |
| `.mh-scan`, `.mh-brackets`, `.mh-gridfield`, `.mh-ticker`, `.mh-rule`, `.mh-dither`, `.mh-crosshair`, `.mh-glow`, `.mh-reveal`, `.mh-draw` | Effects and decorations. All motion stops under `prefers-reduced-motion`. |

### Behaviour

[js/behaviors.js](js/behaviors.js) `enhance(root)` wires markup that declares
behaviour with data attributes, and returns a cleanup function:

| Attribute | Behaviour |
| --- | --- |
| `data-mh-copy="text"` | Copies to the clipboard, falling back to selecting the text. Briefly shows a tick. |
| `data-mh-tabs` | Tabs with arrow, Home and End keys, using `aria-selected` and `aria-controls` panels. |
| `data-mh-menu` | Menu trigger with `aria-controls`. Arrow keys move between items, and Escape or a click outside closes it. |
| `data-mh-dialog-open="id"` / `data-mh-dialog-close` | Opens or closes a native `<dialog>` as a modal. A backdrop click closes it. |
| `data-mh-dismiss` | Removes the closest `[data-mh-dismissible]` with an exit animation. |
| `data-mh-countdown="ms or ISO"` | Live countdown. `data-warn-under` and `data-alert-under` (ms) set its tone. |
| `data-mh-stepper` | Number input with `[data-step="-1"]` and `[data-step="1"]` buttons, respecting min, max and step. |

Escape hides an open tooltip without moving focus.

### Stacks

Every square is a fixed quantity and every item is one contiguous run, so a
band made of many small jobs looks busy instead of thin. Columns are bands
of a metric, or any grouping you choose. An optional strip places every item
on a true scale against a movable lens threshold.

```js
import { renderStacks } from "./ui/js/stacks.js";

const board = renderStacks(el, {
  title: "Open board · reward rate",
  items: jobs,
  id: (job) => job.id,
  size: (job) => job.units,                 // what a square counts
  unit: { per: 100, label: "100 u" },       // one square = 100 units
  metric: (job) => job.reward / job.units,  // orders stacks and places the strip
  groups: [
    { key: "bulk", label: "Bulk", code: "< 5 CR/u", range: [0, 5] },
    { key: "express", label: "Express", code: "≥ 20 CR/u", range: [20, Infinity] },
  ],
  // or groupOf: (job, metric) => job.status, to group by anything
  lens: { value: 12, min: 0, max: 30, step: 0.5, label: "Floor" },
  match: (job, lens, metric) => metric >= lens,
  hazard: (job) => job.risk ?? null,        // a string becomes the row's note
  strip: { domain: [0, 30], ticks: [0, 10, 20, 30] },
  onSelect: (job) => openJob(job),
});
board.select("MH-0246");
```

Other options are `perRow` (default 12), `busyAt` (the number of items that
marks a column busy, default 4), `sizeFormat`, `metricFormat`, `sizeUnit`,
`matchLabel`, `hazardLabel`, `orderLabels` and `itemLabel`. To recolour
matches, for example to mark the viewer's own hauls in the brand colour,
set `--mh-data-match` on a container.

Grid squares and strip bars are `aria-hidden`. Each item is also listed as a
button row with its id, metric, size and notes, which is the accessible path
for selection.

## Files

```
ui/
  minehaul-ui.css     entry: layer order + imports
  tokens.css          palette, roles, data, shape, type, space
  base.css            .mh-root and text roles
  components/*.css    one file per component family
  js/stacks.js        renderStacks()
  js/job.js           renderJobCard(), trackHtml(), meterHtml(), helpers
  js/icons.js         icon(), identicon()
  js/behaviors.js     enhance(): data-mh-* behaviour
  js/toast.js         createToaster()
  demo/               fictional jobs, networks, SSUs and events; specimen script and styles
  stories/            Storybook stories
  .storybook/         Storybook config: toolbar globals, AWAR manager theme
  index.html          specimen
  NOTICE              third-party attribution
```

## Credits

Plate geometry, the button sweep and the interlocking seam are adapted from
the EVE Frontier Builders Program UI kit (MIT, © Fenris Creations). See
[NOTICE](NOTICE). No fonts, logos or colour tokens are taken from it.
