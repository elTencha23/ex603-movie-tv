# Unit 4 – Finding

## The breakdown

**The true failure rate is 17%.** Of the platform's 200 ratings, 34 were withdrawn, which is about 1 in every 6.

**It varies widely across producers.** Among producers with at least 10 ratings, failure rates range from **0%** (movie 10) to **31%** (movie 11). The typical rate for these producers is also about 17%. Two producers, movies 14 and 15, have no ratings yet. Movie 4 has the highest rate (33%), but with only 6 ratings it is too small a sample to judge fairly.

**Producers to investigate:**

| Producer | Ratings | Failures | Failure rate |
|---|---|---|---|
| Movie 11 | 16 | 5 | 31% |
| Movie 9 | 14 | 4 | 29% |
| Movie 2 | 16 | 4 | 25% |

- **Movie 11** has both the most failures and the highest rate among producers with enough ratings. Note that 2 of its 5 failures were user requests, which may not be the producer's fault.
- **Movie 9** fails at well above the typical rate, and it is also currently marked unavailable on the platform.
- **Movie 2** fails at about one and a half times the typical rate.

## Reflection

Conditional aggregation reads the ratings table once. As each row is read, the database checks its status and adds it to the right counters, so the total and the number of failures come out of the same pass. Running two separate filtered queries does the same work twice: one query scans the table to count all ratings, and a second scans it again to count only the withdrawn ones. The results then have to be joined back together by producer, which is a third step and another place for mistakes.

With 200 rows the difference is invisible, but at a million rows each scan takes real time, memory and disk reads, so two queries roughly double the cost, and every extra metric adds another scan. A single pass also guarantees consistency. If new ratings arrive between two separate queries, the total and the failure count can describe slightly different data, and the failure rate calculated from them will be wrong. Leadership has already seen, with the frozen payout, what a wrong failure rate can cost. Conditional aggregation keeps every number in the same snapshot, makes the query shorter and easier to review, and makes it simple to add more metrics, such as flagged ratings, without adding more queries.
