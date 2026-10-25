# ex603-movie-tv
Student name: Paul Astorga. 

Theme: Movie / TV

Description: Repository for weekly assignments and final project for Data and Algorithms for Scalable Systems EX603

# Assignment 2 

## Schema

The database (PostgreSQL) stores users, a movie catalog, the genres each movie belongs to, and the ratings users give to movies.

### Tables

| Table | Purpose | Primary key |
|---|---|---|
| `users` | Platform accounts: name, email, sign-up time, and whether the account is active. | `user_id` |
| `movies` | The movie catalog: title, release year, and whether the movie is listed. | `movie_id` |
| `genres` | The reference list of genres, such as `comedy` or `drama`. | `genre_id` |
| `movie_genres` | Links movies to genres. A movie can have several genres, and a genre covers many movies. | `(movie_id, genre_id)` |
| `ratings` | A user's 1–5 score for a movie, with the time it was given. | `(user_id, movie_id)` |

```
users ──< ratings >── movies ──< movie_genres >── genres
```

### Design decisions

- **Soft deletes with `is_active`.** Users and movies are deactivated, not deleted. This keeps ratings and movie averages stable when an account closes or a title is delisted. A hard `DELETE` is reserved for entries that should never have existed, such as duplicates.
- **Composite primary keys instead of surrogate IDs.** `movie_genres` and `ratings` are keyed on the pair of IDs they connect. That makes it impossible to tag a movie with the same genre twice or for a user to rate the same movie twice, without needing a separate `UNIQUE` constraint.
- **Deliberate `ON DELETE` rules.**
  - Deleting a movie cascades to its genre links and ratings, since they have no meaning without it.
  - Deleting a genre is blocked (`RESTRICT`) while any movie still uses it, so a classification can't disappear silently.
  - Deleting a user who has ratings is blocked. Deactivate them with `is_active` instead.
- **Case-insensitive uniqueness through lowercase storage.** `users.email` and `genres.genre_name` are `UNIQUE` and have a `CHECK` that the value is lowercase. This prevents duplicates like `Ana@Mail.com` and `ana@mail.com`, or `Comedy` and `comedy`. The application lowercases values before writing them.
- **Range checks on numbers.** `release_year` must be between 1888 and 2100, and `score` must be between 1 and 5. Typos and bad imports are rejected by the database instead of corrupting sorting and averages.
- **IDs are supplied explicitly.** `user_id`, `movie_id` and `genre_id` are plain `INT` primary keys, so each insert must provide the ID.

The full reasoning behind every foreign key and `CHECK` constraint is in [analysis/unit2.md](analysis/unit2.md).

# Query Catalogue

## Unit 4 – Aggregation

### 4.1.1 Platform summary
**Business question:** What do ratings look like across the whole platform, and how many users are rating?

```sql
SELECT COUNT(score)            AS rating_count,
       SUM(score)              AS total_score,
       ROUND(AVG(score), 2)    AS avg_score,
       MIN(score)              AS min_score,
       MAX(score)              AS max_score,
       COUNT(DISTINCT user_id) AS distinct_users
FROM ratings;
```

### 4.1.2 Activity and score per producer
**Business question:** Which producers get the most ratings, and how well do they score?

```sql
SELECT m.movie_id,
       COUNT(r.rating_id)     AS rating_count,
       ROUND(AVG(r.score), 2) AS avg_score
FROM movies m
LEFT JOIN ratings r ON r.movie_id = m.movie_id
GROUP BY m.movie_id
ORDER BY rating_count DESC, m.movie_id;
```

### 4.1.3 Failure rate for producers with enough volume
**Business question:** Which producers have enough ratings (10+) for their failure rate to be meaningful, and what is that rate?

```sql
SELECT movie_id,
       COUNT(*) AS rating_count,
       COUNT(*) FILTER (WHERE rating_status = 'withdrawn') AS withdrawn_count,
       ROUND(100.0 * COUNT(*) FILTER (WHERE rating_status = 'withdrawn') / COUNT(*), 1) AS failure_rate_pct
FROM ratings
GROUP BY movie_id
HAVING COUNT(*) >= 10
ORDER BY failure_rate_pct DESC;
```

### 4.1.4 Performance by region and producer
**Business question:** How does each producer perform in each region?

```sql
SELECT device_country,
       movie_id,
       COUNT(*)                                            AS rating_count,
       ROUND(AVG(score), 2)                                AS avg_score,
       COUNT(*) FILTER (WHERE rating_status = 'withdrawn') AS withdrawn_count,
       ROUND(100.0 * COUNT(*) FILTER (WHERE rating_status = 'withdrawn') / COUNT(*), 1) AS failure_rate_pct
FROM ratings
GROUP BY device_country, movie_id
ORDER BY device_country, movie_id;
```

### 4.2.A Total and failed ratings per producer
**Business question:** For each producer, how many ratings did it receive, and how many of them failed?

```sql
SELECT movie_id,
       COUNT(*) AS total_ratings,
       SUM(CASE WHEN rating_status = 'withdrawn' THEN 1 ELSE 0 END) AS failed_ratings
FROM ratings
GROUP BY movie_id
ORDER BY failed_ratings DESC, movie_id;
```

### 4.2.B Regional subtotals and platform total
**Business question:** What is the failure rate in each region, and how does it compare with the platform as a whole?

```sql
SELECT CASE WHEN GROUPING(device_country) = 1 THEN 'ALL REGIONS'
            ELSE device_country END AS region,
       COUNT(*) AS total_ratings,
       SUM(CASE WHEN rating_status = 'withdrawn' THEN 1 ELSE 0 END) AS failed_ratings,
       ROUND(100.0 * SUM(CASE WHEN rating_status = 'withdrawn' THEN 1 ELSE 0 END) / COUNT(*), 1) AS failure_rate_pct
FROM ratings
GROUP BY ROLLUP (device_country)
ORDER BY GROUPING(device_country), region;
```

### 4.2.C Baseline for high-volume producers
**Business question:** What is the typical failure rate for producers with 10 or more ratings?

```sql
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
```
