-- Task 3.3: Hand the team a corrected query
-- You want to give the dashboard team a query they can trust. The same question can be asked in several ways.
--
--
--
-- What to do
-- Answer a two-step question about your data — for example, which actors were involved in the disputed events — and express it three ways.
--
-- First as a subquery using IN or NOT IN.
-- Then as a Common Table Expression using WITH.
-- Then a third way, distinct from both — a different subquery form, a CASE-based construction, or a set-based approach.
-- Demonstrate that all three return identical result sets. Matching row counts is not enough: show that the rows themselves match.
-- Name one input condition under which the three would not be equivalent. NULLs, duplicates, and empty result sets are the usual places equivalence breaks.

-- I am trying to find the withdrawn ratings and the users behind them

--1 a subquery with IN
SELECT user_id, user_name, country
FROM users
WHERE user_id IN (
    SELECT user_id
    FROM ratings
    WHERE rating_status = 'withdrawn'
)
ORDER BY user_id;

--With a CTE with WITH
WITH disputed AS (
    SELECT DISTINCT user_id
    FROM ratings
    WHERE rating_status = 'withdrawn'
)
SELECT u.user_id, u.user_name, u.country
FROM users u
JOIN disputed d ON d.user_id = u.user_id
ORDER BY u.user_id;

-- The different subquery with  EXISTS
SELECT u.user_id, u.user_name, u.country
FROM users u
WHERE EXISTS (
    SELECT 1
    FROM ratings r
    WHERE r.user_id = u.user_id
      AND r.rating_status = 'withdrawn'
)
ORDER BY u.user_id;

-- Proof that the rows match. AI assisted !!!

    WITH
q1 AS (  -- IN
    SELECT user_id, user_name, country FROM users
    WHERE user_id IN (SELECT user_id FROM ratings WHERE rating_status = 'withdrawn')
),
q2 AS (  -- CTE + JOIN
    SELECT u.user_id, u.user_name, u.country
    FROM users u
    JOIN (SELECT DISTINCT user_id FROM ratings WHERE rating_status = 'withdrawn') d
      ON d.user_id = u.user_id
),
q3 AS (  -- EXISTS
    SELECT u.user_id, u.user_name, u.country FROM users u
    WHERE EXISTS (SELECT 1 FROM ratings r
                  WHERE r.user_id = u.user_id AND r.rating_status = 'withdrawn')
)
SELECT 'q1 not in q2' AS check_name, COUNT(*) AS diff_rows FROM (SELECT * FROM q1 EXCEPT SELECT * FROM q2) x
UNION ALL SELECT 'q2 not in q1', COUNT(*) FROM (SELECT * FROM q2 EXCEPT SELECT * FROM q1) x
UNION ALL SELECT 'q1 not in q3', COUNT(*) FROM (SELECT * FROM q1 EXCEPT SELECT * FROM q3) x
UNION ALL SELECT 'q3 not in q1', COUNT(*) FROM (SELECT * FROM q3 EXCEPT SELECT * FROM q1) x
UNION ALL SELECT 'row counts',   (SELECT COUNT(*) FROM q1) * 10000
                                + (SELECT COUNT(*) FROM q2) * 100
                                + (SELECT COUNT(*) FROM q3);



-- If the three queries are not equivalent, remove the distinct

WITH disputed AS (
    SELECT user_id            -- no DISTINCT
    FROM ratings
    WHERE rating_status = 'withdrawn'
)
SELECT u.user_id, u.user_name
FROM users u
JOIN disputed d ON d.user_id = u.user_id;