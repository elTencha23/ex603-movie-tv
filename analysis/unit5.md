# Unit 5 – Write-up

## 1. A feature that uses the three-table join
A **"Recent Activity" feed** for the moderation team could use it. Each line would show who rated (user name), which movie they rated (title), and when (date and time). Moderators could then spot patterns, such as one user withdrawing many ratings in a short time, without looking up IDs in separate tables.

## 2. Why the junction table matters
A movie can have several genres, and a genre can belong to many movies. The `movie_genres` table records each of these pairs on its own row, so one join links any movie to all of its genres.

Without it, genres would have to be stored inside the `movies` table, either as several genre columns or as one text field like "Drama, Comedy". Then the query would need to check every column or search inside text, and a typo such as "Comdy" would silently hide a movie from the results.

## Task 5.2 – Producers with no events

### 1. Which producers were excluded by the inner join?
**Movies 14 and 15.** The left join returns 15 movies, and the inner join returns 13.

### 2. What does it mean when a producer has no events?
**What the data shows:** movies 14 and 15 have no ratings at all. Both are marked available, and both were added to the catalog in early 2022, more than a year before the first rating. Neither has a genre tag. Movie 13 also has no genre, but it does have ratings, so a missing genre alone does not stop a movie from being rated.

**What would need investigation:** the data cannot tell us why. Possible explanations include:
- The movies are not shown to users, for example because they are missing from search or recommendations without genre tags.
- Users are watching them but not rating them.
- A technical problem is stopping their ratings from being saved.
- There is simply no demand for these titles.

### 3. How an inner join gives an incomplete picture
An inner join only keeps movies that have ratings, so movies 14 and 15 disappear without any warning. A report built this way would describe 13 movies as if they were the whole catalog. Leadership would see failure rates for active movies, but not that 2 of 15 movies (13%) have no activity at all.

### 4. Why identify producers who have never been active
A movie with no ratings has no failure rate, so it can never appear on a "worst performers" list, but it is still a problem. It takes up catalog space and may have licensing costs while giving users nothing. It may also point to a bigger issue, such as a broken tagging or recommendation process, that could affect other movies.

### 5. What action leadership could take
- **Add genre tags** to movies 13, 14 and 15 so they can be found and grouped with similar movies.
- **Check whether movies 14 and 15 are visible** to users in search and recommendations, and whether anyone has watched them.
- **Change dashboards to use left joins**, so movies with zero activity show up as zero instead of disappearing.
- **Decide whether to keep or remove** these titles once the investigation explains why they are inactive.

## Task 5.3 – Join performance and execution plans

### 1. When a Cartesian product is useful
A cross join of `movies` (15 rows) and `genres` (5 rows) gives all 75 possible movie and genre pairs. Comparing that list with `movie_genres` (25 rows) shows every pair that is not tagged, which helps the catalog team spot missing tags, such as movies 13, 14 and 15, which have none. Outside of deliberate cases like this, an unexpected Cartesian product usually means a join is missing its `ON` condition.

### 2. Join algorithms PostgreSQL chose
- **Hash Join** to combine `ratings` with `users`.
- **Nested Loop with Memoize** to look up each rating's movie through the `movies_pkey` index.
- A final **Sort** (quicksort) on `rated_at`.

### 3. What the plan shows about those choices
- **Small tables:** `ratings` was read with a Seq Scan (200 rows, 3 buffers) and `users` fit into a 10 kB hash table in a single batch. At this size, reading whole tables is cheaper than using an index.
- **No index on `ratings.user_id`:** the only way to match users was a hash table, so PostgreSQL built one from `users`.
- **An index on `movies.movie_id`:** the primary key allowed a direct Index Scan for each movie.
- **Few distinct movies:** Memoize recorded 13 misses and 187 hits. Only 13 movies were ever looked up in the index; every other row reused a cached result.
- **Estimates were off:** the planner expected 100 users but found 30, because the tables had not been analyzed since loading.
- **Everything ran in memory:** the sort used 37 kB, and execution took 0.213 ms, less than the 3.019 ms spent planning.

### 4. Why understanding the join algorithm is useful
The plan shows where the work happens and which part will slow down first as the data grows. Here it shows that the query reads every rating and sorts them all, which is fast at 200 rows but becomes the bottleneck at millions. Knowing this lets us add the right index before users notice slow dashboards, instead of guessing.

### 5. Changes that could lead to another join algorithm
- **Many more movies:** Memoize works because only 13 distinct movies were rated. With thousands, the cache would miss often, and a **Hash Join** on `movies` would likely become cheaper.
- **Much larger `users` or `ratings`:** if the hash table no longer fits in `work_mem` (Batches greater than 1), PostgreSQL may switch to a **Merge Join**, especially if both inputs are already sorted by the join key.
- **Indexes on `ratings(user_id)` or `ratings(movie_id)`:** for queries that filter on one user or movie, PostgreSQL could use a **Nested Loop with Index Scan** and skip reading the whole table.
- **An index on `ratings(rated_at)`:** this would let PostgreSQL read ratings already in date order and drop the Sort step.
- **Running `ANALYZE`:** with accurate row counts, the planner's estimates would match reality and it might choose a different plan.

## Reflection

In my execution plan, PostgreSQL used a Hash Join to match ratings with users and a Nested Loop with Memoize to look up movies. Both choices depend on the data being small. The users table fit into a 10 kB hash table, and only 13 different movies appeared in the ratings, so 187 of the 200 movie lookups came straight from the cache.

Several changes could shift these choices. If the catalog grew to thousands of movies, the Memoize cache would miss far more often, and a Hash Join on movies would probably become cheaper. If ratings and users grew to millions of rows, the hash table might not fit in memory; PostgreSQL would then split it into batches on disk or switch to a Merge Join, which works well when both sides are already sorted.

Indexes matter just as much. Today ratings.user_id and ratings.movie_id have no index, so the query must read every rating. Adding indexes would let a query about one user or one movie jump straight to the matching rows with an Index Scan, while an index on rated_at would remove the sort step. Finally, the planner guessed 100 users when there were 30, because the tables had not been analyzed. Accurate statistics help PostgreSQL pick the fastest plan as the platform grows.