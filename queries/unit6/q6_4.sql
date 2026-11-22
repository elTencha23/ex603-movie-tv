-- ============================================================================
-- Task 6.4 · Supporting queries for the closing memo
-- (analysis/unit6-finding.md)
--
--   Event    = one row in ratings (200 rows, January-December 2023)
--   Producer = the movie that was rated (movie_id)
--   Failure  = rating_status = 'withdrawn' (34 of 200)
--   Failure rate = withdrawn ratings / all ratings
-- ============================================================================


-- M1 · Is the failure problem getting better or worse, quarter by quarter?
-- Failure rate per quarter, change from the previous quarter, the running
-- rate for the year so far, and the rate without user requests (users
-- deleting their own rating is not a platform failure).
WITH quarterly AS (
    SELECT DATE_TRUNC('quarter', rated_at)::date AS quarter,
           COUNT(*)                                            AS ratings,
           COUNT(*) FILTER (WHERE rating_status = 'withdrawn') AS withdrawn,
           COUNT(*) FILTER (WHERE rating_status = 'withdrawn'
                              AND withdrawn_reason <> 'User request')
               AS withdrawn_excl_user_requests
    FROM ratings
    GROUP BY 1
),
rates AS (
    SELECT q.*,
           ROUND(100.0 * withdrawn / NULLIF(ratings, 0), 1) AS failure_rate_pct
    FROM quarterly q
)
SELECT quarter,
       ratings,
       withdrawn,
       failure_rate_pct,
       failure_rate_pct - LAG(failure_rate_pct) OVER (ORDER BY quarter)
           AS change_pp,
       ROUND(100.0 * SUM(withdrawn) OVER (ORDER BY quarter)
                   / SUM(ratings)   OVER (ORDER BY quarter), 1)
           AS running_failure_rate_pct,
       ROUND(100.0 * withdrawn_excl_user_requests / NULLIF(ratings, 0), 1)
           AS rate_excl_user_requests_pct
FROM rates
ORDER BY quarter;

-- Expected:
--   quarter     ratings  withdrawn  rate  change_pp  running  excl_user_req
--   2023-01-01     53       12      22.6     NULL      22.6       18.9
--   2023-04-01     48        7      14.6     -8.0      18.8       10.4
--   2023-07-01     51        8      15.7      1.1      17.8       11.8
--   2023-10-01     48        7      14.6     -1.1      17.0       12.5


-- M2 · What kind of failures are they?
-- Withdrawn ratings per quarter, split by reason.
SELECT DATE_TRUNC('quarter', rated_at)::date AS quarter,
       COUNT(*) FILTER (WHERE withdrawn_reason = 'Spam detected')    AS spam,
       COUNT(*) FILTER (WHERE withdrawn_reason = 'Policy violation') AS policy_violation,
       COUNT(*) FILTER (WHERE withdrawn_reason = 'Duplicate rating') AS duplicate,
       COUNT(*) FILTER (WHERE withdrawn_reason = 'User request')     AS user_request,
       COUNT(*)                                                      AS total_withdrawn
FROM ratings
WHERE rating_status = 'withdrawn'
GROUP BY 1
ORDER BY 1;

-- Expected:
--   quarter     spam  policy  duplicate  user_request  total
--   2023-01-01    4      4        2           2         12
--   2023-04-01    3      1        1           2          7
--   2023-07-01    3      1        2           2          8
--   2023-10-01    2      2        2           1          7
-- Moderation failures (spam + policy) fell from 8 in Q1 to 4 in every later
-- quarter. Duplicates and user requests stayed at about 3-4 a quarter.


-- M3 · Which movies got better or worse?
-- Failure rate per movie in the first and second half of 2023, and the
-- change between them.
WITH by_half AS (
    SELECT movie_id,
           CASE WHEN rated_at < '2023-07-01' THEN '1. Jan-Jun'
                ELSE '2. Jul-Dec' END                         AS half,
           COUNT(*)                                            AS ratings,
           COUNT(*) FILTER (WHERE rating_status = 'withdrawn') AS withdrawn
    FROM ratings
    GROUP BY 1, 2
),
rates AS (
    SELECT b.*,
           ROUND(100.0 * withdrawn / NULLIF(ratings, 0), 1) AS failure_rate_pct
    FROM by_half b
)
SELECT movie_id,
       half,
       ratings,
       withdrawn,
       failure_rate_pct,
       failure_rate_pct
         - LAG(failure_rate_pct) OVER (PARTITION BY movie_id ORDER BY half)
           AS change_pp
FROM rates
ORDER BY movie_id, half;

-- Expected for the three movies flagged in Unit 5:
--   movie  half         ratings  withdrawn  rate  change_pp
--     2    1. Jan-Jun      10        3      30.0     NULL
--     2    2. Jul-Dec       6        1      16.7    -13.3
--     9    1. Jan-Jun       7        1      14.3     NULL
--     9    2. Jul-Dec       7        3      42.9     28.6
--    11    1. Jan-Jun       9        4      44.4     NULL
--    11    2. Jul-Dec       7        1      14.3    -30.1
-- Movies 2 and 11 improved; movie 9 got much worse.


-- M4 · Are a few users behind the failures?
-- Users with two or more withdrawn ratings, ranked, with their share of all
-- withdrawals and when their first and last withdrawal happened.
-- The share and the running share are calculated over ALL users with a
-- withdrawal (inside the CTE), and only then filtered to 2+, so the
-- denominator is all 34 withdrawals.
WITH user_withdrawals AS (
    SELECT user_id,
           COUNT(*)      AS withdrawn,
           MIN(rated_at) AS first_withdrawal,
           MAX(rated_at) AS last_withdrawal
    FROM ratings
    WHERE rating_status = 'withdrawn'
    GROUP BY user_id
),
ranked AS (
    SELECT uw.*,
           RANK() OVER (ORDER BY withdrawn DESC) AS rnk,
           ROUND(100.0 * withdrawn / SUM(withdrawn) OVER (), 1)
               AS pct_of_all_withdrawn,
           ROUND(100.0 * SUM(withdrawn) OVER (ORDER BY withdrawn DESC, user_id
                                              ROWS BETWEEN UNBOUNDED PRECEDING
                                                       AND CURRENT ROW)
                       / SUM(withdrawn) OVER (), 1)
               AS running_pct
    FROM user_withdrawals uw
)
SELECT user_id,
       withdrawn,
       rnk,
       pct_of_all_withdrawn,
       running_pct,
       first_withdrawal::date AS first_withdrawal,
       last_withdrawal::date  AS last_withdrawal
FROM ranked
WHERE withdrawn >= 2
ORDER BY withdrawn DESC, user_id;

-- Expected (first rows):
--   user  withdrawn  rnk  pct_of_all  running  first       last
--     8       4       1      11.8      11.8    2023-02-01  2023-11-01
--    16       3       2       8.8      20.6    2023-01-27  2023-09-05
--    23       3       2       8.8      29.4    2023-10-01  2023-12-16
--   (then 7 users with 2 each)
-- Three users are behind 10 of the 34 withdrawals (29.4%). User 8 has three
-- policy violations; user 23's three withdrawals all came in October-December.
