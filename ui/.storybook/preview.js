import "../minehaul-ui.css";
import "./preview.css";
import { awar } from "./theme.js";

export const PALETTES = {
  awar: { ink: "#171716", "ink-soft": "#242321", brand: "#873a3c", "brand-deep": "#63282b", signal: "#ff8d3a", paper: "#f2eee6", "paper-muted": "#d6d0c5" },
  console: { ink: "#101519", "ink-soft": "#1c252c", brand: "#3c6e78", "brand-deep": "#24434a", signal: "#e9ac78", paper: "#e6ecee", "paper-muted": "#9aa8b0" },
  frontier: { ink: "#0b0b0b", "ink-soft": "#171716", brand: "#a1270b", "brand-deep": "#460e04", signal: "#ff4700", paper: "#fafae5", "paper-muted": "#9e9e91" },
};

/* Applies the toolbar globals to the canvas document */
const withGlobals = (story, { globals }) => {
  const root = document.documentElement;
  root.dataset.mhTheme = globals.mhTheme ?? "ink";
  const palette = PALETTES[globals.palette] ?? PALETTES.awar;
  for (const [key, value] of Object.entries(palette)) root.style.setProperty(`--mh-${key}`, value);
  root.style.setProperty("--mh-cut-scale", globals.cut ?? "1");
  document.body.classList.add("mh-root");
  return story();
};

/** @type { import('@storybook/html-vite').Preview } */
const preview = {
  tags: ["autodocs"],
  decorators: [withGlobals],
  globalTypes: {
    mhTheme: {
      description: "Minehaul theme",
      toolbar: { title: "Theme", icon: "mirror", items: [{ value: "ink", title: "Ink (dark)" }, { value: "paper", title: "Paper (light)" }], dynamicTitle: true },
    },
    palette: {
      description: "Palette preset",
      toolbar: { title: "Palette", icon: "paintbrush", items: [{ value: "awar", title: "AWAR" }, { value: "console", title: "Minehaul console" }, { value: "frontier", title: "Frontier builders" }], dynamicTitle: true },
    },
    cut: {
      description: "Chamfer scale",
      toolbar: { title: "Chamfer", icon: "component", items: [{ value: "1", title: "Chamfer 1×" }, { value: "0", title: "Square (AWAR)" }, { value: "0.5", title: "Chamfer 0.5×" }, { value: "1.5", title: "Chamfer 1.5×" }], dynamicTitle: true },
    },
  },
  initialGlobals: { mhTheme: "ink", palette: "awar", cut: "1" },
  parameters: {
    layout: "padded",
    backgrounds: { disable: true },
    controls: { expanded: true, sort: "requiredFirst" },
    docs: { theme: awar, codePanel: true },
    a11y: { test: "todo" },
    options: {
      storySort: {
        order: ["Introduction", "Foundations", ["Colors", "Typography", "Space & shape", "Icons", "Motion"], "Actions", "Inputs", "Navigation", "Display", "Data", "Feedback", "Effects", "Pages"],
      },
    },
  },
};

export default preview;
