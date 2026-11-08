-- Part A.1: LEFT JOIN
-- Question: Which movies exist, and how many ratings does each have,
-- including movies that have never been rated?
SELECT m.movie_id,
       m.title,
       COUNT(r.rating_id) AS rating_count
FROM movies m
LEFT JOIN ratings r ON r.movie_id = m.movie_id
GROUP BY m.movie_id, m.title
ORDER BY m.movie_id;

-- Part A.2: INNER JOIN (equivalent query)
-- Question: Which movies have at least one rating, and how many?
SELECT m.movie_id,
       m.title,
       COUNT(r.rating_id) AS rating_count
FROM movies m
INNER JOIN ratings r ON r.movie_id = m.movie_id
GROUP BY m.movie_id, m.title
ORDER BY m.movie_id;

-- Part A.3: Count of movies excluded by the inner join
-- Question: How many movies does the inner join leave out?
SELECT (SELECT COUNT(DISTINCT m.movie_id)
        FROM movies m
        LEFT JOIN ratings r ON r.movie_id = m.movie_id)   AS left_join_movies,
       (SELECT COUNT(DISTINCT m.movie_id)
        FROM movies m
        INNER JOIN ratings r ON r.movie_id = m.movie_id)  AS inner_join_movies,
       (SELECT COUNT(DISTINCT m.movie_id)
        FROM movies m
        LEFT JOIN ratings r ON r.movie_id = m.movie_id)
     - (SELECT COUNT(DISTINCT m.movie_id)
        FROM movies m
        INNER JOIN ratings r ON r.movie_id = m.movie_id)  AS excluded_movies;

-- Part A.4: Which movies are missing
-- Question: Which movies have never been rated?
SELECT m.movie_id,
       m.title,
       m.added_on,
       m.is_available
FROM movies m
LEFT JOIN ratings r ON r.movie_id = m.movie_id
WHERE r.rating_id IS NULL
ORDER BY m.movie_id;

-- Part B.1: RIGHT JOIN
-- Question: Same as Part A.1 (every movie and its rating count), written with
-- the tables swapped so movies is on the right side.
SELECT m.movie_id,
       m.title,
       COUNT(r.rating_id) AS rating_count
FROM ratings r
RIGHT JOIN movies m ON m.movie_id = r.movie_id
GROUP BY m.movie_id, m.title
ORDER BY m.movie_id;

-- Part B.2: Verify the LEFT and RIGHT JOIN results match
-- Question: Is there any row in one result that is not in the other?
-- Both counts should be 0.
WITH left_result AS (
    SELECT m.movie_id, m.title, COUNT(r.rating_id) AS rating_count
    FROM movies m
    LEFT JOIN ratings r ON r.movie_id = m.movie_id
    GROUP BY m.movie_id, m.title
),
right_result AS (
    SELECT m.movie_id, m.title, COUNT(r.rating_id) AS rating_count
    FROM ratings r
    RIGHT JOIN movies m ON m.movie_id = r.movie_id
    GROUP BY m.movie_id, m.title
)
SELECT (SELECT COUNT(*) FROM (SELECT * FROM left_result
                              EXCEPT
                              SELECT * FROM right_result) x) AS only_in_left,
       (SELECT COUNT(*) FROM (SELECT * FROM right_result
                              EXCEPT
                              SELECT * FROM left_result) y)  AS only_in_right;

-- Part B.3: FULL OUTER JOIN
-- Question: Are there movies with no ratings, or ratings with no movie?
SELECT m.movie_id   AS movie_movie_id,
       r.movie_id   AS rating_movie_id,
       r.rating_id,
       CASE WHEN r.rating_id IS NULL THEN 'movie with no ratings'
            WHEN m.movie_id  IS NULL THEN 'rating with no movie'
            ELSE 'matched' END AS match_status
FROM movies m
FULL OUTER JOIN ratings r ON r.movie_id = m.movie_id
WHERE r.rating_id IS NULL OR m.movie_id IS NULL
ORDER BY match_status, m.movie_id;

-- Part C.1: NOT EXISTS
-- Question: Which movies have never been rated?
SELECT m.movie_id
FROM movies m
WHERE NOT EXISTS (
    SELECT 1
    FROM ratings r
    WHERE r.movie_id = m.movie_id
)
ORDER BY m.movie_id;

-- Part C.2: EXCEPT
-- Question: Which movies have never been rated? (all movie IDs minus rated movie IDs)
SELECT movie_id FROM movies
EXCEPT
SELECT movie_id FROM ratings
ORDER BY movie_id;
