# Unit 6 – Closing memo

**To:** Leadership team
**Subject:** Is the failure problem getting better or worse, and what to do next quarter
**Data:** all 200 ratings, January–December 2023
**Queries:** [`queries/unit6/q6_4.sql`](../queries/unit6/q6_4.sql) (M1–M4), with support from [`q6_2.sql`](../queries/unit6/q6_2.sql) and [`q6_3.sql`](../queries/unit6/q6_3.sql)

A failure is a rating that was withdrawn (`rating_status = 'withdrawn'`): 34 of the 200 ratings.

## The short answer

**Better, but it stopped improving after the spring.** The failure rate fell from **22.6% in Q1 to about 15%** in Q2 to Q4, and then stayed there. The improvement came from **fewer spam and policy violations**. What is left is a steady floor of duplicates and user requests, plus **a few repeat users** and **one movie (9) that got worse**.

## 1. Better or worse?

**The rate dropped once, then held steady** (M1):

| Quarter | Ratings | Withdrawn | Failure rate | Change | Running rate |
|---|---|---|---|---|---|
| Q1 2023 | 53 | 12 | **22.6%** | — | 22.6% |
| Q2 2023 | 48 | 7 | 14.6% | −8.0 pp | 18.8% |
| Q3 2023 | 51 | 8 | 15.7% | +1.1 pp | 17.8% |
| Q4 2023 | 48 | 7 | 14.6% | −1.1 pp | 17.0% |

- **The real improvement happened between Q1 and Q2:** −8.0 percentage points. Since then, the rate has moved by about one point a quarter. It has **flattened, not kept falling**.
- **The 17.0% for the year** that a single SUM would report hides both the bad start and the plateau. The running rate shows the path: 22.6% → 18.8% → 17.8% → 17.0%.
- **Month by month it is noisy** (from 0% in April to 25.0% in June; q6_3.sql, Part B). June was the only month after March as bad as the start of the year, and it fell back to 11.8% in July. June's spike came from five unrelated withdrawals, not a campaign.
- **Volume did not explain it.** Ratings stayed flat at 48–53 a quarter (q6_2.sql, Part B), so the rate fell because fewer ratings failed, not because more ratings came in.

**Why it improved, and why it stopped** (M2):

| Quarter | Spam | Policy violation | Duplicate | User request |
|---|---|---|---|---|
| Q1 | 4 | 4 | 2 | 2 |
| Q2 | 3 | 1 | 1 | 2 |
| Q3 | 3 | 1 | 2 | 2 |
| Q4 | 2 | 2 | 2 | 1 |

- **Moderation failures (spam + policy) halved:** 8 in Q1, then 4 in every quarter after. That is the whole improvement.
- **Duplicates and user requests did not change:** about 3–4 a quarter. They now make up about half of all failures, and nothing done this year has touched them.
- **User requests are not a platform failure.** These are people deleting their own ratings. Without them, Q4's rate would be **12.5%** rather than 14.6% (M1).

**Where the remaining failures come from:**
- **A few repeat users** (M4). Users **8, 16 and 23** are behind **10 of the 34 withdrawals (29.4%)**. User 8 has three policy violations across different movies. User 23's three withdrawals all happened in **October–December**, so this is a current problem, not an old one.
- **The flagged movies went in different directions** (M3). **Movie 11** improved from 44.4% in the first half to 14.3% in the second, and **movie 2** from 30.0% to 16.7%. **Movie 9 got worse: 14.3% → 42.9%** (3 of 7 ratings withdrawn in July–December). Movie 9 also had a 112-day gap with no ratings (q6_2.sql, Part C) and is currently unlisted.

**Caveat:** the numbers are small. One withdrawn rating moves a quarter's rate by about two points. The drop from Q1 is large enough to trust, but the quarter-to-quarter changes after it are not.

## 2. What the team should do next quarter

1. **Fix duplicate ratings in the app.** Duplicates (7 this year, 2 in Q4) are a software problem, not a user problem. Blocking a second rating from the same user for the same movie would remove them. On Q4's numbers, that alone brings the rate from 14.6% to **10.4%** (5 of 48).
2. **Review users 8, 16 and 23.** Three accounts cause almost a third of all failures. Check them for spam or policy patterns and act on the accounts, not on the movies they rated. Start with user 23, who is still active.
3. **Investigate movie 9 before it is listed again.** Its failure rate tripled in the second half, it went silent for almost four months, and it is now unlisted. Find out whether these are connected. Two of its three recent withdrawals were user requests, so check those first.
4. **Report user requests separately.** Show the headline failure rate without them (12.5% in Q4), and track user requests on their own. Mixing them in makes producers look responsible for something they didn't do.
5. **Set a target and an alert.** Target: **a failure rate below 12% in Q1 2024**, which is reachable by fixing duplicates. Alert: any month where the rate rises by more than 10 percentage points *and* there are at least 3 withdrawals. Each alert gets broken down by reason, user and movie (q6_3.sql, Part B) before anyone acts.

## Bottom line

The failure problem is **better than at the start of 2023, but no longer improving**. Moderation fixed the spam and policy problem in the spring. The next gains are in places no one has worked on yet: the duplicate-rating bug, three repeat users, and movie 9. Fixing duplicates alone should bring the rate under 12% next quarter.