CREATE TABLE IF NOT EXISTS sudoku_progress (
  session_id BIGINT UNSIGNED PRIMARY KEY,
  board CHAR(81) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  mistakes INT UNSIGNED NOT NULL DEFAULT 0,
  move_no BIGINT UNSIGNED NOT NULL DEFAULT 0,
  last_cell_index TINYINT UNSIGNED,
  last_digit TINYINT UNSIGNED,
  last_correct BOOLEAN,
  last_elapsed_sec INT UNSIGNED NOT NULL DEFAULT 0,
  solved_at TIMESTAMP(3),
  CONSTRAINT sudoku_progress_session FOREIGN KEY (session_id)
    REFERENCES game_sessions (id) ON DELETE CASCADE
) ENGINE=InnoDB;
