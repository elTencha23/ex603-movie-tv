-- Part A.1: Row counts of the source tables
-- Question: How many genres and how many movies are there?
SELECT (SELECT COUNT(*) FROM genres) AS genre_rows,
       (SELECT COUNT(*) FROM movies) AS movie_rows;

-- Part A.2: CROSS JOIN
-- Question: What does every possible movie and genre pairing look like?
SELECT m.movie_id,
       g.genre_name
FROM movies m
CROSS JOIN genres g
ORDER BY m.movie_id, g.genre_id;

-- Part A.3: Check the result equals the product of the two counts
-- Question: Does the cross join return genres x movies rows?
SELECT (SELECT COUNT(*) FROM genres)
     * (SELECT COUNT(*) FROM movies)                       AS expected_rows,
       (SELECT COUNT(*) FROM movies CROSS JOIN genres)     AS cross_join_rows;


-- Part B: Execution plan for the three-table join from Task 5.1
-- Question: How does PostgreSQL plan to combine ratings, users and movies,
-- and how long does it actually take?
EXPLAIN ANALYZE
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