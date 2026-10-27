/**
 * Progressive enhancement for markup that declares behaviour with data
 * attributes. Call once per root; calling again on the same root is a no-op.
 *
 *   data-mh-copy="text"            copy button; sets data-copied briefly
 *   data-mh-tabs                   tab set: [role=tab] with aria-controls
 *   data-mh-menu                   menu trigger: aria-controls → menu element
 *   data-mh-dialog-open="id"       opens <dialog id> as a modal
 *   data-mh-dialog-close="value"   closes the enclosing dialog
 *   data-mh-dismiss                removes the closest [data-mh-dismissible]
 *   data-mh-countdown="ms|ISO"     live countdown; data-warn-under / data-alert-under in ms
 *   data-mh-stepper                number field with [data-step="-1|1"] buttons
 *
 * Escape hides an open tooltip without moving focus (WCAG 1.4.13).
 */
import { icon } from "./icons.js";

const bound = new WeakSet();

export function enhance(root = document) {
  if (bound.has(root)) return () => {};
  bound.add(root);

  const onClick = (event) => {
    const t = event.target;

    const copy = t.closest("[data-mh-copy]");
    if (copy) copyText(copy);

    const open = t.closest("[data-mh-dialog-open]");
    if (open) document.getElementById(open.dataset.mhDialogOpen)?.showModal();

    const close = t.closest("[data-mh-dialog-close]");
    if (close) close.closest("dialog")?.close(close.dataset.mhDialogClose || "");

    // A click on the backdrop lands on the dialog element itself
    if (t instanceof HTMLDialogElement && t.open) {
      const r = t.getBoundingClientRect();
      const inside = event.clientX >= r.left && event.clientX <= r.right && event.clientY >= r.top && event.clientY <= r.bottom;
      if (!inside) t.close("");
    }

    const dismiss = t.closest("[data-mh-dismiss]");
    if (dismiss) {
      const target = dismiss.closest("[data-mh-dismissible]");
      if (target) {
        target.setAttribute("data-leaving", "");
        setTimeout(() => target.remove(), matchMedia("(prefers-reduced-motion: reduce)").matches ? 0 : 220);
      }
    }

    const tab = t.closest('[data-mh-tabs] [role="tab"]');
    if (tab) selectTab(tab);

    const step = t.closest("[data-mh-stepper] [data-step]");
    if (step) stepBy(step);

    const trigger = t.closest("[data-mh-menu]");
    if (trigger) toggleMenu(trigger);
    else if (t.closest('[role="menuitem"]')) closeMenus(root);
    else if (!t.closest(".mh-menu")) closeMenus(root);
  };

  const onKey = (event) => {
    if (event.key === "Escape") {
      for (const a of root.querySelectorAll(".mh-tip-anchor:is(:hover, :focus-within)")) a.setAttribute("data-tip-hidden", "");
      const openMenu = root.querySelector("[data-mh-menu][aria-expanded='true']");
      if (openMenu) {
        closeMenus(root);
        openMenu.focus();
      }
    }
    const tab = event.target.closest?.('[data-mh-tabs] [role="tab"]');
    if (tab && ["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) {
      const tabs = [...tab.closest('[role="tablist"]').querySelectorAll('[role="tab"]')];
      const i = tabs.indexOf(tab);
      const next = { ArrowLeft: i - 1, ArrowRight: i + 1, Home: 0, End: tabs.length - 1 }[event.key];
      const target = tabs[(next + tabs.length) % tabs.length];
      event.preventDefault();
      target.focus();
      selectTab(target);
    }
    const item = event.target.closest?.('.mh-menu [role="menuitem"]');
    if (item && (event.key === "ArrowDown" || event.key === "ArrowUp")) {
      const items = [...item.closest(".mh-menu").querySelectorAll('[role="menuitem"]:not(:disabled)')];
      const i = items.indexOf(item) + (event.key === "ArrowDown" ? 1 : -1);
      event.preventDefault();
      items[(i + items.length) % items.length].focus();
    }
  };

  const onLeave = (event) => {
    const anchor = event.target.closest?.(".mh-tip-anchor");
    if (anchor) anchor.removeAttribute("data-tip-hidden");
  };

  root.addEventListener("click", onClick);
  root.addEventListener("keydown", onKey);
  root.addEventListener("mouseout", onLeave);
  root.addEventListener("focusout", onLeave);

  const timers = [...root.querySelectorAll("[data-mh-countdown]")].map(startCountdown);
  for (const tabs of root.querySelectorAll("[data-mh-tabs]")) {
    const current = tabs.querySelector('[role="tab"][aria-selected="true"]') ?? tabs.querySelector('[role="tab"]');
    if (current) selectTab(current);
  }

  return () => {
    root.removeEventListener("click", onClick);
    root.removeEventListener("keydown", onKey);
    root.removeEventListener("mouseout", onLeave);
    root.removeEventListener("focusout", onLeave);
    timers.forEach(clearInterval);
    bound.delete(root);
  };
}

async function copyText(button) {
  // A second click before the reset would save the check icon as the original
  if (button.hasAttribute("data-copied")) return;
  const text = button.dataset.mhCopy;
  try {
    await navigator.clipboard.writeText(text);
  } catch {
    // Clipboard refused (insecure context, sandbox): select the visible text instead
    const code = button.parentElement?.querySelector("code");
    if (code) getSelection()?.selectAllChildren(code);
  }
  button.setAttribute("data-copied", "");
  const before = button.innerHTML;
  button.innerHTML = icon("check");
  button.dispatchEvent(new CustomEvent("mh:copied", { bubbles: true, detail: { text } }));
  setTimeout(() => {
    button.removeAttribute("data-copied");
    button.innerHTML = before;
  }, 1400);
}

// Looks inside `scope` first, so behaviour works before the markup is attached
const byId = (scope, id) => (id && scope?.querySelector(`#${CSS.escape(id)}`)) || document.getElementById(id);

function selectTab(tab) {
  const list = tab.closest('[role="tablist"]');
  const set = tab.closest("[data-mh-tabs]");
  for (const t of list.querySelectorAll('[role="tab"]')) {
    const on = t === tab;
    t.setAttribute("aria-selected", String(on));
    t.tabIndex = on ? 0 : -1;
    const panel = byId(set, t.getAttribute("aria-controls"));
    if (panel) panel.hidden = !on;
  }
}

function toggleMenu(trigger) {
  const menu = byId(trigger.closest(".mh-menu-anchor"), trigger.getAttribute("aria-controls"));
  if (!menu) return;
  const open = trigger.getAttribute("aria-expanded") !== "true";
  closeMenus(document);
  trigger.setAttribute("aria-expanded", String(open));
  menu.hidden = !open;
  if (open) menu.querySelector('[role="menuitem"]:not(:disabled)')?.focus({ preventScroll: true });
}

function closeMenus(root) {
  for (const t of root.querySelectorAll("[data-mh-menu][aria-expanded='true']")) {
    t.setAttribute("aria-expanded", "false");
    const menu = byId(t.closest(".mh-menu-anchor"), t.getAttribute("aria-controls"));
    if (menu) menu.hidden = true;
  }
}

function stepBy(button) {
  const input = button.closest("[data-mh-stepper]").querySelector("input");
  const step = Number(input.step) || 1;
  const min = input.min === "" ? -Infinity : Number(input.min);
  const max = input.max === "" ? Infinity : Number(input.max);
  const next = Math.min(max, Math.max(min, (Number(input.value) || 0) + Number(button.dataset.step) * step));
  input.value = String(next);
  input.dispatchEvent(new Event("input", { bubbles: true }));
  input.dispatchEvent(new Event("change", { bubbles: true }));
}

const pad = (n) => String(n).padStart(2, "0");

/** Renders "05h 12m 44s" into a [data-mh-countdown] element and keeps it current. */
export function startCountdown(el) {
  const raw = el.dataset.mhCountdown;
  // An unparseable date counts as ended rather than rendering NaN
  const end = /^\d+$/.test(raw) ? Number(raw) : Date.parse(raw) || 0;
  const now = () => (el.dataset.now ? Number(el.dataset.now) + (Date.now() - started) : Date.now());
  const started = Date.now();
  const warn = Number(el.dataset.warnUnder ?? 0);
  const alert = Number(el.dataset.alertUnder ?? 0);
  const tick = () => {
    if (!el.isConnected && id) return clearInterval(id);
    const left = Math.max(0, end - now());
    const s = Math.floor(left / 1000);
    const d = Math.floor(s / 86400);
    const parts = d
      ? [[d, "d"], [Math.floor(s / 3600) % 24, "h"], [Math.floor(s / 60) % 60, "m"]]
      : [[Math.floor(s / 3600), "h"], [Math.floor(s / 60) % 60, "m"], [s % 60, "s"]];
    el.innerHTML = parts.map(([v, u]) => `<b>${pad(v)}</b><small>${u}</small>`).join("");
    el.toggleAttribute("data-ended", left === 0);
    el.dataset.tone = left > 0 && alert && left < alert ? "alert" : left > 0 && warn && left < warn ? "warn" : "";
    el.setAttribute("aria-label", left > 0 ? `${parts.map(([v, u]) => `${v}${u}`).join(" ")} left` : "Ended");
  };
  let id = 0;
  tick();
  id = setInterval(tick, 1000);
  return id;
}
