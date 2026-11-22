-- ============================================================================
-- Task 6.2 · Compare each row to its neighbors
--
-- In this project:
--   Event    = one row in ratings (200 rows, January-December 2023)
--   Producer = the movie that was rated (movie_id)
--   Metric   = ratings.score
--   Failure  = rating_status = 'withdrawn' (34 of 200)
--   Time     = ratings.rated_at
-- ============================================================================


-- ----------------------------------------------------------------------------
-- Part A · Row to row
-- Question: Is a movie's score going up or down over time, not just high or
-- low overall? For each rating, show the score of the previous and the next
-- rating of the same movie, in time order, and how much it changed.
--
-- Withdrawn ratings are left out before LAG/LEAD run: their score is a 0.5
-- placeholder, so they would create fake drops and recoveries.
-- Final output: movie 11, the movie with the most withdrawn ratings.
-- ----------------------------------------------------------------------------

WITH real_ratings AS (
    SELECT rating_id,
           movie_id,
           user_id,
           rated_at,
           score
    FROM ratings
    WHERE rating_status <> 'withdrawn'
),
with_neighbors AS (
    SELECT rr.*,
           LAG(score)  OVER w AS prev_score,
           LEAD(score) OVER w AS next_score,
           score - LAG(score) OVER w AS delta_from_prev
    FROM real_ratings rr
    WINDOW w AS (PARTITION BY movie_id ORDER BY rated_at, rating_id)
)
SELECT movie_id,
       rating_id,
       rated_at,
       prev_score,
       score,
       next_score,
       delta_from_prev
FROM with_neighbors
WHERE movie_id = 11
ORDER BY rated_at, rating_id;

-- Expected (11 rows):
--   rating  rated_at          prev  score  next  delta
--     169   2023-01-08 14:28  NULL   3.2   5.0   NULL
--     164   2023-02-09 14:56   3.2   5.0   2.2    1.8
--     167   2023-02-15 15:42   5.0   2.2   2.3   -2.8
--     170   2023-02-24 00:13   2.2   2.3   3.7    0.1
--     172   2023-02-24 22:40   2.3   3.7   2.5    1.4
--     160   2023-07-10 14:23   3.7   2.5   1.4   -1.2
--     161   2023-08-17 21:49   2.5   1.4   1.0   -1.1
--     159   2023-08-23 11:46   1.4   1.0   3.3   -0.4
--     158   2023-10-14 22:46   1.0   3.3   3.5    2.3
--     166   2023-10-17 23:57   3.3   3.5   2.9    0.2
--     157   2023-11-11 10:44   3.5   2.9   NULL  -0.6
--
-- Reading it: after a mixed start, movie 11's scores slide three times in a
-- row from July to August (3.7 -> 2.5 -> 1.4 -> 1.0), then recover to
-- 3.3-3.5 in October.
-- Notes
-- * The movie filter is in the outer query, after LAG/LEAD have run, so the
--   neighbors always come from that movie's full history.
-- * rating_id breaks ties if two ratings share the same rated_at.
-- * The first row has no previous rating (prev and delta are NULL) and the
--   last row has no next rating (next is NULL).


-- ----------------------------------------------------------------------------
-- Part B · Cumulative and smoothed
-- Question: How is the platform doing over time? For each month: how many
-- ratings came in, the total so far, the recent trend, the failure rate so
-- far, and how close each quarter gets to its target.
--
-- Target: 50 ratings per quarter (200 for the year, spread evenly).
-- ----------------------------------------------------------------------------

WITH monthly AS (
    SELECT DATE_TRUNC('month', rated_at)::date                AS month,
           COUNT(*)                                           AS ratings,
           COUNT(*) FILTER (WHERE rating_status = 'withdrawn') AS withdrawn
    FROM ratings
    GROUP BY 1
),
windowed AS (
    SELECT month,
           ratings,
           withdrawn,
           SUM(ratings) OVER (ORDER BY month
                              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
               AS running_ratings,
           SUM(withdrawn) OVER (ORDER BY month
                                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
               AS running_withdrawn,
           ROUND(AVG(ratings) OVER (ORDER BY month
                                    ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2)
               AS moving_avg_3m,
           SUM(ratings) OVER (PARTITION BY DATE_TRUNC('quarter', month)
                              ORDER BY month
                              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
               AS quarter_to_date
    FROM monthly
)
SELECT month,
       ratings,
       running_ratings,
       moving_avg_3m,
       ROUND(100.0 * running_withdrawn / running_ratings, 1)
           AS running_failure_rate_pct,
       quarter_to_date,
       50                                     AS quarter_target,
       ROUND(100.0 * quarter_to_date / 50, 1) AS pct_of_target
FROM windowed
ORDER BY month;

-- Expected:
--   month       ratings  running  avg_3m  run_fail%  qtd  target  pct
--   2023-01-01     21       21    21.00     23.8      21    50     42.0
--   2023-02-01     21       42    21.00     21.4      42    50     84.0
--   2023-03-01     11       53    17.67     22.6      53    50    106.0
--   2023-04-01     11       64    14.33     18.8      11    50     22.0
--   2023-05-01     17       81    13.00     17.3      28    50     56.0
--   2023-06-01     20      101    16.00     18.8      48    50     96.0
--   2023-07-01     17      118    18.00     17.8      17    50     34.0
--   2023-08-01     18      136    18.33     17.6      35    50     70.0
--   2023-09-01     16      152    17.00     17.8      51    50    102.0
--   2023-10-01     18      170    17.33     17.1      18    50     36.0
--   2023-11-01     14      184    16.00     16.8      32    50     64.0
--   2023-12-01     16      200    16.00     17.0      48    50     96.0
--
-- Reading it: volume is flat. After a strong January and February (21 each),
-- the 3-month average dips to 13 in May, recovers to about 18 in the summer
-- and ends the year at 16. Q1 (53) and Q3 (51) meet the 50-rating target;
-- Q2 and Q4 (48 each) fall just short, at 96%. The running failure rate
-- falls from 23.8% in January to about 17% from May on, and stays there.
--
-- ROWS counts rows, not time. Every month has ratings, so 3 rows really are
-- 3 months here, and the first two months average over only 1 and 2 months.
-- At day level it would not hold: only 155 of the 365 days have a rating, so
-- a 7-row window would usually cover more than 7 calendar days.
--
-- ROWS vs RANGE: with ROWS, rows that share the same ORDER BY value are
-- still added one at a time, so a running total by day goes up within a day
-- (2023-10-11 has 3 ratings, and each gets a different total). With RANGE,
-- rows with the same ORDER BY value are peers and are added together, so all
-- 3 ratings on 2023-10-11 show the same total, the one for the end of that day.


-- ----------------------------------------------------------------------------
-- Part C · Where the series stops
-- Question: Which movie stops receiving ratings for a long time and then
-- starts again? For each rating, how long since the previous rating of the
-- same movie? Keep only gaps longer than 100 days.
--
-- All ratings count here, withdrawn included: a withdrawn rating is still a
-- sign that someone was rating the movie.
-- ----------------------------------------------------------------------------

WITH gaps AS (
    SELECT movie_id,
           LAG(rating_id) OVER w AS prev_rating_id,
           LAG(rated_at)  OVER w AS prev_rated_at,
           rating_id,
           rated_at,
           rated_at - LAG(rated_at) OVER w AS gap
    FROM ratings
    WINDOW w AS (PARTITION BY movie_id ORDER BY rated_at, rating_id)
)
SELECT movie_id,
       prev_rating_id,
       prev_rated_at,
       rating_id,
       rated_at,
       gap,
       ROUND(EXTRACT(EPOCH FROM gap) / 86400, 1) AS gap_days
FROM gaps
WHERE gap > INTERVAL '100 days'
ORDER BY gap DESC;

-- Expected:
--   movie  prev  prev_rated_at     rating  rated_at          gap                 days
--     9     137  2023-01-05 14:18    131   2023-04-28 04:16  112 days 13:58:00  112.6
--    12     177  2023-03-02 20:20    173   2023-06-17 14:10  106 days 17:50:00  106.7
--
-- Movie 9 is the clearest stop: one rating on 5 January, then nothing for
-- almost four months, then regular ratings again until December. Movie 12
-- has a similar 3.5-month pause in spring.
-- The WHERE has to be in the outer query: window functions run after WHERE
-- and HAVING, so filtering on rated_at - LAG(rated_at) OVER w in the same
-- SELECT is an error.
-- What we cannot tell from this data: whether nobody rated movie 9 in
-- February-April, or whether ratings were made and lost. A missing rating
-- leaves no row, so "no activity" and "activity we failed to record" look
-- the same.
