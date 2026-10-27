/**
 * Toasts in a polite live region. Alert-toned toasts use role="alert".
 * Timers pause while the toast is hovered or focused, so people who read
 * slowly or use a keyboard don't lose the message.
 *
 * @example
 * const toaster = createToaster();
 * toaster.toast({ tone: "ok", title: "Claimed MH-0248", text: "9,500 CR collateral posted." });
 * toaster.toast({ tone: "alert", title: "Delivery rejected", duration: 0,
 *                 action: { label: "View job", onClick: () => open("MH-0246") } });
 */
import { icon } from "./icons.js";

const ICONS = { info: "info", ok: "check", warn: "warning", alert: "alert", accent: "bell", brand: "shield" };

const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);

export function createToaster({ region, label = "Notifications" } = {}) {
  let host = region;
  if (!host) {
    host = document.createElement("section");
    host.className = "mh-toaster";
    document.body.append(host);
  }
  host.setAttribute("aria-label", label);
  host.setAttribute("aria-live", "polite");
  host.classList.add("mh-toaster");

  function toast({ tone = "info", title, text = "", action, duration = 6000, iconName } = {}) {
    const el = document.createElement("div");
    el.className = "mh-plate mh-toast";
    el.dataset.tone = tone;
    el.setAttribute("role", tone === "alert" ? "alert" : "status");
    el.style.setProperty("--mh-toast-duration", `${duration}ms`);
    el.innerHTML = `<span class="mh-toast__icon">${icon(iconName ?? ICONS[tone] ?? "info")}</span>
      <div class="mh-toast__body">
        <span class="mh-toast__title">${esc(title)}</span>
        ${text ? `<p class="mh-toast__text">${esc(text)}</p>` : ""}
        ${action ? `<div class="mh-toast__actions"><button type="button" class="mh-link" data-toast-action>${esc(action.label)}</button></div>` : ""}
      </div>
      <button type="button" class="mh-toast__close" aria-label="Dismiss notification">${icon("cross")}</button>
      ${duration > 0 ? `<span class="mh-toast__timer" aria-hidden="true"></span>` : ""}`;

    let remaining = duration;
    let startedAt = 0;
    let timer = 0;
    // Hover and focus pause independently; the timer resumes only when neither holds
    let hovered = false;
    let focused = false;
    const start = () => {
      if (duration <= 0 || timer || hovered || focused) return;
      startedAt = performance.now();
      timer = setTimeout(dismiss, remaining);
    };
    const pause = () => {
      if (!timer) return;
      clearTimeout(timer);
      timer = 0;
      remaining -= performance.now() - startedAt;
    };

    function dismiss() {
      clearTimeout(timer);
      if (el.hasAttribute("data-leaving")) return;
      el.setAttribute("data-leaving", "");
      const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
      setTimeout(() => el.remove(), reduce ? 0 : 220);
    }

    el.addEventListener("mouseenter", () => { hovered = true; pause(); });
    el.addEventListener("mouseleave", () => { hovered = false; start(); });
    el.addEventListener("focusin", () => { focused = true; pause(); });
    el.addEventListener("focusout", (e) => {
      if (el.contains(e.relatedTarget)) return;
      focused = false;
      start();
    });
    el.querySelector(".mh-toast__close").addEventListener("click", dismiss);
    el.querySelector("[data-toast-action]")?.addEventListener("click", () => {
      action.onClick?.();
      dismiss();
    });

    host.append(el);
    start();
    return { dismiss, element: el };
  }

  return { toast, element: host, clear: () => host.replaceChildren() };
}
