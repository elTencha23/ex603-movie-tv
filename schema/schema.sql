-- =================================================================
-- EX 603 Assignment 2 — schema.sql
-- Theme: Movie-tv
-- Author: Paul Astorga
-- Target: PostgreSQL 14+
-- =================================================================
-- Reset. Reverse creation order, so no dependency blocks a drop.
 
DROP TABLE IF EXISTS users    CASCADE;
DROP TABLE IF EXISTS movies   CASCADE;
DROP TABLE IF EXISTS genres   CASCADE;
DROP TABLE IF EXISTS movie_genres   CASCADE;
DROP TABLE IF EXISTS ratings    CASCADE;

-- ============================================
-- Table: users
-- ============================================
CREATE TABLE users (
    user_id     INT PRIMARY KEY,
    first_name  VARCHAR(100) NOT NULL,
    last_name   VARCHAR(100) NOT NULL,
    email       VARCHAR(255) NOT NULL UNIQUE CHECK (email = LOWER(email)),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
	is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- ============================================
-- Table: movies
-- ============================================
CREATE TABLE movies (
    movie_id      INT PRIMARY KEY,
    title         VARCHAR(255) NOT NULL,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    release_year  SMALLINT NOT NULL CHECK (release_year BETWEEN 1888 AND 2100)
);


-- ============================================
-- Table: genres
-- ============================================
CREATE TABLE genres (
    genre_id    INT PRIMARY KEY,
    genre_name  VARCHAR(100) NOT NULL UNIQUE CHECK (genre_name = LOWER(genre_name))
);


-- ============================================
-- Table: movie_genres
-- ============================================
CREATE TABLE movie_genres (
    movie_id        INT NOT NULL,
    genre_id        INT NOT NULL,
	CONSTRAINT pk_movie_genres       PRIMARY KEY (movie_id, genre_id),
    CONSTRAINT fk_movie_genres_movie FOREIGN KEY (movie_id) REFERENCES movies (movie_id) ON DELETE CASCADE,
    CONSTRAINT fk_movie_genres_genre FOREIGN KEY (genre_id) REFERENCES genres (genre_id) ON DELETE RESTRICT
);


-- ============================================
-- Table: ratings
-- ============================================
CREATE TABLE ratings (
    user_id     INT NOT NULL,
    movie_id    INT NOT NULL,
    score       SMALLINT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_ratings        PRIMARY KEY (user_id, movie_id),
    CONSTRAINT fk_ratings_user   FOREIGN KEY (user_id)  REFERENCES users (user_id),
    CONSTRAINT fk_ratings_movie  FOREIGN KEY (movie_id) REFERENCES movies (movie_id) ON DELETE CASCADE,
    CONSTRAINT chk_ratings_score CHECK (score BETWEEN 1 AND 5)
);

