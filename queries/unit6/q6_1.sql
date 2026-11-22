-- ============================================================================
-- Task 6.1 · Compute across a window without collapsing
--
-- In this project:
--   Event    = one row in ratings
--   Producer = the movie that was rated (movie_id)
--   Metric   = ratings.score (1-5)
--   Failure  = rating_status = 'withdrawn'
-- ============================================================================


-- ----------------------------------------------------------------------------
-- Part 1 · Compare each event to its producer's average
-- Question: Is a rating unusual for its own movie? Show every rating next to
-- that movie's average score, and how far it is from that average.
-- ----------------------------------------------------------------------------

-- 1A · Window version: one row per rating
SELECT r.rating_id,
       r.movie_id,
       r.user_id,
       r.score,
       r.rating_status,
       ROUND(AVG(r.score) OVER (PARTITION BY r.movie_id), 2) AS movie_avg_score,
       ROUND(r.score - AVG(r.score) OVER (PARTITION BY r.movie_id), 2)
           AS diff_from_movie_avg
FROM ratings r
ORDER BY r.movie_id, r.rating_id;

-- 1B · GROUP BY version: one row per movie
SELECT r.movie_id,
       COUNT(*)               AS rating_count,
       ROUND(AVG(r.score), 2) AS movie_avg_score
FROM ratings r
GROUP BY r.movie_id
ORDER BY r.movie_id;

-- 1C · Row counts of the two versions, side by side
SELECT (SELECT COUNT(*) FROM ratings)                  AS window_rows,
       (SELECT COUNT(DISTINCT movie_id) FROM ratings)  AS group_by_rows;

-- Comparison
-- The window version returns one row per rating; the GROUP BY version returns
-- one row per rated movie (1C shows both numbers). The averages are the same
-- in both, but GROUP BY loses every individual rating: which user gave it,
-- its score, its status, and how far it sits from the movie's average. So it
-- can say what is normal for a movie, but not which ratings are unusual.


-- ----------------------------------------------------------------------------
-- Part 2 · Rank producers three ways
-- Question: For a leaderboard of the most-rated movies, how does the ranking
-- method change who appears higher when two movies have the same number of
-- ratings?
--
-- Starts from movies (LEFT JOIN) so movies with no ratings are included with
-- 0. Movies 14 and 15 have no ratings, so they are always tied, which
-- guarantees at least one tie in the output.
-- ----------------------------------------------------------------------------

WITH movie_counts AS (
    SELECT m.movie_id,
           COUNT(r.rating_id) AS rating_count
    FROM movies m
    LEFT JOIN ratings r ON r.movie_id = m.movie_id
    GROUP BY m.movie_id
)
SELECT movie_id,
       rating_count,
       ROW_NUMBER() OVER (ORDER BY rating_count DESC, movie_id) AS row_num,
       RANK()       OVER (ORDER BY rating_count DESC)           AS rnk,
       DENSE_RANK() OVER (ORDER BY rating_count DESC)           AS dense_rnk
FROM movie_counts
ORDER BY row_num;

-- How the three functions treat a tie:
-- ROW_NUMBER  never ties. Tied movies get different numbers, decided only by
--             the tie-breaker (movie_id), so the leaderboard shows a
--             difference that is not in the data.
-- RANK        gives tied movies the same number and then skips, so the next
--             movie's rank = 1 + the number of movies ahead of it.
-- DENSE_RANK  gives tied movies the same number and does not skip, so the
--             next movie is only one place lower.
-- The tie-breaker is only in ROW_NUMBER's ORDER BY; putting it in RANK or
-- DENSE_RANK would split the ties there too.


-- ----------------------------------------------------------------------------
-- Part 3 · Sort producers into four bands
-- Question: If we split movies into four bands by number of ratings, which
-- band does each one land in, and what happens to tied movies?
-- ----------------------------------------------------------------------------

WITH movie_counts AS (
    SELECT m.movie_id,
           COUNT(r.rating_id) AS rating_count
    FROM movies m
    LEFT JOIN ratings r ON r.movie_id = m.movie_id
    GROUP BY m.movie_id
)
SELECT movie_id,
       rating_count,
       RANK()   OVER (ORDER BY rating_count DESC)           AS rnk,
       NTILE(4) OVER (ORDER BY rating_count DESC, movie_id) AS band
FROM movie_counts
ORDER BY band, rating_count DESC, movie_id;

-- What happens at a boundary:
-- NTILE(4) deals the ordered rows into 4 bands as evenly as it can. With 15
-- movies the bands hold 4, 4, 4 and 3 movies. NTILE only counts rows and never
-- looks at the values, so if two movies with the same rating_count fall on
-- either side of a band boundary, they land in different bands even though
-- RANK shows them as equal. Which one goes higher is decided only by the
-- tie-breaker (movie_id). Look for rows where rnk is equal but band differs.