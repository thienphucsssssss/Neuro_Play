CREATE TABLE IF NOT EXISTS users (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(32) NOT NULL UNIQUE,
  email VARCHAR(254) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  display_name VARCHAR(80) NOT NULL,
  avatar_url VARCHAR(2048),
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS games (
  id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(16) NOT NULL UNIQUE,
  name VARCHAR(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO games (id, code, name) VALUES
  (1, 'rubik', 'Rubik'),
  (2, 'sudoku', 'Sudoku'),
  (3, 'puzzle', 'Xếp hình'),
  (4, 'caro', 'Caro')
AS seed_game ON DUPLICATE KEY UPDATE name = seed_game.name;

CREATE TABLE IF NOT EXISTS game_sessions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  game_id TINYINT UNSIGNED NOT NULL,
  difficulty ENUM('easy', 'medium', 'hard') NOT NULL,
  seed VARCHAR(64),
  status ENUM('active', 'completed', 'abandoned') NOT NULL DEFAULT 'active',
  started_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  finished_at TIMESTAMP(3),
  UNIQUE KEY session_identity (id, user_id, game_id, difficulty),
  KEY user_sessions (user_id, started_at DESC),
  FOREIGN KEY (user_id) REFERENCES users (id),
  FOREIGN KEY (game_id) REFERENCES games (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS scores (
  session_id BIGINT UNSIGNED PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  game_id TINYINT UNSIGNED NOT NULL,
  difficulty ENUM('easy', 'medium', 'hard') NOT NULL,
  score INT UNSIGNED NOT NULL,
  duration_sec INT UNSIGNED NOT NULL,
  mistakes INT UNSIGNED NOT NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  KEY leaderboard (game_id, difficulty, score DESC, duration_sec, session_id),
  KEY user_scores (user_id, created_at DESC),
  CONSTRAINT scores_session_identity FOREIGN KEY (session_id, user_id, game_id, difficulty)
    REFERENCES game_sessions (id, user_id, game_id, difficulty)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
