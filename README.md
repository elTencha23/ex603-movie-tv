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