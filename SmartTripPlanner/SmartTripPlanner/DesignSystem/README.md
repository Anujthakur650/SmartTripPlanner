# Minimal Calm Design System

The SmartTrip Planner interface is powered by a minimal, calm design language optimised for SwiftUI. The tokens below are defined in `Theme.swift` and surfaced through the shared `AppEnvironment`.

## Color System

| Token | Light | Dark | Intended use |
| --- | --- | --- | --- |
| `primary` / `onPrimary` | Deep teal on white | Soft aqua on deep navy | Primary actions, highlights |
| `accent` / `onAccent` | Powder blue on white | Mist blue on near-black | Secondary accents, selection states |
| `background` | Whisper grey | Obsidian slate | App and surface backgrounds |
| `surface` | White | Graphite blue | Cards, panes, list rows |
| `surfaceMuted` | Mist grey | Deep teal grey | Chips, tags, quiet containers |
| `surfaceElevated` | Ice grey | Steel blue | Elevated cards and overlays |
| `textPrimary` | Midnight ink | Polar white | Headline and body text |
| `textSecondary` | Stone grey | Frost blue | Secondary text and captions |
| `success` / `onSuccess` | Forest green on white | Mint green on deep teal | Positive states |
| `warning` / `onWarning` | Golden amber on white | Honey gold on umber | Cautionary states |
| `error` / `onError` | Cranberry red on white | Rose quartz on oxblood | Error and destructive states |
| `info` / `onInfo` | Ocean blue on white | Sky blue on midnight | Informational surfaces |
| `border` & `outline` | Soft steel | Deep lagoon | Dividers, strokes, outlines |

Colors automatically resolve to the active `ColorScheme` via `DynamicColor`.

## Typography Scale (Rounded SF Pro)

| Token | Description |
| --- | --- |
| `largeTitle` | Hero headlines for section intros |
| `title` / `title2` | Prominent card or section titles |
| `headline` | Callouts and emphasis |
| `body` | Default reading size |
| `callout` | Supporting text with gentle hierarchy |
| `subheadline` | Secondary labels |
| `footnote` | Metadata, helper text |
| `caption` | Annotations, tag labels |
| `button` | Medium-weight CTAs |

## Spacing Scale

Spacing values are defined in points and surfaced via `theme.spacing`:

- `xxs` = 4
- `xs` = 8
- `s` = 12
- `m` = 16
- `l` = 20
- `xl` = 24
- `xxl` = 32

## Corner Radii

- `s` = 8 (chips and list rows)
- `m` = 12 (buttons, text inputs)
- `l` = 16 (cards)
- `xl` = 24 (full-width callouts)
- `pill` = 999 (tags and pills)

## Shadows

The `theme.shadows` scale provides tonal depth without overwhelming the calm aesthetic:

- `none` – flat surfaces
- `subtle` – resting elements
- `resting` – elevated cards
- `raised` – modal overlays

`Theme.ShadowToken` resolves the appropriate colour per scheme to preserve accessibility.

Use the shared `AppEnvironment` to access these tokens:

```swift
@EnvironmentObject private var appEnvironment: AppEnvironment
let theme = appEnvironment.theme
Text("Title")
    .font(theme.typography.title)
    .foregroundStyle(theme.colors.textPrimary.resolved(for: colorScheme))
```
