# Unit 6 · Window functions

In this project an **event** is one rating (200 rows in `ratings`), a **producer** is the movie being rated (15 movies, 13 with ratings), the **metric** is `score`, and a **failure** is a rating with `rating_status = 'withdrawn'` (34 of 200).

---

# Task 6.1 · Compute across a window without collapsing

Queries: [`queries/unit6/q6_1.sql`](../queries/unit6/q6_1.sql)

## 1. A question that needs each row next to its group's average

> **Which individual ratings are far below what is normal for their movie, and who gave them?**

To answer this, every rating has to sit on the same row as its movie's average, so the two can be compared. `AVG(score) OVER (PARTITION BY movie_id)` does that: it keeps all **200 ratings** and adds the movie's average to each one.

The result shows ratings that look nothing like the rest of their movie:

| Rating | Movie | User | Score | Movie average | Difference |
|---|---|---|---|---|---|
| 123 | 8 | 11 | 0.8 | 3.41 | −2.61 |
| 79 | 6 | 23 | 0.8 | 3.32 | −2.52 |
| 145 | 10 | 2 | 0.8 | 3.31 | −2.51 |
| 36 | 3 | 22 | 5.0 | 2.76 | +2.24 |

Ratings like these are worth a second look. They could be honest outliers, but they could also be a review-bombing pattern or a user who rates everything at the extremes. Either way, someone can now check them by rating ID and user.

`GROUP BY movie_id` cannot answer this question. It returns **13 rows**, one per rated movie, with the same averages, but the individual ratings are gone: no rating ID, no user, no score, no status. It tells us what is normal for each movie but not which ratings break from it. To get the ratings back, we would have to join the grouped result to `ratings` again, which is exactly what the window function does in one step.

**A data note:** every withdrawn rating has a placeholder score of **0.5**, not a real opinion. I left them out of the average with `FILTER (WHERE rating_status <> 'withdrawn')`, but kept them as rows. Including them would make movies with many withdrawals look worse than they are: movie 11's average would drop from **2.82 to 2.09**.

## 2. Ranking is never neutral

**Feature: a "Most Rated" row on the home screen**, showing the movies with the most ratings. Placement on that row means more views for a movie, so the order matters to the people who made it.

In our data, four pairs of movies are tied on number of ratings: **5 & 7** (18), **2 & 11** (16), **1 & 13** (11) and **14 & 15** (0). The three functions handle the tie at 18 differently:

| Function | Movie 5 | Movie 7 | Movie 12 (next) | What it says |
|---|---|---|---|---|
| `ROW_NUMBER()` | 4 | 5 | 6 | Movie 5 beats movie 7, but only because its ID is smaller |
| `RANK()` | 4 | 4 | 6 | They are equal, and five movies are ahead of movie 12 |
| `DENSE_RANK()` | 4 | 4 | 5 | They are equal, and movie 12 is 5th, although five movies have more ratings |

**The feature should use `RANK()`.**

- **Not `ROW_NUMBER()`**, because it invents a winner. Movie 7 would be shown below movie 5 because of an ID number, not because fewer people rated it. On a public row that decides visibility, that is unfair to movie 7.
- **Not `DENSE_RANK()`**, because it makes positions after a tie look better than they are. At the bottom of the list, movies 14 and 15 would be shown as 11th, even though 13 movies have more ratings than they do.
- **`RANK()`** shows tied movies as equals and keeps every later position honest: a movie's place is 1 + the number of movies with more ratings.

The tie becomes a real decision if the row has a fixed number of slots. A **"Top 4" row lands exactly on the tie**: positions 4 and 5 are movies 5 and 7, both with 18 ratings. With `RANK() <= 4` the row would show five movies. The platform has to choose openly: either show both tied movies, or use `ROW_NUMBER()` with a stated tie-breaker (for example, "most recent rating wins"), not a hidden one like the movie ID. `NTILE(4)` shows the same problem: it puts movie 5 in the top band and movie 7 in the second band, even though their counts are identical.

---

# Task 6.2 · Compare each row to its neighbors

Queries: [`queries/unit6/q6_2.sql`](../queries/unit6/q6_2.sql)

## 1. What a large delta tells you, and what to do about it

The delta is the change in score from one rating of a movie to the next. I followed **movie 11**, the movie with the most withdrawn ratings (5 of 16), leaving withdrawn ratings out so that only real scores are compared.

Two kinds of large delta show up:
- **A single jump.** In February, a 5.0 is followed by a 2.2 (rating 167, **delta −2.8**). One rating very different from the last usually just means two people disagree. On its own, it is not something to act on.
- **A run of drops.** From July to August, three ratings in a row fall: **3.7 → 2.5 → 1.4 → 1.0** (deltas −1.2, −1.1, −0.4), before recovering to 3.3–3.5 in October. Several drops in a row is a trend, and that is the signal worth acting on.

On a movie platform, a run of drops means either that viewers' opinion really changed (a re-release, a new audience, a bad cut), or that someone is pushing the score down (review bombing).

What someone should do:
1. **Check who gave the low ratings.** For movie 11, the three low ratings come from **three different users** (21, 17 and 26) in two countries, and all three were published normally. That points away from a single bad actor.
2. **Check the moderation history.** Movie 11 already had four ratings withdrawn earlier in the year (spam, policy violation and two user requests). One of the low ratings comes from user 21, whose earlier rating of this movie was withdrawn as spam. That is worth a moderator's look.
3. **Act on the trend, not one row.** Alert the content team when a movie has two or more consecutive drops, and let moderation review the users behind them before the movie's average is shown publicly.

## 2. Why a running total answers what a plain SUM cannot

A plain `SUM` gives one number for the year: **200 ratings, 34 of them withdrawn, a 17.0% failure rate**. That says where the platform ended, not how it got there.

The running totals keep every month and show the path:
- **When the failure problem improved.** The running failure rate started at **23.8% in January** and stayed above 21% through March. It dropped to **about 17% by May** and then stayed between 16.8% and 18.8% for the rest of the year. A single 17% hides both the bad start and the fact that nothing improved after spring.
- **Progress against a target during each quarter.** With a target of 50 ratings per quarter, the quarter-to-date running total shows Q1 crossing the line in March (106%) and Q3 in September (102%), while Q2 and Q4 each ended **two ratings short (96%)**. A SUM per quarter tells you the final count, but not how far behind a quarter was with one month left.

That is the question leadership asked: where things stand now *and* how they got there.

## 3. Why a 3-month moving average

I used `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` on monthly ratings, which is a 3-month window.

- **It matches how the platform is measured.** Three months is one quarter, the same period as the target.
- **It smooths noise without hiding real changes.** March and April had only 11 ratings each, after 21 in both January and February. Raw monthly numbers (a 1-row window) make that look like volume halved overnight. The 3-month average shows a dip to **13.0 in May** and a recovery to **about 18 by the summer**, ending the year at 16.
- **A bigger window would hide the spring dip.** A 6-month window stays between **15.7 and 17.7** from June to December: a flat line that suggests nothing ever happened. A 12-month window would just be the yearly average, and with only 12 months of data, it would have a single full value.
- **Every month has ratings**, so 3 rows really are 3 calendar months. At day level they would not be: only 155 of the 365 days have a rating, so a 7-row window would usually cover more than a week.

A different window tells a different story: 1 month says "March was a crash," 6 months says "flat all year," and 3 months says "a spring dip, then steady." The 3-month view matches the data best.

## 4. What the gap means

The clearest gap is **movie 9: one rating on 5 January 2023, then nothing for 112.6 days, until 28 April**. After that, it was rated regularly until December. Movie 12 has a similar 106.7-day pause in spring.

There are three possible explanations:

| Explanation | Evidence | Verdict |
|---|---|---|
| **Data quality problem** (ratings were lost) | The platform recorded ratings every month of the gap (21 in February, 11 in March, 11 in April), and **every other movie that was already being rated received ratings in that period** (from 1 to 9 each). An outage would have hit them too. | Unlikely |
| **Side effect of how events are recorded** | Problem ratings are not deleted: they stay in the table with `rating_status = 'withdrawn'` (34 rows). So a gap cannot come from moderators removing spam. | No |
| **Real stop in activity** (nobody rated it) | Movie 9 is the only active movie with no ratings during those months, and its ratings resume at the usual pace afterwards. | **Most likely** |

**My conclusion: it's a real stop in activity.** People stopped rating movie 9 for almost four months and then started again.

**What I can't tell is *why*.** The `movies` table shows movie 9 as **not listed** today, and one possibility is that it was unlisted during those months and listed again later. The table only stores the current status, not its history, so the data can't confirm or rule this out. Movie 9 is also one of the three movies flagged in Unit 5 for high failure rates.

**The response** is to check the catalog history for movie 9 between January and April 2023. If it was unavailable, the gap is explained, and the fix is to store listing changes with dates so future gaps can be explained from the data. If it was available, the gap is a real lack of interest, and that belongs with the content team, alongside its high failure rate.

---

# Task 6.3 · Build the reporting patterns

Queries: [`queries/unit6/q6_3.sql`](../queries/unit6/q6_3.sql)

## 1. The feature top-N would power, and why three

**Feature: a "Top reviews" panel on each movie's page**, showing the three highest ratings the movie has received. Part A builds it: rank each movie's ratings (`PARTITION BY movie_id`), keep the top three, and use `FIRST_VALUE` and `LAST_VALUE` to show the movie's best and worst score next to them.

**Why three, and not one or ten:**
- **One is decided by the tie-breaker, not by viewers.** High scores tie constantly: movie 5 has **seven 5.0 ratings**, movie 10 six and movie 8 five. A single "top review" would be whichever 5.0 the tie-breaker picks. One review also suggests a consensus that isn't there: every movie except movie 1 has a 5.0, yet the worst real ratings go as low as 0.8.
- **Ten is more than many movies have.** Leaving out withdrawn ratings, movie 4 has only **4** real ratings, and movies 3, 9 and 13 have 10 each. A top ten would show every rating for those movies, including the bad ones, so it stops being a highlight and becomes the full list.
- **Three is selective and still honest.** For the most-rated movies (8 and 10, with 19 real ratings each) it picks 3 of 19, a real selection. It fits on a movie page and on a phone screen without scrolling. Shown next to the movie's lowest score (from `LAST_VALUE`), it highlights the best reviews without hiding that opinions differ.
- **Three makes the tie rule visible but manageable.** With `ROW_NUMBER()` and "newer review wins," the panel always shows exactly three reviews, and the rule keeps it fresh. With `RANK()`, movie 5's panel would show seven reviews.

One condition for the real feature: the panel should show only **published** ratings. Part A includes flagged ones (for example, rating 184 for movie 12), and a review under investigation shouldn't be promoted on the movie's page.

## 2. What a large month-over-month change means, and what to do about it

On this platform, the month-over-month change that matters most is the **failure rate**, the share of ratings that get withdrawn. A rise means more ratings are spam, duplicates, policy violations or retracted by users. That makes movie averages less trustworthy and gives moderators more work.

The biggest rise is **June 2023: the failure rate went from 11.8% to 25.0% (+13.2 percentage points)**, with withdrawals going from 2 to 5 (+150%).

What someone should do when a change like that appears:

1. **Only react when the change is large *and* real.** With 11–21 ratings a month, single ratings move the percentages a lot: April's 0% failure rate was simply a month with no withdrawals. A sensible rule is to **alert when the failure rate rises by more than 10 percentage points *and* there are at least 3 withdrawals that month**. June meets it. May (+11.8 pp, but only 2 withdrawals) does not.
2. **Break the spike down before reacting.** June's 5 withdrawals came from **5 different users, on 4 movies, from 4 countries, with 4 different reasons**: one spam, one duplicate, one policy violation and **two user requests**. That is not a spam campaign or a bug; it's an unlucky month.
3. **Separate the reasons, because they need different owners.** Spam (12 of the 34 withdrawals for the year) and policy violations (8) go to moderation. Duplicates (7) point to an app or data bug and go to engineering. User requests (7) are people deleting their own ratings, so they aren't a platform failure. Two of June's five withdrawals were user requests on movie 11, which is worth noting on that movie, but not worth an alarm.
4. **Check the next month.** In July the rate fell back to 11.8% (−13.2 pp), which confirms that June was a spike, not a new level.

The month-over-month change is the **trigger**, not the answer. It becomes a metric only when it has a threshold, an owner and a next step: when it fires, someone breaks the month down by reason, user and movie, and sends each part to the team that can fix it.

---

# Reflection

A question that is easy with a window function but awkward with GROUP BY is: **"How long did each movie go between one rating and the next, and which movies had gaps longer than 100 days?"** On our platform it found movie 9, which received one rating on 5 January 2023 and then nothing for 112 days.

GROUP BY can describe each movie's ratings as a whole: how many there are, the first and last date, the average score. But every one of those answers collapses the ratings into a single row, and a gap only exists *between* two ratings. Once the rows are grouped, their order is gone, and so is any idea of "the previous rating."

Without a window function, I would have to join `ratings` to itself and, for every rating, look up the latest earlier rating of the same movie with a correlated subquery (`MAX(rated_at) < current rated_at`). That is hard to read, easy to get wrong when two ratings share a timestamp, and it compares every rating with every other one, so it slows down as the platform grows.

With `LAG(rated_at) OVER (PARTITION BY movie_id ORDER BY rated_at)`, each rating simply sees the one before it. Every row stays, the gap is one subtraction, and an outer `WHERE` keeps only the long ones. The window function keeps the detail that grouping throws away.

