---
version: alpha
name: Minehaul
description: A freight operations console for independent EVE Frontier haulers.
colors:
  background: '#101519'
  sidebar: '#0d1114'
  surface: '#151c21'
  raised: '#1c252c'
  primary: '#c6dde1'
  text: '#e6ecee'
  muted: '#9aa8b0'
  border: '#2b353c'
  accent: '#e9ac78'
  success: '#9bc9b0'
  danger: '#efa5a1'
  on-primary: '#152328'
  scrollbar: '#52616b'
typography:
  body:
    fontFamily: "Barlow, Arial, sans-serif"
  display:
    fontFamily: "Barlow Condensed, Arial Narrow, Arial, sans-serif"
  mono:
    fontFamily: "IBM Plex Mono, monospace"
rounded:
  DEFAULT: '4px'
spacing:
  section-gap: '30px'
  page-max: '1600px'
---

# Minehaul design system

## Overview

A cargo dispatch console, grounded in orbital infrastructure and freight manifests. English-speaking EVE Frontier players compare and claim funded Transfer jobs. Product register: dense enough for repeated use, with the endpoint diagram providing the one expressive moment. Demo data only. The repository README and ADRs 0004/0005 govern domain semantics. There was no existing frontend or sibling workflow.

The signature is a quiet orbital schematic, combining registered storage nodes and cargo connections without suggesting a verified travel path. Avoid neon gaming HUD clutter, generic financial charts, marketing claims, and invented production readiness.

Runtime CSS variables in `dist/styles.css` own tokens. This file mirrors the exact values. `colors.KEY` maps to `--color-KEY`; typography maps to `--font-body`, `--font-display`, and `--font-mono`; radius maps to `--radius`; spacing maps to `--section-gap` and `--page-max`. Shared controls consume those variables. Keep this mapping synchronized.

## Colors

Graphite surfaces, pale mineral blue actions, muted copper accents, and soft green lifecycle indicators. Text and state labels carry meaning in addition to color. The sole theme is dark; forced colors preserve system control boundaries. Diagram primitives use illustrative colors outside the semantic UI token set.

## Typography

Barlow Condensed gives headlines the proportions of industrial labeling. Barlow handles body copy and controls. IBM Plex Mono is reserved for IDs, amounts, and quiet technical captions. Display 36–42px, section titles 17px, body 14px, dense tabular metadata 10–12px. External Google Fonts have local fallbacks; the layout must remain usable when unavailable.

## Layout

Desktop: 228px navigation rail, 80px header, 36px page margins. A network schematic leads into an inline statistical summary and bounded eight-job table. At 960px the rail becomes compact; at 680px it becomes top navigation and controls stack. The table owns horizontal overflow; the document owns vertical scrolling. No arbitrary pagination for eight finite fixture jobs.

## Elevation & Depth

Use tonal surfaces and fine borders. Shadows belong to dialogs and temporary notifications. No shadows on table rows or statistics.

## Shapes

4px control and panel corners. Small circular dots identify networks and status. The diagram alone uses orbital shapes.

## Components

Shared button classes provide outline and primary variants, visible hover/focus, disabled styling, and active feedback. Navigation has explicit current-page semantics. Search has an accessible clear action. Native selects intentionally use operating-system popup behavior. The native dialog provides modal semantics, keyboard trapping and Escape; shared code restores focus. Notifications use one live region. Local data needs no simulated loading indicator.

Tables share render, filter and sort behavior between job board and My hauls. Empty states explain how to recover. Error messaging appears beside the blocked action. Read-only networks lead to filtered jobs. Inline SVG icons are decorative alongside text. Respect reduced motion; use only short state transitions.

## Do's and Don'ts

- Do show collateral, net hauler reward, and destination before a simulated claim.
- Do distinguish delivered from settled, and label demo time skipping explicitly.
- Don't claim a real wallet, chain connection, verified route, or production delivery proof.
- Don't add nonfunctional controls or unsupported Inject/Extract listings.
