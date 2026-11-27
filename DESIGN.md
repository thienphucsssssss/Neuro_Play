# Neuro Play · Interface structure

This is the structural specification for the Flutter Android app and its Vietnamese interface. [STYLE.md](STYLE.md) supplies the appearance and copy direction for these roles.

## 1. Layout and sizes

| Token | dp | Application |
| --- | ---: | --- |
| `space.xs` | 4 | Inline label gap, tile gutters |
| `space.sm` | 8 | Between related controls |
| `space.md` | 12 | Dense component padding |
| `space.lg` | 16 | Phone screen gutters and component padding |
| `space.xl` | 24 | Between groups and wider-screen gutters |
| `space.xxl` | 32 | Between sections |
| `space.section` | 48 | Between major regions on expanded layouts |
| `size.touchMin` | 48 | Minimum action width and height |
| `size.rowMin` | 56 | Minimum standalone list row height |
| `size.tileMin` | 156 | Minimum width per tile in a two-column library |
| `size.contentMax` | 960 | Content width cap for expanded layouts |
| `stroke.rule` / `stroke.active` | 1 / 2 | Structural rule and active-state outline |
| `stroke.focusGap` | 2 | Space between a control and its focus outline |

| Radius token | dp | Component anatomy |
| --- | ---: | --- |
| `radius.flat` | 0 | Sudoku and Caro cells, section rules |
| `radius.xs` | 4 | Sliding tiles, small marks |
| `radius.control` | 8 | Buttons, fields and tabs |
| `radius.card` | 12 | Cards and bubbles |
| `radius.sheet` | 16 | Sheets and dialogs |
| `radius.circle` | half the diameter | Circular targets, avatars and X/O game tokens where applicable |

Use a single play column below 600dp. At 600dp, increase side gutters to 24dp. At 840dp and above, put controls beside the play area when both fit. Preserve source and focus order on reflow. Keep tools reachable in landscape, at increased text size and with the keyboard or a system inset present.

## 2. Type and text layout

Source Sans 3 is an open-source Google font (SIL OFL) with the Vietnamese subset and equal-width lining digits at the weights below. Bundle it for Flutter. A fallback family must cover Vietnamese, including combining marks. Use the same scale in every theme. [Source Sans 3 metadata](https://github.com/google/fonts/blob/main/ofl/sourcesans3/METADATA.pb)

| Flutter token | Weight | Size / line (sp) | Use |
| --- | ---: | ---: | --- |
| `textTheme.displaySmall` | 700 | 36 / 44 | Completion headline |
| `textTheme.headlineMedium` | 700 | 30 / 38 | Screen heading |
| `textTheme.headlineSmall` | 700 | 24 / 32 | Section and sheet heading |
| `textTheme.titleMedium` | 600 | 18 / 24 | Card title and single row title |
| `textTheme.bodyLarge` | 400 | 16 / 24 | Instructions, inputs and messages |
| `textTheme.bodyMedium` | 400 | 14 / 20 | Supporting content and inline feedback |
| `textTheme.labelLarge` | 600 | 14 / 20 | Buttons, fields and tabs |
| `textTheme.labelMedium` | 600 | 12 / 16 | Metric label and state |
| `textTheme.bodySmall` | 400 | 12 / 16 | Secondary metadata |
| `numberStyles.score` | 700 | 32 / 40 | Result score |
| `numberStyles.metric` | 600 | 22 / 28 | Elapsed time and error count |
| `numberStyles.cell` | 500 / 700 | 20 / 24 | Entered and fixed digits |
| `numberStyles.cellCompact` | 500 / 700 | 18 / 22 | Digits in compact cells |
| `numberStyles.note` | 500 | 9 / 10 | Candidates, 10 / 12 in enlarged cells |
| `numberStyles.rank` | 600 | 16 / 24 | Aligned ranking columns |

Use `TextStyle.height = line / size`. Set `FontFeature.tabularFigures()` and `FontFeature.liningFigures()` for numeric roles. Keep first ascent and last descent. Cover “Thách đấu”, “Bảng xếp hạng” and “Hoàn thành!” in the text-layout check. Let labels wrap and rows grow. Keep a text readout of the selected cell when text scaling exceeds the available board space.

## 3. ThemeData and color roles

Set `ThemeData.colorScheme` and `ThemeData.textTheme`. Map shared tokens into component themes. Use typed `ThemeExtension` classes for dimensions, numeric text styles, motion, game roles and interaction roles.

| Token | Functional meaning |
| --- | --- |
| `colorScheme.surface`, `surfaceContainerLow`, `surfaceContainer`, `surfaceContainerHigh` | Canvas, card or row, inset area, sheet |
| `colorScheme.onSurface`, `onSurfaceVariant` | Main and supporting text |
| `colorScheme.primary`, `onPrimary` | Primary action fill and foreground |
| `colorScheme.primaryContainer`, `onPrimaryContainer` | Active tab, hint or shared selection fill and foreground |
| `colorScheme.outline`, `outlineVariant` | Functional boundary and optional separator |
| `colorScheme.error`, `errorContainer`, `onErrorContainer` | Error border, fill and message |
| `colorScheme.scrim`, `surfaceTint` | Modal backdrop and elevation tint policy |
| `interaction.primaryPressed`, `interaction.focusRing` | Pressed action fill and keyboard focus stroke |
| `feedback.success`, `feedback.successContainer` | Completion mark and background |
| `game.board`, `game.gridLine`, `game.groupLine` | Board base and two structural line roles |
| `game.selectedFill`, `game.relatedFill` | Active and peer cell backgrounds |
| `game.accent1` … `game.accent4`, with corresponding `Container` roles | Game-specific foreground and supporting fill |

## 4. Component anatomy

| Component | Anatomy and layout | States and behavior |
| --- | --- | --- |
| Button | Label, optional leading icon or trailing progress indicator, 8dp radius, at least 48 × 48dp, 16dp inline padding | Primary uses `primary` / `onPrimary`. On a `primary` surface it can use `onPrimary` fill with a contrasting foreground. Secondary uses `surfaceContainerLow` and `outline`. Keep a stable width for loading. Expose pressed, disabled and focus semantics. |
| Card | One container, optional media slot, title, supporting line and optional action, 12dp radius, 16dp padding | Give an actionable card a single named target. Keep any independent secondary action outside that target. |
| List row | Optional leading icon or avatar, flexible title and supporting value, optional trailing action or aligned numeric slot, 56dp minimum | Grow to fit text. Give each independent action 48dp. Use a separator outside the target. |
| Bottom nav | Three to five destinations, each containing an icon and visible label, equal target widths and system bottom inset | Expose selected semantics and a selected indicator. Hide the app-level bar in focused play. |
| Sheet | Title, body, dismissal control, optional actions and bottom inset, 16dp upper radius | Scroll the content if needed. On modal open, direct focus into the sheet. On close, restore focus to the opener. Keep blocking and non-blocking sheets distinct in semantics. |
| Metric / progress | Visible label, value and optional unit or maximum. Use the numeric roles for changing values. | Expose determinate progress with a name and a current and maximum value. Use text for pending, saved and failed. Keep timer ticks silent in live regions. |
| Keypad | Grid of numeric buttons, ≤5 columns on a phone, and separate edit / hint controls | Every key is at least 48dp. Use pressed/toggled semantics and repeat actions only when the game allows it. |

Place game identity and metrics before the board, tools after the board and submission after the tools. Place completion status before result metrics, progress and next actions. Loaders retain the component footprint. Start, submit, retry and leave flows retain input when a recoverable action fails.

## 5. Board geometry and access

`W` is the available inner track width after the screen gutters and outer board border. Lay out square cells and snap grid rules to device pixels. Compact modes size the overview to available space. Use expanded play with every grid target at 48dp or larger, plus a reachable direction and value control when the full board needs panning.

| Board | Compact track size | Expanded track size | Separators and controls |
| --- | --- | --- | --- |
| Sudoku | 9 × 9, `min(W, 456) / 9` dp, about 35–40dp at 360–390dp screen widths | 48–56dp per cell, at least 432dp inner width | 1dp `game.gridLine` internally, 2dp `game.groupLine` at the perimeter and between 3 × 3 groups. Four directional controls plus number pad reach every move. |
| Caro | `N × N`, `min(W, 480) / N` dp, about 21–24dp at 360–390dp for `N = 15` | At least 48dp per playable intersection or cell with a panning viewport | Separate X and O by shape and label. Mark and announce the last move. Pan the viewport to the moved cursor when needed. |
| Sliding puzzle | `N × N`, `(min(W, 456) − 4 × (N − 1)) / N` dp, at least 48dp or use a panning viewport | At least 48dp per playable tile, 4dp gaps | Use 4dp tile radius. Identify the empty slot with a dashed outline and accessible text. Expose actions for adjacent eligible tiles. |

The compact Sudoku and Caro boards can have individually labeled direct-tap shortcuts smaller than 48dp. A separate 48dp-target route reaches the same moves using enlarged cells or coordinate controls. State the selected row, column, value and editability in screen-reader and keyboard navigation. Cube gestures also have labeled rotate, undo and reset-view controls outside the viewport.

## 6. Cell states

Keep structural group lines across all states. For overlapping roles, resolve fills in this order: error, hint, done, selected, related, default. Keep focus and selection distinguishable on overlapping feedback. The given, entered and note rows govern cell content alongside that fill.

| State | Role-based fill and mark | Weight and noncolor cue |
| --- | --- | --- |
| Default | `game.board` and `game.gridLine` | Empty visual and “Ô trống” semantics |
| Selected | `game.selectedFill` with 2dp `interaction.focusRing` inset edge and corner indicator | Preserve content weight. Expose “Đang chọn” and coordinates. A keyboard focus ring remains separate from selection. |
| Related | `game.relatedFill` with unchanged grid | Preserve content weight. Mark the selected row and column ends and expose related semantics. |
| Given | `onSurface` on the resolved fill | Weight 700, optional fixed marker and “Số cho sẵn”. Read-only value. |
| Entered | `onSurface` on the resolved fill | Weight 500 and “Số đã nhập”. Editable value. |
| Note | `onSurfaceVariant` on the resolved fill | Weight 500 in a 3 × 3 candidate arrangement. Read candidates in numeric order. |
| Error | `errorContainer` and `onErrorContainer`, with 2dp `error` inset edge | Weight 600, exclamation and corresponding “Sai” text in status. |
| Hint | `primaryContainer` and `onPrimaryContainer`, with 2dp dashed outline | Weight 600 if a value is shown. Pair a numbered corner marker with the same number and coordinates in the hint copy. |
| Done | `feedback.successContainer` and `feedback.success` | Weight 600 or 700 for given values, 2dp outline and check. Announce “Đã hoàn thành” once. |

Caro and sliding omit Sudoku-specific content types. Apply selection, last-move or resolved-state cues to their own geometry and semantics. Keep board and hint explanation in sync when changing or closing the active step.

## 7. Motion

| Token / event | Duration | Easing |
| --- | ---: | --- |
| `motion.select` · selection / press | 100ms | easeOut |
| `motion.correct` · correct feedback | 140ms | easeOut |
| `motion.wrong` · wrong feedback | 160ms | easeOut |
| `motion.tileSlide` · one adjacent move | 170ms | easeInOut |
| `motion.sheetIn` / `sheetOut` | 220 / 180ms | easeOutCubic / easeInCubic |
| `motion.result` · completion | 240ms | easeOut |

Apply focus, the semantic state and the accessible outcome immediately. Honor `MediaQuery.disableAnimations` and the Android animation setting. In reduced motion, update content without transitions or displacement.

## 8. Accessibility and verification

- Apply WCAG AA. Check 4.5:1 for normal text, 3:1 for large text and 3:1 for meaningful control, focus and board boundaries against adjacent fills. Verify both foreground and background for each state. [WCAG 2.2](https://www.w3.org/TR/WCAG22/)
- Pair state colors with text, shape, border style or an icon. Use a persistent, 2dp visible keyboard focus ring with a 2dp gap. Keep actionable controls at least 48 × 48dp and provide the full-size grid routes in §5.
- Set locale and semantics to Vietnamese. Check TalkBack order, text scaling, long labels, visible focus and keyboard shortcuts. Announce submitted results once. Keep progress labels and units exposed. Restore focus after modal dismissals.

## Assumptions

- 15 × 15 Caro and 3 × 3 or 4 × 4 sliding layouts are design baselines. The configured game rules provide actual board sizes.
- The app provides score, error rules, difficulty and submission state. Design dimensions are Android logical pixels unless the table marks a type size in sp.
