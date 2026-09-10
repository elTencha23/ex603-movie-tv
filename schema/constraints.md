# Constraints — ON DELETE Justification

Why CASCADE and RESTRICT were chosen for three foreign keys in the movies database

## Overview

The movies database defines four foreign keys, each with an explicit `ON DELETE` behavior. One of them — `ratings.user_id → users(user_id)` — was left at `NO ACTION`, since users are never hard\-deleted (they are soft\-deleted via the `is_active` flag instead), making the delete behavior largely moot. The other three were deliberately set to either `CASCADE` or `RESTRICT`, and this document explains the reasoning behind each choice.

## 1\. `ratings.movie_id → movies(movie_id)`\: CASCADE

**Decision:** `ON DELETE CASCADE`

**Justification:** A rating only has meaning in the context of the movie it rates. If a movie is removed from the catalog, any ratings tied to it become orphaned data — a score with nothing left to describe. Keeping those rows around would clutter the `ratings` table with references to movies that no longer exist, and any report or aggregate built from `ratings` (like an average score) would have to account for "phantom" rows pointing nowhere.

`CASCADE` keeps the data consistent automatically: deleting a movie removes its ratings in the same operation, with no orphaned rows and no extra cleanup step required.

## 2\. `movie_genres.movie_id → movies(movie_id)`\: CASCADE

**Decision:** `ON DELETE CASCADE`

**Justification:** The same logic as above applies here. A row in `movie_genres` exists only to tag a specific movie with a specific genre — it has no independent meaning without the movie it's tagging. If "The Shining" is deleted from `movies`, its "Horror" and "Drama" tags in `movie_genres` are meaningless leftovers.

`CASCADE` ensures that deleting a movie also removes its genre associations automatically, keeping the junction table free of stale, dangling links.

## 3\. `movie_genres.genre_id → genres(genre_id)`\: RESTRICT

**Decision:** `ON DELETE RESTRICT`

**Justification:** Genres behave differently from movies in this relationship — a genre like "Horror" is a shared, reusable category referenced by potentially hundreds of movies, not a piece of data that belongs to any single movie. Deleting a genre is a much bigger, more consequential action than deleting one movie, since it silently affects every movie currently tagged with it.

`RESTRICT` was chosen over `CASCADE` deliberately: it blocks the deletion of a genre as long as any movie is still tagged with it, forcing that decision to be explicit rather than silent. To delete "Horror," someone would first have to reassign or remove that tag from every movie using it — at which point deleting the now\-unused genre is safe. This prevents an accidental genre deletion from quietly stripping a tag off a large portion of the movie catalog without anyone noticing.

## Summary

| Foreign key | `ON DELETE` | Reasoning in one line |
| --- | --- | --- |
| `ratings.movie_id → movies(movie_id)` | CASCADE | A rating has no meaning without its movie |
| `movie_genres.movie_id → movies(movie_id)` | CASCADE | A genre tag has no meaning without its movie |
| `movie_genres.genre_id → genres(genre_id)` | RESTRICT | A genre is shared across many movies — deleting it should be a deliberate, visible action |
