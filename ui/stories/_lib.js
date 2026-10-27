/* Story helpers. Not part of the library. */
import { enhance } from "../js/behaviors.js";

export { icon, identicon } from "../js/icons.js";

/** Renders an HTML string into a container and wires data-mh-* behaviour. */
export function render(html, { className = "", style = "" } = {}) {
  const el = document.createElement("div");
  if (className) el.className = className;
  if (style) el.style.cssText = style;
  el.innerHTML = html;
  enhance(el);
  return el;
}

/** Runs fn once the element is in the document (for measurements and charts). */
export function whenAttached(el, fn) {
  if (el.isConnected) return fn(el);
  const id = setInterval(() => {
    if (el.isConnected) {
      clearInterval(id);
      fn(el);
    }
  }, 16);
  setTimeout(() => clearInterval(id), 5000);
}

export const int = new Intl.NumberFormat("en-US", { maximumFractionDigits: 0 });

/** Docs description shorthand */
export const describe = (component, story) => ({
  docs: { description: { ...(component ? { component } : {}), ...(story ? { story } : {}) } },
});
