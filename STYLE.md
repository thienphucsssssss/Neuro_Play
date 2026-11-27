# Neuro Play · Art direction

Neuro Play should feel like a friendly cognitive training studio. Players can see the exercise they are doing, make a move confidently and leave with visible credit for their practice. Use clear game diagrams, a measured pace and brief, satisfying feedback. [DESIGN.md](DESIGN.md) defines the underlying component, grid and accessibility rules.

## 1. Reference observations

| Reference | What the public images and listing show | Direction for Neuro Play |
| --- | --- | --- |
| NeuroNation | Public category images use cool pale blue panels, white rounded tiles and navy labels. Games are illustrated by small slices of their mechanics, including symbols, numbers and geometric targets. The tile density is regular, with a title below each image. Its article groups exercises by numeracy, language, reasoning, memory and perception. Play screenshots show an ordered exercise track with a level, goal, time and a star marker. | Give each game a visible skill label and a picture that explains its mechanic. Present a repeatable practice goal and its recorded progress in plain language. The skill labels describe the task a player practices. |
| Infinite Word Search Puzzles | Store images combine bright yellow, orange and aqua promo backdrops with dark in-game surfaces. Inside the app, artwork uses high-saturation rounded category tiles, simple themed pictograms and dense grouping. A progression screenshot uses linked level nodes, locks, reward boxes and a percent meter. Multiplayer has a distinct entry. The listing describes progression, endless and daily puzzles, unlockable designs, multiplayer and leaderboards. | Give the daily challenge a single obvious entry and make completed milestones visible. Use original puzzle shapes and muted local identity colors. Put optional modes and social routes behind their own named destinations. |

The public article images and Google Play galleries were inspected for this revision. The local `design/references/` directory was absent in the available checkout. Reference assets are used for observation only. Draw original Neuro Play artwork. [NeuroNation brain games](https://www.neuronation.com/science/en/brain-games/) · [NeuroNation screenshots](https://play.google.com/store/apps/details?id=air.nn.mobile.app.main&hl=en) · [Infinite Word Search Puzzles listing and screenshots](https://play.google.com/store/apps/details?id=com.randomlogicgames.wordsearch&hl=en)

## 2. Light-first palette

Use one brand accent, a decisive cobalt. Neutral surfaces lean cool and are separated by value and functional borders. Use the cobalt action across games. Give each game one quieter hue with its own lightly tinted backing. Error and completion colors have semantic jobs.

| Role from DESIGN.md | Light value | Appearance |
| --- | --- | --- |
| `colorScheme.primary` / `onPrimary` | `#2347BA` / `#FFFFFF` | Cobalt action or daily panel and its white foreground |
| `interaction.primaryPressed` / `focusRing` | `#19358F` / `#2347BA` | Press emphasis and external focus |
| `colorScheme.primaryContainer` / `onPrimaryContainer` | `#E2E9FF` / `#172F7D` | Cobalt tint and deep ink for current destinations and hints |
| `colorScheme.surface` / `surfaceContainerLow` | `#F3F6FC` / `#FFFFFF` | Cool off-white canvas and white functional surfaces |
| `colorScheme.surfaceContainer` / `surfaceContainerHigh` | `#E9EFF9` / `#E3EAF8` | Inset areas and sheets |
| `colorScheme.onSurface` / `onSurfaceVariant` | `#15213A` / `#4B5972` | Deep navy text and slate copy |
| `colorScheme.outline` / `outlineVariant` | `#657795` / `#CFD9EB` | Functional edges and quiet decorative rules |
| `colorScheme.error`, `onErrorContainer` / `errorContainer` | `#9D3843` / `#F9E6E6` | Error text and border on a muted rose tint |
| `feedback.success` / `successContainer` | `#266447` / `#DDEFE5` | Completion text and check on a muted green tint |
| `game.board` / `gridLine` / `groupLine` | `#FFFFFF` / `#70819E` / `#405473` | Neutral board, legible ordinary and group rules |
| `game.selectedFill` / `relatedFill` | `#DCE7FF` / `#EEF3FB` | Clear active fill with a quiet peer wash |
| `colorScheme.scrim` / `surfaceTint` | `#15213A66` / `#00000000` | Translucent backdrop and transparent elevation tint |

| Game roles | Accent / tint | Where to use |
| --- | --- | --- |
| `game.accent1` / `accent1Container` · Sudoku | `#356872` / `#D9EDEF` | Muted blue-green for digit tiles and Sudoku identity |
| `game.accent2` / `accent2Container` · Khối lập phương 3D | `#65518A` / `#EDE6F7` | Dusty grape for a small cube diagram and active axis |
| `game.accent3` / `accent3Container` · Xếp hình | `#7C5728` / `#F5EADA` | Ochre for local tile motion cues |
| `game.accent4` / `accent4Container` · Cờ Caro | `#834A5B` / `#F5E5EB` | Clay rose for local board identity or the last move |

A game accent stays in a diagram, small marker or labeled identity area. The play surface uses the neutral board roles. Keep persistent labels on all saturated areas; verify the final foreground and background pairs with DESIGN.md §8.

## 3. Shape, imagery and density

The shared visual motif is a puzzle tile with one clearly legible change. Build art from matte planes, a few clean edges and occasional shallow overlap. Use the radius scale from DESIGN.md. Small diagrams fit a square slot, the daily motif can use a larger crop and the board keeps its square grid. Keep the game’s orientation and numbers readable at thumbnail size. Use the sans hierarchy in DESIGN.md with clear, upright headings.

| Game | Original illustration | Practice label |
| --- | --- | --- |
| Sudoku | A short grid crop with a few distinct digits and one selected square. A selected tile can lift out of the daily-challenge illustration. Keep the playable grid orthogonal. | **Suy luận logic** · Loại trừ theo hàng, cột và khối. |
| Khối lập phương 3D | Three flat isometric faces with a single rotated slice or axis arrow. Use a different mark on each face where needed. | **Suy luận logic** · Tìm quy luật xoay và giữ thứ tự bước. |
| Xếp hình | An arrangement of square tiles, a visible vacancy and one adjacent tile in motion. Orient the graphic toward the empty slot. | **Không gian và lập kế hoạch** · Hình dung vị trí và sắp thứ tự bước. |
| Cờ Caro | A short crop of X and O marks with one marked next square or a forming line. Keep the marks distinguishable by shape. | **Chiến thuật và dự đoán** · Đọc thế cờ và nghĩ trước nước đáp. |

**Home** opens with one daily challenge that names its game, difficulty and skill. Use a white action with deep ink inside the cobalt panel. Place current streak and level nearby, then use three named skill groups. Sudoku and Cube appear together under “Suy luận logic”. Keep the group names legible without color. Use flat rows for the game directory and give each game a recognizable illustration inside its own small slot.

**Sudoku** puts the board before the keypad and tools. Avoid game art behind the active board. Use the header for game identity, time and mistakes. Keep the hint link visually connected to the active cell so the player knows what to do next.

**Result** opens with the outcome and round facts. The progress area names the same skill used on Home, reports what changed and gives one next action. For a Sudoku result show “Suy luận logic” and the current weekly tally. Use the matching skill label for Cube, Xếp hình and Cờ Caro results.

## 4. Progress and rewards

- **Streak** · Display “3 ngày liên tiếp” with a week strip of labeled day marks. A check means a completed day, an outline means today, and empty days stay quiet. If today has been completed, use both the selected day treatment and the check.
- **Level** · Show the level and a stated value such as “90 / 100 XP”. State the earned increment beside the result, then show the new total beside the bar. Keep level and round score distinct.
- **Skill bars** · Label the exact practice goal “3 / 5 ván tuần này”. Highlight the skill played on the current round and add one line of plain language. The bar is a record of completed play toward a goal.
- **Completion** · Set one completed tile into a short stack and show a prominent check. Fade or settle the group once using `motion.result`. The text and values appear immediately and reduced motion keeps the tile still. Treat optional theme rewards as predictable milestones when supported.

## 5. Vietnamese microcopy

Write short, natural sentences using “bạn” when needed. Name the action and the observation it acts on. For progress, use numbers with units and explain their basis. Use sentence case and review diacritics on narrow screens.

| Moment | Copy example |
| --- | --- |
| Daily entry | “Thử thách hôm nay” · “Chơi ngay” |
| Clue | “Hàng 4 còn thiếu số 7. Thử ô đang chọn.” |
| Mistake | “Ô này chưa đúng. Bạn có thể thử lại.” |
| Completion | “Hoàn thành Sudoku!” · “Thêm một ván cho mục tiêu tuần này.” |
| Streak resumes | “Chơi một ván để bắt đầu chuỗi mới.” |

## 6. Do / don’t

**Color and shape**

- **Do** · Keep the cobalt action and use muted game tints locally.
- **Don’t** · Use casino effects, neon cyber treatments, gradients across game categories or newspaper styling.

**Art and layout**

- **Do** · Show what the player moves or solves and give the daily challenge a distinct focal point.
- **Don’t** · Stack identical dashboard cards or use generic brain, network or trophy artwork.

**Rewards and language**

- **Do** · Show the named skill, a completed action and a clear next step in Vietnamese.
- **Don’t** · Claim a change in cognitive ability, punish a missed day through copy or make rewards look random.

## Assumptions

- The direction defines the light theme first. A dark theme can be designed separately with the same roles.
- The skill categories describe how each game is played. XP, weekly goals and streaks are proposed interface examples. Their production rules are separate.
- The preview uses a near-finished Sudoku so the action and outcome can be reviewed quickly. All figures and completion dates are illustrative.
