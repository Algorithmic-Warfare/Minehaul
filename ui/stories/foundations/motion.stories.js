import { render, describe, icon } from "../_lib.js";

export default {
  title: "Foundations/Motion",
  parameters: describe(
    "Motion is slow and instrumental: sweeps, lamps, scans. Two durations (`--mh-fast` 140ms, `--mh-slow` 550ms) and one easing (`--mh-ease`, a quick-out cubic). Everything stops under `prefers-reduced-motion`.",
  ),
};

const MOTION_CSS = `<style>
  .sb-lane { position: relative; height: 34px; border: 1px solid var(--mh-line); background: var(--mh-bg); }
  .sb-lane i { position: absolute; left: 4px; top: 4px; width: 24px; height: 24px; background: var(--mh-accent); clip-path: polygon(6px 0, 100% 0, 100% calc(100% - 6px), calc(100% - 6px) 100%, 0 100%, 0 6px); transition: left var(--_d) var(--_e); }
  .sb-lane:hover i, .sb-lane:focus-visible i { left: calc(100% - 28px); }
  .sb-lane:focus-visible { outline: 2px solid var(--mh-accent); outline-offset: 2px; }
</style>`;

const lane = (label, d, e) => `<div class="sb-section" style="gap: 6px">
  <span class="mh-label">${label}</span>
  <div class="sb-lane" tabindex="0" role="img" aria-label="${label}: hover or focus to play" style="--_d: ${d}; --_e: ${e}"><i></i></div>
</div>`;

export const Tokens = {
  parameters: describe(null, "Hover or focus a lane to play it."),
  render: () =>
    render(`${MOTION_CSS}<div class="sb-stack" style="max-width: 640px">
      ${lane("--mh-fast · --mh-ease", "var(--mh-fast)", "var(--mh-ease)")}
      ${lane("--mh-slow · --mh-ease", "var(--mh-slow)", "var(--mh-ease)")}
      ${lane("--mh-slow · linear (for comparison)", "var(--mh-slow)", "linear")}
      <p class="sb-caption"><code>--mh-fast</code> for colour and keyline changes, <code>--mh-slow</code> for anything that travels: sweeps, thumbs, underlines, entrances.</p>
    </div>`),
};

export const Interactions = {
  parameters: describe(null, "The motion each control uses. Hover, focus and click them."),
  render: () =>
    render(`<div class="sb-split">
      <section class="sb-section">
        <span class="mh-label">Keyline sweep · hover the button</span>
        <div class="sb-row"><button type="button" class="mh-plate mh-button mh-button--lg"><span class="mh-button__label">Claim job</span></button>
        <button type="button" class="mh-plate mh-button mh-button--lg mh-button--secondary"><span class="mh-button__label">Manifest</span></button></div>
      </section>
      <section class="sb-section">
        <span class="mh-label">Lamp glow · hover the nav items</span>
        <ul class="mh-navlist">
          <li><a class="mh-plate mh-navitem" href="#board" aria-current="page"><span class="mh-lamp"></span>Board</a></li>
          <li><a class="mh-plate mh-navitem" href="#hauls"><span class="mh-lamp"></span>My hauls</a></li>
          <li><a class="mh-plate mh-navitem" href="#networks"><span class="mh-lamp"></span>Networks</a></li>
        </ul>
      </section>
      <section class="sb-section">
        <span class="mh-label">Toggle thumb · click</span>
        <label class="mh-toggle"><input type="checkbox" role="switch" checked> Notify me when a dispute opens</label>
      </section>
      <section class="sb-section">
        <span class="mh-label">Tab underline · click a tab</span>
        <div class="mh-tabs" data-mh-tabs>
          <div class="mh-tabs__list" role="tablist" aria-label="Motion demo tabs">
            <button type="button" class="mh-tab" role="tab" aria-selected="true" aria-controls="mo-open" id="mo-t1">Open <span class="mh-count">11</span></button>
            <button type="button" class="mh-tab" role="tab" aria-selected="false" aria-controls="mo-live" id="mo-t2">Live <span class="mh-count">5</span></button>
            <button type="button" class="mh-tab" role="tab" aria-selected="false" aria-controls="mo-ended" id="mo-t3">Ended</button>
          </div>
          <div class="mh-tabpanel sb-caption" role="tabpanel" id="mo-open" aria-labelledby="mo-t1">11 jobs listed across three networks.</div>
          <div class="mh-tabpanel sb-caption" role="tabpanel" id="mo-live" aria-labelledby="mo-t2" hidden>5 jobs claimed, collected or in their dispute window.</div>
          <div class="mh-tabpanel sb-caption" role="tabpanel" id="mo-ended" aria-labelledby="mo-t3" hidden>Settled, resolved, expired and cancelled jobs.</div>
        </div>
      </section>
      <section class="sb-section">
        <span class="mh-label">Loading · radar sweep and cells</span>
        <div class="sb-row"><button type="button" class="mh-plate mh-button" aria-busy="true"><span class="mh-button__label">Claiming</span><span class="mh-button__cells" aria-hidden="true"><i></i><i></i><i></i></span></button>
        <span class="mh-spinner mh-spinner--lg" role="status" aria-label="Loading"><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i></span></div>
      </section>
      <section class="sb-section">
        <span class="mh-label">Live node · pulse</span>
        <ul class="mh-nodes" style="max-width: 280px">
          <li><span class="mh-node" data-live></span><b>SSU-01</b></li>
          <li><span class="mh-node"></span><b>SSU-02</b></li>
          <li><span class="mh-node" data-mode="leased"></span><b>SSU-03</b></li>
        </ul>
      </section>
    </div>`),
};

export const ReducedMotion = {
  name: "Reduced motion",
  parameters: describe(null, "What changes when the OS asks for reduced motion."),
  render: () =>
    render(`<div class="mh-plate mh-notice" data-tone="info" style="max-width: 680px">
      <span class="mh-notice__icon">${icon("info")}</span>
      <span class="mh-notice__title">prefers-reduced-motion: reduce</span>
      <p>Inside <code>.mh-root</code> every transition and animation is cut. Spinners and busy bars hold a static state, the scan line and ticker stop (the ticker wraps instead), reveals render in place, and toasts keep their timer in script so they still dismiss. State changes stay visible through colour, keyline weight and hatching, never through motion alone.</p>
    </div>`),
};
