import { render, describe, icon } from "../_lib.js";
import { NETWORK_DETAIL, SSUS, EVENTS } from "../../demo/network.js";
import { nodesHtml, networkCard, ssuCard, feedHtml } from "./_network.js";

export default {
  title: "Display/Network",
  parameters: describe(
    "Network-level display: the network card (configuration, figures, endpoint nodes), the node strip, SSU cards with owner and lease, the protocol activity feed and the adapter list. Circles appear only here, for network nodes, as AWAR's design rules ask.",
  ),
};

export const NetworkCard = {
  name: "Network card",
  parameters: describe(
    null,
    "`.mh-network` on a large plate. A paused network (`data-paused`) takes a hatched fill and a warning keyline, and explains what pausing does: it blocks new claims, but existing hauls can still finish and settle.",
  ),
  argTypes: { network: { control: "inline-radio", options: NETWORK_DETAIL.map((n) => n.tag) } },
  args: { network: "MRD" },
  render: ({ network }) => render(`<div style="max-width: 640px">${networkCard(NETWORK_DETAIL.find((n) => n.tag === network))}</div>`),
};

export const AllNetworks = {
  name: "All networks",
  render: () => render(`<div class="sb-split">${NETWORK_DETAIL.map(networkCard).join("")}</div>`),
};

export const NodeStrip = {
  name: "Node strip",
  parameters: describe(
    null,
    "`.mh-nodes`: a schematic of a network's endpoints, not a map. Vaulted SSUs are solid rings, leased ones dashed in the warning colour, a live node pings in the signal colour, and an offline node is hatched. The dashed links carry no travel-path claim.",
  ),
  render: () =>
    render(`<div class="sb-stack">${NETWORK_DETAIL.map((n) => `<div class="sb-section"><span class="mh-label">${n.name}</span>${nodesHtml(n.ssus)}</div>`).join("")}</div>`),
};

export const SsuCards = {
  name: "SSU cards",
  parameters: describe(
    null,
    "`.mh-ssu`: one registered endpoint (`RegisteredSsu`). Vaulted SSUs keep their OwnerCap in the DAO vault; leased ones show the lease as a cell meter that turns to alert in its last quarter, because a lapsed lease fails admission at claim time.",
  ),
  render: () => render(`<div class="sb-grid" style="--sb-min: 250px">${Object.keys(SSUS).map(ssuCard).join("")}</div>`),
};

export const ActivityFeed = {
  name: "Activity feed",
  parameters: describe(
    null,
    "`.mh-feed`: protocol events from `minehaul_core::events`, newest first. The mark takes the lifecycle colour of the event; expiries, cancellations and revocations are hatched. `data-new` blinks the mark three times for an event that just arrived. Delivery and settlement are separate events and must not be counted as two jobs.",
  ),
  render: () => render(`<div style="max-width: 640px">${feedHtml(EVENTS)}</div>`),
};

export const Adapters = {
  name: "Adapter list",
  parameters: describe(
    null,
    "Delivery adapters registered to a network. There is no production delivery adapter yet, so the only active one is marked test-only; revoked adapters use the hatched void style.",
  ),
  render: () => {
    const rows = NETWORK_DETAIL.flatMap((n) => n.adapters.map((a) => ({ ...a, network: n })));
    return render(`<div class="mh-table-scroll"><table class="mh-table" style="max-width: 760px">
      <thead><tr><th>Adapter</th><th>Network</th><th>Auth object</th><th>Status</th></tr></thead>
      <tbody>${rows
        .map(
          (a) => `<tr><td style="font-family: var(--mh-font-body)">${icon("adapter")} ${a.name}</td><td>${a.network.tag}</td><td class="mh-table__id">${a.id}</td>
          <td>${a.status === "revoked"
            ? `<span class="mh-plate mh-plate--xs mh-status" data-status="cancelled">Revoked</span>`
            : `<span class="mh-plate mh-plate--xs mh-status" data-status="delivered">Test only</span>`}</td></tr>`,
        )
        .join("")}</tbody>
    </table></div>`);
  },
};
