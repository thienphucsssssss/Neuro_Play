# Neuro Play prompts for Google Stitch

Supply [DESIGN.md](../DESIGN.md) for tokens, layout and behavior and [STYLE.md](../STYLE.md) for palette, illustrations, reward visuals and Vietnamese voice. The [working preview](preview.html) shows the Home → Sudoku → Result flow.

## Master prompt

> Design Neuro Play for Android portrait at 390dp. Follow DESIGN.md for ThemeData roles, text sizes, grid geometry, component anatomy, 48dp targets, accessible feedback and reduced motion. Resolve those roles using the light palette in STYLE.md. Use STYLE.md’s friendly training-studio tone and original illustrated puzzle tiles. Keep visible copy in Vietnamese. Keep one action per decision area. Show skill labels and transparent practice goals. Use no fabricated claims about cognitive improvement. Use screen-specific instructions below.

## 1. Login / Register

> Put “Đăng nhập” or “Tạo tài khoản” in textTheme.headlineMedium. Use labeled 48dp fields, a password visibility control and an inline colorScheme.error message. Use colorScheme.primary for submit. Follow STYLE.md’s concise and friendly Vietnamese copy.

## 2. Home

> Open with “Thử thách hôm nay”, a Sudoku skill label and one “Chơi ngay” button using colorScheme.onPrimary on the primary panel. Use STYLE.md’s daily puzzle illustration, weekly streak strip and level. Use textTheme.headlineSmall for “Chơi theo kỹ năng”. Place Sudoku and Khối lập phương 3D under “Suy luận logic”, Xếp hình under “Không gian và lập kế hoạch”, and Cờ Caro under “Chiến thuật và dự đoán”. Set the four local illustrations in game.accent1 through game.accent4 and use the bottom-nav anatomy.

## 3. Game detail / Difficulty

> Show game name in textTheme.headlineMedium and the exact practice label and original diagram from STYLE.md. Use three named 48dp Sudoku choices “Dễ”, “Vừa”, “Khó”, with colorScheme.primaryContainer and a selected indicator. Follow with one “Bắt đầu” button.

## 4. Sudoku

> Use game.board, game.gridLine and game.groupLine for nine rows with 3 × 3 grouping. Display editable and fixed digits using numberStyles.cell. Use the state cues from DESIGN.md §6, and use numberStyles.metric for time and mistakes. Keep art outside the play area as specified in STYLE.md. Put 48dp keypad, note, hint and submit controls below or beside the board. Expose the enlarged board and named direction controls.

## 5. 3D Cube

> Use game.board for the viewport and game.accent2 for the local turn axis. Follow STYLE.md’s three-face, one-move illustration. Pair face fills with shapes or letters. Put named rotate, reset-view and undo buttons outside the viewport with size.touchMin.

## 6. AI Coach sheet

> Open “Gợi ý của AI” in colorScheme.surfaceContainerHigh and radius.sheet. Keep the affected board cell or a compact board visible. Use the numbered hint state in DESIGN.md §6. Write one inference in plain Vietnamese from STYLE.md and name the row and column. Include a 48dp close button.

## 7. Sliding puzzle

> Show the grid and 4dp gutter from DESIGN.md §5, with a dashed vacant slot and labeled move controls. Mark the selected tile with game.accent3. Use STYLE.md’s vacancy example and the label “Không gian và lập kế hoạch”.

## 8. Caro

> Show a square game.board with legible X and O, the last-move marker in game.accent4 and a named current turn. Use the enlarged grid controls from DESIGN.md and STYLE.md’s local diagram based on a forming line. Label the skill “Chiến thuật và dự đoán”.

## 9. Result

> Put “Hoàn thành Sudoku!” in textTheme.displaySmall. Apply feedback.success and feedback.successContainer to STYLE.md’s completed tile and check. Show numeric round score, time and mistakes before level, streak or skill progress. Name the same skill that Home used and show a weekly fraction and the earned XP. Keep the result visible under motion.result and honor reduced motion. Add a clear next action.

## 10. Leaderboard

> Put “Bảng xếp hạng” in textTheme.headlineMedium, then game and difficulty filters and rows. Use numberStyles.rank for aligned values, colorScheme.outlineVariant for dividers and primaryContainer for the current row with “Bạn”. Use STYLE.md’s emphasis on measured play results.

## 11. Challenge

> Use textTheme.headlineMedium for “Thách đấu”. Show the selected friend, game, difficulty and a clear pending or accepted label. Use component list rows for invitations and one colorScheme.primary action. Apply STYLE.md’s original game markers and concise copy.

## 12. Chat

> Put the friend’s name in textTheme.titleMedium. Use radius.card, colorScheme.surfaceContainer for incoming and primaryContainer for outgoing messages. Label timestamps with bodySmall and use a 48dp “Gửi” action. Keep retry copy brief as in STYLE.md.

## 13. Profile

> Use colorScheme.surface and textTheme.headlineMedium. Show practice progress with named bars, units and the level vocabulary in STYLE.md. Use list-row anatomy for account settings and a surfaceContainerHigh sheet for sign-out confirmation.
