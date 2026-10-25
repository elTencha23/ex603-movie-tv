/*For each producer, compute the total number of events and the total number of events classified as failures,
  in a single pass over the event table, without a WHERE clause filtering the whole query.
  The outliers here are the producers you will name in your finding.
✓  CASE used inside an aggregate — for example SUM(CASE WHEN ... THEN 1 ELSE 0 END) or COUNT(CASE WHEN ... END).
✓  Both totals appearing as separate columns in one result set.*/

SELECT movie_id,
       COUNT(*) AS total_ratings,
       SUM(CASE WHEN rating_status = 'withdrawn' THEN 1 ELSE 0 END) AS failed_ratings
FROM ratings
GROUP BY movie_id
ORDER BY failed_ratings DESC, movie_id;

/*Part B: Subtotals and a grand total
The regional director wants subtotals per region and a platform grand total,
  not the detail rows. Write a query that produces regional subtotals and a platform-wide
  grand total without including the individual detail rows.

✓  GROUP BY ROLLUP (...), or GROUPING SETS or CUBE.
✓  A written note identifying which rows are the subtotals and which is the grand total.*/

SELECT CASE WHEN GROUPING(device_country) = 1 THEN 'ALL REGIONS'
            ELSE device_country END AS region,
       COUNT(*) AS total_ratings,
       SUM(CASE WHEN rating_status = 'withdrawn' THEN 1 ELSE 0 END) AS failed_ratings,
       ROUND(100.0 * SUM(CASE WHEN rating_status = 'withdrawn' THEN 1 ELSE 0 END) / COUNT(*), 1) AS failure_rate_pct
FROM ratings
GROUP BY ROLLUP (device_country)
ORDER BY GROUPING(device_country), region;

/*Part C: A two-step pipeline
Leadership wants to establish a baseline for evaluating high-volume producers.
  That needs two steps: use a WITH clause to create an intermediate result
  that summarizes performance for each producer, then use a second aggregation or
  filter on that intermediate result to calculate a baseline for high-volume producers.

✓  A WITH clause producing an intermediate aggregate.
✓  A second aggregation or filter applied to that intermediate result.*/

WITH producer_summary AS (
    SELECT movie_id,
           COUNT(*) AS total_ratings,
           SUM(CASE WHEN rating_status = 'withdrawn' THEN 1 ELSE 0 END) AS failed_ratings,
           100.0 * SUM(CASE WHEN rating_status = 'withdrawn' THEN 1 ELSE 0 END) / COUNT(*) AS failure_rate_pct
    FROM ratings
    GROUP BY movie_id
)
SELECT COUNT(*)                         AS high_volume_producers,
       ROUND(AVG(failure_rate_pct), 1)  AS baseline_failure_rate_pct,
       ROUND(MIN(failure_rate_pct), 1)  AS lowest_rate_pct,
       ROUND(MAX(failure_rate_pct), 1)  AS highest_rate_pct
FROM producer_summary
WHERE total_ratings >= 10;