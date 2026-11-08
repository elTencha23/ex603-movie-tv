-- Requirement 1: Three-table join
-- Question: Who are the people behind each rating? For every rating, show the
-- user who gave it, the movie it was for, and when it happened.
SELECT r.rating_id,
       u.user_id,
       u.user_name,
       m.movie_id,
       m.title,
       r.rated_at
FROM ratings r
INNER JOIN users  u ON u.user_id  = r.user_id
INNER JOIN movies m ON m.movie_id = r.movie_id
ORDER BY r.rated_at;

-- Requirement 2: Producer -> junction -> catalog
-- Question: Do the movies flagged in Unit 4 (11, 9 and 2) share any genres?
SELECT m.movie_id,
       m.title,
       g.genre_name
FROM movies m
INNER JOIN movie_genres mg ON mg.movie_id = m.movie_id
INNER JOIN genres       g  ON g.genre_id  = mg.genre_id
WHERE m.movie_id IN (2, 9, 11)
ORDER BY g.genre_name, m.movie_id;

-- Requirement 3: Self join on the producer table
-- Question: How do the flagged movies (2, 9, 11) compare with other movies from
-- the same country? Is their activity level or failure rate different?
WITH movie_stats AS (
    SELECT m.movie_id,
           COUNT(r.rating_id) AS rating_count,
           ROUND(100.0 * SUM(CASE WHEN r.rating_status = 'withdrawn' THEN 1 ELSE 0 END)
                 / NULLIF(COUNT(r.rating_id), 0), 1) AS failure_rate_pct
    FROM movies m
    LEFT JOIN ratings r ON r.movie_id = m.movie_id
    GROUP BY m.movie_id
)
SELECT a.movie_id         AS flagged_movie,
       a.origin_country,
       sa.rating_count     AS flagged_ratings,
       sa.failure_rate_pct AS flagged_failure_pct,
       b.movie_id         AS peer_movie,
       sb.rating_count     AS peer_ratings,
       sb.failure_rate_pct AS peer_failure_pct
FROM movies a
INNER JOIN movies b       ON b.origin_country = a.origin_country
                         AND b.movie_id <> a.movie_id
INNER JOIN movie_stats sa ON sa.movie_id = a.movie_id
INNER JOIN movie_stats sb ON sb.movie_id = b.movie_id
WHERE a.movie_id IN (2, 9, 11)
ORDER BY a.movie_id, b.movie_id;