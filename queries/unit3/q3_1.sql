-- 3.1 Find active, highly rated producers.
-- Use your theme’s filter condition from the appendix. Sort them and return the first ten.
SELECT m.movie_id, m.title, m.release_year,
       ROUND(AVG(r.score), 2) AS avg_score
FROM movies m
JOIN ratings r ON r.movie_id = m.movie_id
WHERE m.is_available
  AND m.release_year > 2015
  AND r.rating_status = 'published'
GROUP BY m.movie_id
ORDER BY avg_score DESC, m.movie_id
LIMIT 10;

-- 3.1 Find all possible event statuses.
-- Display the distinct values in the event status column.
-- Look carefully at the results. Are there more statuses than you expected?
SELECT rating_status, COUNT(rating_status) AS num_ratings
FROM ratings
GROUP BY rating_status
ORDER BY num_ratings DESC;

-- 3.1 Filter the events in two different ways.
-- Write: one query that filters a numeric range,
-- and one query that filters using an explicit list of values with IN.

SELECT *
FROM ratings
WHERE score BETWEEN 4.0 AND 5.0
ORDER BY score DESC, rating_id;

SELECT rating_id, user_id, movie_id, rated_at, score, rating_status
FROM ratings
WHERE rating_status IN ('published', 'flagged')
ORDER BY rating_id;

-- 3.1. Work with text and missing values.
-- Write queries that: find producers whose names match a text pattern using LIKE,
-- and identify records where a reason/value is missing (NULL).
-- Use COALESCE to replace a missing value with a useful label such as: No reason provided.

SELECT movie_id, title, release_year
FROM movies
WHERE title LIKE 'Title\_1%'
ORDER BY movie_id;

SELECT rating_id, movie_id, rating_status, withdrawn_reason
FROM ratings
WHERE withdrawn_reason IS NULL
ORDER BY rating_id;

SELECT rating_id,
       movie_id,
       rating_status,
       COALESCE(withdrawn_reason, 'No reason provided') AS withdrawn_reason
FROM ratings
ORDER BY rating_id;

-- 3.1 Make the results easier to understand. Create a query with calculated/computed columns that would make sense to someone who does not work with SQL. Depending on your theme, you might calculate or label:
-- a payout amount,
-- a time of day,
-- a value/rating category,
-- or another useful business measure.
-- Use CASE where appropriate to create plain-language categories.

SELECT
    m.title                                   AS "Movie",
    u.user_name                               AS "Viewer",
    TO_CHAR(r.rated_at, 'Mon FMDD, YYYY')     AS "Date rated",

    -- Time of day the rating was made
    CASE
        WHEN EXTRACT(HOUR FROM r.rated_at) BETWEEN 5  AND 11 THEN 'Morning'
        WHEN EXTRACT(HOUR FROM r.rated_at) BETWEEN 12 AND 16 THEN 'Afternoon'
        WHEN EXTRACT(HOUR FROM r.rated_at) BETWEEN 17 AND 20 THEN 'Evening'
        ELSE 'Night'
    END                                       AS "Time of day",

    r.score                                   AS "Score (out of 5)",

    -- Score turned into a plain-language rating category
    CASE
        WHEN r.rating_status = 'withdrawn' THEN 'Not counted'
        WHEN r.score >= 4.5 THEN 'Excellent'
        WHEN r.score >= 3.5 THEN 'Good'
        WHEN r.score >= 2.5 THEN 'Average'
        WHEN r.score >= 1.5 THEN 'Poor'
        ELSE 'Very poor'
    END                                       AS "Rating category",

    -- How long they watched, rounded to whole minutes
    ROUND(r.watch_minutes) || ' min'          AS "Watch time",

    CASE
        WHEN r.watch_minutes < 5  THEN 'Short'
        WHEN r.watch_minutes < 20 THEN 'Medium'
        ELSE 'Long'
    END                                       AS "Viewing length",

    -- Status in everyday words, including the reason if it was removed
    CASE r.rating_status
        WHEN 'published' THEN 'Live'
        WHEN 'flagged'   THEN 'Under review'
        WHEN 'withdrawn' THEN 'Removed: ' || r.withdrawn_reason
    END                                       AS "Rating status"

FROM ratings r
JOIN movies m ON m.movie_id = r.movie_id
JOIN users  u ON u.user_id  = r.user_id
ORDER BY r.rated_at;