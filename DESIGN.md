# grape-oas website design

## Theme
Light editorial typography for Ruby developers evaluating a documentation gem. A large serif headline sits beside an actual, tested Ruby example.

## Palette
Paper: oklch(98% .006 320). Ink: oklch(24% .023 320). Grape: oklch(43% .115 320). Muted: oklch(46% .025 320). Wash: oklch(94% .02 320). Lines: oklch(86% .017 320).

## Typography
Georgia gives the project an approachable reference-book voice without external fonts. Arial handles explanations and navigation. System monospace handles Ruby and numeric details. Headlines use tight tracking; prose uses natural wrapping.

## Components
Cardless sections, hairline dividers, a dark code surface, and semantic tables. Links have visible focus outlines. The primary link uses a 3px radius and subtle pointer press feedback.

## Layout
1160px maximum width, 96px combined desktop gutters, asymmetric hero content, and a two-column reference layout. Spacing follows content hierarchy, with 30px to 90px section gaps.

## Depth
Background steps distinguish code, output, and table headings. No shadows, glass, or decorative gradients.

## Guardrails
Show real examples and measurements. Avoid performance claims beyond the measured workload. Keep version labels visible. Keep reference docs on GitHub. Never add tracking as visual polish.

## Responsive behavior
At 960px reduce gaps. At 700px stack the hero and guide, wrap navigation, and keep code and tables in independently scrollable containers. No page-wide horizontal overflow.

## Future changes
Use the palette above, Georgia headlines at 44px/1.14 with -0.035em tracking, and Arial body text at 17px/1.65. Add a reference section as a divider and text, not a shadow card. New benchmark tables retain tabular numbers, explicit units, captions, and row headings.
