-- ============================================================================
-- Task 6.3 · Build the reporting patterns
--
-- In this project:
--   Event    = one row in ratings (200 rows, January-December 2023)
--   Producer = the movie that was rated (movie_id)
--   Metric   = ratings.score
--   Failure  = rating_status = 'withdrawn' (34 of 200)
--   Time     = ratings.rated_at
-- ============================================================================


-- ----------------------------------------------------------------------------
-- Part A · Top N per category
-- Question: What are the three highest ratings each movie received, and how
-- wide is the range between each movie's best and worst rating?
--
-- Withdrawn ratings are left out: their score is a 0.5 placeholder.
-- ----------------------------------------------------------------------------

WITH real_ratings AS (
    SELECT rating_id,
           movie_id,
           user_id,
           rated_at,
           score,
           rating_status
    FROM ratings
    WHERE rating_status <> 'withdrawn'
),
ranked AS (
    SELECT rr.*,
           ROW_NUMBER() OVER w AS rn,
           FIRST_VALUE(score) OVER w AS best_score,
           LAST_VALUE(score)  OVER (w ROWS BETWEEN UNBOUNDED PRECEDING
                                           AND UNBOUNDED FOLLOWING) AS worst_score
    FROM real_ratings rr
    WINDOW w AS (PARTITION BY movie_id
                 ORDER BY score DESC, rated_at DESC)
)
SELECT movie_id,
       rn,
       rating_id,
       user_id,
       rated_at,
       score,
       rating_status,
       best_score,
       worst_score
FROM ranked
WHERE rn <= 3
ORDER BY movie_id, rn;

-- Expected: 39 rows (3 per rated movie). First rows:
--   movie  rn  rating  rated_at          score  status     best  worst
--     1     1     10   2023-06-22 22:30   4.8   published   4.8   1.2
--     1     2      7   2023-02-23 10:07   4.4   published   4.8   1.2
--     1     3     11   2023-11-14 09:05   3.7   flagged     4.8   1.2
--     2     1     18   2023-05-04 14:33   5.0   published   5.0   2.2
--     2     2     17   2023-08-11 08:48   4.9   published   5.0   2.2
--     2     3     24   2023-07-03 05:00   4.8   published   5.0   2.2
--     5     1     60   2023-12-20 19:28   5.0   published   5.0   1.7
--     5     2     63   2023-11-07 14:54   5.0   published   5.0   1.7
--     5     3     54   2023-10-11 06:21   5.0   published   5.0   1.7
--   ...
-- Every movie's best rating is a 5.0 except movie 1 (4.8). The worst real
-- ratings are as low as 0.8 (movies 6, 8 and 10), so most movies have
-- ratings across almost the whole scale.
--
-- Ties at third place
-- Scores of 5.0 are very common, so third place is often a tie. Five movies
-- have more ratings tied at their third-place score than places left:
--   movie 1: two ratings of 3.7 for the last place
--   movie 5: seven ratings of 5.0 for all three places
--   movie 7: four ratings of 5.0     movie 8: five    movie 10: six
-- With RANK() or DENSE_RANK(), rank <= 3 would return all of them: 50 rows
-- instead of 39, and up to seven "top three" ratings for movie 5.
-- This query uses ROW_NUMBER() and breaks ties with the most recent rating
-- first (rated_at DESC). That keeps exactly three per movie, which is what a
-- "top reviews" panel needs, and "newer review wins" is a rule that is easy
-- to explain and keeps the panel fresh. The cost is that older ratings with
-- the same score are left out, and this comment states that openly.
--
-- Other notes
-- * FIRST_VALUE uses the default frame, which always starts at the first row
--   of the movie, so it correctly returns the best score.
-- * LAST_VALUE needs ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING.
--   With the default frame it would stop at the current row and just return
--   each row's own score, not the movie's lowest.
-- * Flagged ratings are still included (for example rating 11 above, and
--   rating 184 for movie 12). A public panel should probably show only
--   'published' ratings until a flag is resolved.


-- ----------------------------------------------------------------------------
-- Part B · Period over period
-- Question: Is the platform getting better or worse each month? How many
-- ratings and how many failures (withdrawn ratings) did each month have,
-- and how did that change from the month before?
-- ----------------------------------------------------------------------------

-- B1 · Check for missing months in the raw monthly series.
-- LAG compares with the previous ROW, not the previous month. If a month had
-- no ratings it would have no row, and LAG would silently compare, say,
-- April with February. This lists every place where that would happen.
-- Expected: 0 rows (every month of 2023 has ratings).
WITH monthly AS (
    SELECT DATE_TRUNC('month', rated_at)::date AS month
    FROM ratings
    GROUP BY 1
),
with_prev AS (
    SELECT month,
           LAG(month) OVER (ORDER BY month) AS prev_row_month
    FROM monthly
)
SELECT month,
       prev_row_month,
       (month - INTERVAL '1 month')::date AS expected_prev_month
FROM with_prev
WHERE prev_row_month <> (month - INTERVAL '1 month')::date;


-- B2 · Month over month, on a complete calendar.
-- generate_series builds every month between the first and last rating, so
-- a month with no ratings would still get a row (with 0) and LAG always
-- compares with the real previous month.
WITH bounds AS (
    SELECT DATE_TRUNC('month', MIN(rated_at)) AS first_month,
           DATE_TRUNC('month', MAX(rated_at)) AS last_month
    FROM ratings
),
calendar AS (
    SELECT GENERATE_SERIES(first_month, last_month, INTERVAL '1 month')::date
               AS month
    FROM bounds
),
monthly AS (
    SELECT DATE_TRUNC('month', rated_at)::date                AS month,
           COUNT(*)                                           AS ratings,
           COUNT(*) FILTER (WHERE rating_status = 'withdrawn') AS withdrawn
    FROM ratings
    GROUP BY 1
),
series AS (
    SELECT c.month,
           COALESCE(m.ratings, 0)   AS ratings,
           COALESCE(m.withdrawn, 0) AS withdrawn,
           ROUND(100.0 * COALESCE(m.withdrawn, 0)
                 / NULLIF(COALESCE(m.ratings, 0), 0), 1) AS failure_rate_pct,
           m.month IS NULL          AS month_missing_in_data
    FROM calendar c
    LEFT JOIN monthly m ON m.month = c.month
),
compared AS (
    SELECT s.*,
           LAG(ratings)          OVER (ORDER BY month) AS prev_ratings,
           LAG(withdrawn)        OVER (ORDER BY month) AS prev_withdrawn,
           LAG(failure_rate_pct) OVER (ORDER BY month) AS prev_failure_rate_pct
    FROM series s
)
SELECT month,
       ratings,
       ROUND(100.0 * (ratings - prev_ratings) / NULLIF(prev_ratings, 0), 1)
           AS ratings_pct_change,
       withdrawn,
       ROUND(100.0 * (withdrawn - prev_withdrawn) / NULLIF(prev_withdrawn, 0), 1)
           AS withdrawn_pct_change,
       failure_rate_pct,
       failure_rate_pct - prev_failure_rate_pct AS failure_rate_change_pp,
       month_missing_in_data
FROM compared
ORDER BY month;

-- Expected:
--   month       ratings  ratings_%  withdrawn  withdrawn_%  fail_rate  change_pp
--   2023-01-01     21      NULL         5         NULL        23.8       NULL
--   2023-02-01     21       0.0         4        -20.0        19.0       -4.8
--   2023-03-01     11     -47.6         3        -25.0        27.3        8.3
--   2023-04-01     11       0.0         0       -100.0         0.0      -27.3
--   2023-05-01     17      54.5         2         NULL        11.8       11.8
--   2023-06-01     20      17.6         5        150.0        25.0       13.2
--   2023-07-01     17     -15.0         2        -60.0        11.8      -13.2
--   2023-08-01     18       5.9         3         50.0        16.7        4.9
--   2023-09-01     16     -11.1         3          0.0        18.8        2.1
--   2023-10-01     18      12.5         2        -33.3        11.1       -7.7
--   2023-11-01     14     -22.2         2          0.0        14.3        3.2
--   2023-12-01     16      14.3         3         50.0        18.8        4.5
--   (month_missing_in_data is false for every month)
--
-- Notes
-- * NULLIF in action: April had 0 withdrawn ratings, so May's
--   withdrawn_pct_change would divide by zero. NULLIF turns the 0 into NULL,
--   and the result is NULL instead of an error. Growth from zero has no
--   meaningful percentage.
-- * The failure rate is compared in percentage points (pp), not percent:
--   going from 11.8% to 25.0% is +13.2 pp. Saying "+112%" would exaggerate it.
-- * The numbers are small, so percentages swing hard: June's +150% in
--   withdrawals is 3 more withdrawn ratings. Read every % with its count.
-- * 100.0 (not 100) forces decimal division; with integers every
--   percentage would be rounded down to a whole number.
