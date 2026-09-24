## Unit 2: Schema Reasoning

## Foreign key constraints

| Foreign key | ON DELETE | Reason |
|---|---|---|
| `movie_genres.movie_id` → `movies.movie_id` | `CASCADE` | A genre tag has no meaning once the movie it describes no longer exists. |
| `movie_genres.genre_id` → `genres.genre_id` | `RESTRICT` | Removing a genre must not silently strip that classification from every movie that uses it. |
| `ratings.user_id` → `users.user_id` | `NO ACTION` (default) | Users are deactivated with `is_active`, not deleted, so their ratings and every movie average built on them stay intact. |
| `ratings.movie_id` → `movies.movie_id` | `CASCADE` | A rating of a movie that no longer exists is meaningless and would only pollute aggregate queries. |

## `movie_genres.movie_id` → `movies`: CASCADE

**The event:** an administrator hard-deletes a movie row. On this platform that is meant for entries that should never have existed, such as a duplicate created by mistake or a test record. A movie that is only being taken off the catalog is hidden with `movies.is_active = FALSE` instead, which keeps all of its rows.

**Who is affected:** only the movie's own genre links. No other movie and no user loses anything, because the link rows belong entirely to the deleted movie.

**Under the alternative:** with `RESTRICT` or `NO ACTION`, deleting a duplicate movie would fail until someone manually deleted its `movie_genres` rows first. That adds a cleanup step that protects nothing, since those links carry no information of their own.

## `movie_genres.genre_id` → `genres`: RESTRICT

**The event:** an administrator tries to delete a genre, for example to merge "sci-fi" into "science fiction" or to retire a category.

**Who is affected:** every movie tagged with that genre, and every user who browses or filters by it. With `RESTRICT`, the delete is refused while any movie still uses the genre. The administrator has to reassign those movies first (for example, by moving the links to "science fiction") and can delete the old genre after that. A genre that no movie uses can be deleted freely.

**Under the alternative:** with `CASCADE`, one `DELETE` on `genres` would quietly remove the tag from hundreds of movies. Some movies could be left with no genre at all and would vanish from genre browsing and recommendations. Nothing would report an error, so the loss could go unnoticed for a long time. Genres are a small, carefully maintained reference list, so making their deletion deliberate costs little.

## `ratings.user_id` → `users`: NO ACTION (default)

**The event:** a user leaves the platform. The platform handles this by setting `users.is_active = FALSE`, and if the user asks for their personal data to be removed, by anonymizing the name and email in place. Actually deleting the row is blocked while the user has ratings.

**Who is affected:** every other user, through movie averages and recommendations. Each rating contributes to a movie's average score. Keeping the rows means those averages don't shift when someone leaves.

**Under the alternatives:**
- `CASCADE` would delete all of the user's ratings. Every movie they rated would get a different average overnight, and a popular title could lose many ratings after one bulk account cleanup.
- `SET NULL` isn't possible with this design, because `user_id` is part of the primary key `(user_id, movie_id)` and primary key columns can't be NULL. Supporting it would require a surrogate `rating_id` key and would leave ratings that belong to nobody.

`NO ACTION` differs from `RESTRICT` only in timing: PostgreSQL checks it at the end of the statement instead of immediately. The effect is the same, because the delete is refused.

## `ratings.movie_id` → `movies`: CASCADE

**The event:** the same hard delete of a movie as above, reserved for mistaken or duplicate entries. Delisted movies are deactivated with `is_active` and keep their ratings.

**Who is affected:** the users who rated that entry lose those specific ratings. That is correct for a duplicate, because the ratings were attached to a record that shouldn't exist.

**Under the alternative:** with `RESTRICT`, removing a bad entry would fail until someone deleted its ratings by hand, which is the same step `CASCADE` performs automatically. The ratings have no value apart from the movie. Keeping them would require them to point at a movie that no longer exists, and the foreign key doesn't allow that.

## CHECK constraints

## `users.email`: `CHECK (email = LOWER(email))`

**Invalid state prevented:** two accounts for the same address that differ only in capitalization, such as `Ana@Mail.com` and `ana@mail.com`. The `UNIQUE` constraint on its own compares strings exactly, so it would accept both.

**How it could otherwise arise:** a user signs up once from a phone that auto-capitalizes the first letter and again from a laptop, or records are imported from another system that stores mixed-case emails, or one code path forgets to lowercase before inserting. The result is duplicate accounts, split rating histories, and failed logins when the lookup's capitalization doesn't match the stored value. Requiring lowercase storage makes the `UNIQUE` constraint effectively case-insensitive.

## `movies.release_year`: `CHECK (release_year BETWEEN 1888 AND 2100)`

**Invalid state prevented:** a release year that couldn't belong to a real film, like `0`, `-2019`, `95`, or `20240`. The lower bound is the year of the earliest surviving motion picture. The upper bound leaves room for announced future releases while still rejecting typos.

**How it could otherwise arise:** a typo in an admin form (`20024`), a two-digit year from an old spreadsheet (`95`), or an import that fills missing values with `0`. Any of these would break sorting by year, "movies from the 90s" filters, and decade statistics.

## `genres.genre_name`: `CHECK (genre_name = LOWER(genre_name))`

**Invalid state prevented:** the same genre existing twice with different capitalization, such as `Comedy` and `comedy`. As with email, `UNIQUE` alone would allow both.

**How it could otherwise arise:** two administrators add the genre at different times with different capitalization, or an import brings in `Drama` when `drama` already exists. The catalog would then be split: some movies tagged with one row and some with the other, and filtering by either would silently miss part of the genre. Display formatting such as title case is handled by the application.

## `ratings.score`: `CHECK (score BETWEEN 1 AND 5)`

**Invalid state prevented:** a score outside the platform's 1–5 scale, such as `0`, `-1`, `7`, or `10`.

**How it could otherwise arise:** a UI bug that sends a zero-indexed star position (0–4), ratings imported from a site that uses a 10-point scale, or a client that calls the API directly and skips front-end validation. A single `10` would inflate a movie's average, and a `0` would drag it down. The resulting numbers would look plausible, so nobody would notice the error. Enforcing the range in the database protects every write path, not just the official UI.
