# Design system — first implementation

## Visual direction

Teach-back AI uses a warm, restrained clinical identity: parchment-like canvas, deep forest-green actions, muted sage surfaces, charcoal typography, and selective terracotta emphasis. The interface avoids cold hospital-blue defaults, decorative gradients, excessive cards, and artificial clinical imagery.

The visual language should feel calm and human while keeping clinical tasks precise and legible.

## Color tokens

| Token | Value | Intended use |
|---|---|---|
| Canvas | `#F7F5EF` | Main application background |
| Surface | `#FFFEFB` | Forms, panels, and content surfaces |
| Surface muted | `#EEF1E9` | Secondary surfaces and disabled controls |
| Ink | `#20342D` | Primary text |
| Ink muted | `#5C6D63` | Secondary text and metadata |
| Line | `#DDE4DA` | Borders and separators |
| Brand | `#205C47` | Primary actions and identity |
| Brand hover | `#174A39` | Primary action hover |
| Brand soft | `#E7F0E9` | Supportive backgrounds |
| Accent | `#A34E3C` | Selective emphasis and focus |
| Success | `#2D6B4B` | Confirmed states |
| Warning | `#7A4B11` | Attention states |
| Danger | `#9F3E36` | Errors and destructive states |

Selected foreground/background contrast ratios were calculated using WCAG relative luminance:

- Ink on canvas: 12.11:1.
- Muted text on canvas: 5.04:1.
- Brand on white: 7.83:1.
- Accent on white: 5.66:1.
- Warning on warning-soft: 6.45:1.
- Danger on danger-soft: 5.54:1.
- Success on success-soft: 5.51:1.

These values support the selected token pairs; they do not by themselves establish WCAG 2.2 AA conformance for the complete application.

## Typography

- Display headings use a restrained serif stack to create editorial distinction.
- Interface text uses a system sans-serif stack for predictable rendering and performance.
- Numeric values use tabular numerals where useful.
- Arabic receives an explicit system-font fallback; full Arabic typography and RTL validation remain a later localization task.

## Components implemented

- Button: primary, secondary, ghost, and danger variants; small, medium, and large sizes; disabled and focus states.
- Card: consistent surface, border, radius, and restrained shadow.
- Badge: neutral, success, warning, danger, and accent states.
- InputField and TextareaField: associated labels, hint/error descriptions, invalid state, and disabled state.
- PageHeader: consistent title hierarchy and optional actions.
- EmptyState: explicit zero-data messaging.
- ClinicianShell: responsive application frame, semantic navigation, account identity, and sign-out action.

## Accessibility foundations

- Visible keyboard focus.
- Skip links on the primary, authentication, and clinician shells.
- Semantic navigation, headings, forms, and landmarks.
- Labels programmatically associated with inputs.
- Error messages announced with `role="alert"`.
- Logical spacing/border utilities where supported.
- Reduced-motion preference respected globally.
- Minimum 44px target height for primary controls.

A full accessibility audit, keyboard-only journey review, screen-reader testing, and mobile touch-target verification remain required.
