/*Calculate the following statistics across the entire event table using your theme's metric: the count,
  total, average, minimum, and maximum of your theme’s metric across the whole event table,
  and how many distinct actors appear. Review your results carefully.
  For example, if your metric should never be zero but your minimum value is zero,
  this may indicate another data-quality issue that needs investigation.*/

SELECT COUNT(score)            AS rating_count,
       SUM(score)              AS total_score,
       ROUND(AVG(score), 2)    AS avg_score,
       MIN(score)              AS min_score,
       MAX(score)              AS max_score,
       COUNT(DISTINCT user_id) AS distinct_users
FROM ratings;


/*Write a query that calculates the event count and average metric for each producer.
  Sort the results from the producer with the most events to the producer with the fewest.
  Consider what these results tell you about differences in activity and performance across producers.*/
SELECT m.movie_id,
       COUNT(r.rating_id)     AS rating_count,
       ROUND(AVG(r.score), 2) AS avg_score
FROM movies m
LEFT JOIN ratings r ON r.movie_id = m.movie_id
GROUP BY m.movie_id
ORDER BY rating_count DESC, m.movie_id;

/*Which producers have enough volume for their rate to mean anything?
  A producer with only a few events may have a high failure rate that is not representative of their usual performance.
  Choose a minimum event-count threshold and use HAVING to include only producers who meet that threshold.
  Explain why you selected your threshold.*/

  SELECT movie_id,
       COUNT(*) AS rating_count,
       COUNT(*) FILTER (WHERE rating_status = 'withdrawn') AS withdrawn_count,
       ROUND(100.0 * COUNT(*) FILTER (WHERE rating_status = 'withdrawn') / COUNT(*), 1) AS failure_rate_pct
FROM ratings
GROUP BY movie_id
HAVING COUNT(*) >= 10
ORDER BY failure_rate_pct DESC;

/*I chose 10 because with fewer ratings, one withdrawn rating changes a movie’s failure rate too much. For example, movie 4 has only 6 ratings, so just 2 failures give it a 33% rate.*/

/*How does the picture change along two dimensions at once? Leadership also wants to understand how performance varies across regions.
  Write a query that groups the data by two dimensions, including region, and calculates the relevant summary statistics.
  Your results should contain one row for each combination of the two dimensions so that regional leaders can review their results.*/

SELECT device_country,
       movie_id,
       COUNT(*)                                            AS rating_count,
       ROUND(AVG(score), 2)                                AS avg_score,
       COUNT(*) FILTER (WHERE rating_status = 'withdrawn') AS withdrawn_count,
       ROUND(100.0 * COUNT(*) FILTER (WHERE rating_status = 'withdrawn') / COUNT(*), 1) AS failure_rate_pct
FROM ratings
GROUP BY device_country, movie_id
ORDER BY device_country, movie_id;

