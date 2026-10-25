# Unit 4 – Reflection

## Who acts on the per-producer breakdown
The **Content Partnerships Manager**, the person who manages the relationship with each movie's producer. They decide which producers to contact, review, or support based on their failure rates.

## What the aggregate hides
- **The average hides the distribution.** Every withdrawn rating has a score of exactly 0.5, which is a placeholder, not a real opinion. A movie's average mixes these placeholders with real scores, so a low average can mean "viewers disliked it" or "many ratings were withdrawn". The average also hides spread: a movie whose ratings are split between 1s and 5s can have the same average as one where every rating is a 3.
- **The count hides who is counted.** Movie 11 has the most failures (5), but they come from 5 different users with different reasons: 2 were "User request", which is not the producer's fault. A few users withdraw repeatedly; user 8, for example, has 4 withdrawn ratings across different movies. Inactive users (5, 7, 22, 26, 28) are counted too.

## What I would need to see next
1. Failures per producer broken down by `withdrawn_reason`, to separate producer problems from user requests.
2. Failures broken down by `user_id`, to see whether a few users drive most of them.
3. The score distribution for each producer (median and spread), with withdrawn ratings excluded.

## Task 4.2 – Write-up

### Part A
The conditional aggregation answers two questions side by side for each producer:
1. How many ratings did this producer receive in total?
2. How many of those ratings failed (were withdrawn)?

### Part B
The **Regional Director** needs subtotals rather than detail rows, because they compare regions, not individual movies. The grand total gives the platform-wide failure rate (17.0%), and that lets them decide whether a region is performing above or below the platform as a whole. The regional rows alone can't show that.

### Part C
The pipeline answers this question: **What is the typical failure rate for high-volume producers (10 or more ratings)?** That rate is the baseline for judging whether any single producer is doing worse than normal.
