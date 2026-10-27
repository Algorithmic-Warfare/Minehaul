/**
 * Pixel icons on a 7 × 7 grid ("#" filled, "." empty), compiled to a single
 * SVG path with crisp edges. Size them at multiples of 7px (14, 21, 28) so
 * every cell lands on whole pixels. The grid technique follows the Builders
 * Program Icon (MIT, Fenris Creations; see ui/NOTICE); the glyphs are new.
 *
 * @example
 * el.innerHTML = icon("cargo");                       // decorative
 * el.innerHTML = icon("warning", { label: "Risk" });  // meaningful
 */

export const GLYPHS = {
  check: [".......", "......#", ".....#.", "#...#..", ".#.#...", "..#....", "......."],
  cross: ["#.....#", ".#...#.", "..#.#..", "...#...", "..#.#..", ".#...#.", "#.....#"],
  plus: ["...#...", "...#...", "...#...", "#######", "...#...", "...#...", "...#..."],
  minus: [".......", ".......", ".......", "#######", ".......", ".......", "......."],
  "caret-down": [".......", ".......", "#.....#", ".#...#.", "..#.#..", "...#...", "......."],
  "caret-right": [".......", "..#....", "...#...", "....#..", "...#...", "..#....", "......."],
  "arrow-right": ["...#...", "....#..", ".....#.", "#######", ".....#.", "....#..", "...#..."],
  "arrow-left": ["...#...", "..#....", ".#.....", "#######", ".#.....", "..#....", "...#..."],
  external: ["...####", ".....##", "....#.#", "...#..#", "..#....", ".#.....", "#......"],
  menu: [".......", "#######", ".......", "#######", ".......", "#######", "......."],
  dots: [".......", ".......", ".......", "#..#..#", ".......", ".......", "......."],
  search: [".###...", "#...#..", "#...#..", "#...#..", ".###...", "....##.", ".....##"],
  filter: ["#######", ".#...#.", "..#.#..", "...#...", "...#...", "...#...", "...#..."],
  refresh: ["..####.", ".#...##", "#...###", "#......", "#.....#", ".#...#.", "..###.."],
  copy: ["####...", "#..#...", "#.#####", "#.#...#", "###...#", "..#...#", "..#####"],
  info: ["..###..", ".......", "..##...", "...#...", "...#...", "...#...", "..###.."],
  warning: ["...#...", "..#.#..", "..#.#..", ".#.#.#.", ".#...#.", "#..#..#", "#######"],
  alert: ["#######", "#..#..#", "#..#..#", "#..#..#", "#.....#", "#..#..#", "#######"],
  bell: ["...#...", "..###..", ".#...#.", ".#...#.", ".#...#.", "#######", "...#..."],
  clock: [".#####.", "#..#..#", "#..#..#", "#..##.#", "#.....#", "#.....#", ".#####."],
  hourglass: ["#######", ".#...#.", "..#.#..", "...#...", "..#.#..", ".#.#.#.", "#######"],
  cargo: ["#######", "#..#..#", "#######", "#.....#", "#.###.#", "#.....#", "#######"],
  node: ["..###..", ".#...#.", "#..#..#", "#.###.#", "#..#..#", ".#...#.", "..###.."],
  route: ["##.....", "##.....", "..#....", "...#...", "....#..", ".....##", ".....##"],
  stacks: ["##.##.#", "##.##.#", ".......", "##.##.#", "##.##.#", ".......", "##.##.."],
  wallet: [".#####.", "#......", "#######", "#....##", "#....##", "#......", "#######"],
  coin: [".#####.", "#.....#", "#.###.#", "#.#...#", "#.###.#", "#.....#", ".#####."],
  lock: ["..###..", ".#...#.", ".#...#.", "#######", "#..#..#", "#..#..#", "#######"],
  shield: ["#######", "#.....#", "#.....#", "#.....#", ".#...#.", "..#.#..", "...#..."],
  user: ["..###..", "..###..", "...#...", ".#####.", "...#...", "..#.#..", ".#...#."],
  pause: [".......", ".##.##.", ".##.##.", ".##.##.", ".##.##.", ".##.##.", "......."],
  play: [".#.....", ".##....", ".###...", ".####..", ".###...", ".##....", ".#....."],
  network: ["#..#..#", ".......", "..###..", "#.#.#.#", "..###..", ".......", "#..#..#"],
  adapter: ["..#.#..", "..#.#..", "#######", "#.....#", "#.....#", ".#...#.", "...#..."],
};

export const iconNames = Object.keys(GLYPHS);

const paths = Object.fromEntries(
  Object.entries(GLYPHS).map(([name, rows]) => [
    name,
    rows.flatMap((row, y) => [...row].map((c, x) => (c === "#" ? `M${x} ${y}h1v1h-1z` : ""))).join(""),
  ]),
);

const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);

/** An icon as an SVG string, in the current text colour. */
export function icon(name, { label, size, className = "" } = {}) {
  const d = paths[name];
  if (!d) throw new Error(`Unknown icon: ${name}`);
  const a11y = label ? `role="img" aria-label="${esc(label)}"` : `aria-hidden="true"`;
  const dim = size ? ` width="${size}" height="${size}"` : "";
  return `<svg class="mh-icon ${className}" viewBox="0 0 7 7" shape-rendering="crispEdges"${dim} ${a11y}><path d="${d}"/></svg>`;
}

/* ---------- Identicons ---------- */

// FNV-1a, enough to spread similar addresses apart
function hash(text) {
  let h = 0x811c9dc5;
  for (const c of String(text)) {
    h ^= c.charCodeAt(0);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h;
}

/**
 * A 5 × 5 mirrored pixel mark for an address or character id. Colours come
 * from tokens, so identicons follow the palette and theme.
 */
export function identicon(seed, { size = 28, label } = {}) {
  let h = hash(seed);
  const tone = ["var(--mh-signal)", "var(--mh-brand-fill)", "var(--mh-fg)"][h % 3];
  h = hash(h.toString(16) + seed);
  let d = "";
  for (let y = 0; y < 5; y++) {
    for (let x = 0; x < 3; x++) {
      if ((h >> (y * 3 + x)) & 1) {
        d += `M${x} ${y}h1v1h-1z`;
        if (x < 2) d += `M${4 - x} ${y}h1v1h-1z`;
      }
    }
  }
  const a11y = label ? `role="img" aria-label="${esc(label)}"` : `aria-hidden="true"`;
  return `<svg class="mh-identicon" viewBox="-1 -1 7 7" width="${size}" height="${size}" shape-rendering="crispEdges" ${a11y}><rect x="-1" y="-1" width="7" height="7" style="fill: var(--mh-surface-2)"/><path d="${d}" style="fill: ${tone}"/></svg>`;
}
