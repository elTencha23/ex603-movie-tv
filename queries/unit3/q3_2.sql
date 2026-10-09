-- 3.2 Part A: The rows that vanished
-- SQL uses three-valued logic: TRUE, FALSE, and UNKNOWN. A comparison against NULL yields UNKNOWN,
-- and a WHERE clause keeps only rows where the predicate is TRUE.
-- A filter that looks exhaustive can therefore discard rows silently,
-- without an error and without warning anyone.
--
-- Reproduce it:
--
-- Pick a nullable column on your event or producer table. If the dataset has no NULLs in it, insert a few deliberately and say that you did.
-- Write a query with a negation or inequality predicate on that column — for example WHERE status != 'completed' — and record the row count it returns.
-- Write a second query counting the rows the first one silently omitted, and show that the two counts do not sum to the table total.
-- Repair the first query using an explicit IS NULL condition or COALESCE, so it returns what you intended.

-- I picked ratings.withdrawn_reason, it holds 166 NULLs, I want to know all the ratings that wasnt removed by spam

SELECT COUNT(*) AS not_spam
FROM ratings
WHERE withdrawn_reason <> 'Spam detected';

--Result: 22. But I was expecting 188 (200 minus 12 spam),
-- but I only got the other reasons

SELECT
    (SELECT COUNT(*) FROM ratings WHERE withdrawn_reason <> 'Spam detected') AS not_equal,
    (SELECT COUNT(*) FROM ratings WHERE withdrawn_reason =  'Spam detected') AS equal,
    (SELECT COUNT(*) FROM ratings WHERE withdrawn_reason IS NULL)            AS silently_omitted,
    (SELECT COUNT(*) FROM ratings)                                           AS table_total;

--for a NULL row, NULL <> 'Spam detected' evaluates to UNKNOWN,
-- not TRUE. NULL = 'Spam detected' is also UNKNOWN.
-- WHERE keeps only rows that are TRUE, so those rows fail both conditions.

-- The fix, add an explicit IS NULL in the query

SELECT COUNT(*) AS not_spam
FROM ratings
WHERE withdrawn_reason <> 'Spam detected'
   OR withdrawn_reason IS NULL;

-- With a COALESCE:

SELECT COUNT(*) AS not_spam
FROM ratings
WHERE COALESCE(withdrawn_reason, 'No reason provided') <> 'Spam detected';

SELECT rating_id,
       user_id,
       movie_id,
       score,
       rating_status,
       withdrawn_reason,                                              -- raw value (NULL shows as <null>)
       COALESCE(withdrawn_reason, 'No reason provided') AS reason_label
FROM ratings
WHERE COALESCE(withdrawn_reason, 'No reason provided') <> 'Spam detected'
ORDER BY rating_id;

-- Part B: The alias that did not exist yet
-- SQL is written FROM, WHERE, SELECT, ORDER BY, but it is not evaluated in that order.
--
--
--
-- Write a query defining an alias in SELECT and referencing that alias in WHERE. Capture the error message verbatim.
-- Produce two correct rewrites: one repeating the expression in WHERE, one wrapping the query in a CTE or subquery so the alias becomes a real column.

SELECT rating_id, score, weight,
       score * weight AS weighted_score
FROM ratings
WHERE weighted_score > 7;

--[42703] ERROR: column "weighted_score" does not exist

-- Fix 1

SELECT rating_id, score, weight,
       score * weight AS weighted_score
FROM ratings
WHERE score * weight > 7;

-- Fix 2

WITH w AS (
    SELECT rating_id, score, weight,
           score * weight AS weighted_score
    FROM ratings
)
SELECT *
FROM w
WHERE weighted_score > 7;