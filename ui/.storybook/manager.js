import { addons } from "storybook/manager-api";
import { awar } from "./theme.js";

// One tree, ordered by storySort, so single-level titles don't float above groups
addons.setConfig({ theme: awar, sidebar: { showRoots: false } });
