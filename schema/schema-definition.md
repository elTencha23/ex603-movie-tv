# Movies Database Schema Definition

Relation schemas, attribute domains, and keys for all five tables

## Overview

This document defines the relational schema for the movies database, implemented in PostgreSQL. Five tables make up the schema: `users`, `movies`, `ratings`, `genres`, and `movie_genres`. In each relation schema below, the primary key attribute(s) are shown in **bold**, and foreign key attributes are marked *(FK)*.

## users

**Relation schema**

USERS(**user\_id**, first\_name, last\_name, email, is\_active, created\_at)

| Attribute | Domain | Key |
| --- | --- | --- |
| user\_id | Integer, auto\-incremented, \> 0 | **Primary Key** |
| first\_name | Character string, up to 100 characters, required |  |
| last\_name | Character string, up to 100 characters, required |  |
| email | Character string, up to 255 characters, required, unique across the table |  |
| is\_active | Boolean, {true, false}, defaults to true |  |
| created\_at | Date, defaults to the current date |  |

Primary Key: `user_id`

Users are never hard\-deleted — `is_active` is flipped to false instead, preserving rating history and allowing reactivation later.

## movies

**Relation schema**

MOVIES(**movie\_id**, title, is\_active, release\_year)

| Attribute | Domain | Key |
| --- | --- | --- |
| movie\_id | Integer, auto\-incremented, \> 0 | **Primary Key** |
| title | Character string, up to 255 characters, required |  |
| is\_active | Boolean, {true, false}, defaults to true |  |
| release\_year | Integer, required |  |

Primary Key: `movie_id`

## ratings

**Relation schema**

RATINGS(**rating\_id**, *user\_id (FK)*, *movie\_id (FK)*, created\_at, score)

| Attribute | Domain | Key |
| --- | --- | --- |
| rating\_id | Integer, auto\-incremented, \> 0 | **Primary Key** |
| user\_id | Integer, must match an existing `users.user_id` | *Foreign Key → users(user\_id)* |
| movie\_id | Integer, must match an existing `movies.movie_id` | *Foreign Key → movies(movie\_id)* |
| created\_at | Date, defaults to the current date |  |
| score | Integer, required |  |

Primary Key: `rating_id`
Foreign Keys: `user_id` references `users(user_id)` — `ON DELETE NO ACTION`; `movie_id` references `movies(movie_id)` — `ON DELETE CASCADE`

## genres

**Relation schema**

GENRES(**genre\_id**, genre\_name)

| Attribute | Domain | Key |
| --- | --- | --- |
| genre\_id | Integer, auto\-incremented, \> 0 | **Primary Key** |
| genre\_name | Character string, up to 100 characters, required, unique across the table |  |

Primary Key: `genre_id`

## movie\_genres

**Relation schema**

MOVIE\_GENRES(**movie\_genre\_id**, *movie\_id (FK)*, *genre\_id (FK)*)

| Attribute | Domain | Key |
| --- | --- | --- |
| movie\_genre\_id | Integer, auto\-incremented, \> 0 | **Primary Key** |
| movie\_id | Integer, must match an existing `movies.movie_id` | *Foreign Key → movies(movie\_id)* |
| genre\_id | Integer, must match an existing `genres.genre_id` | *Foreign Key → genres(genre\_id)* |

Primary Key: `movie_genre_id`
Foreign Keys: `movie_id` references `movies(movie_id)` — `ON DELETE CASCADE`; `genre_id` references `genres(genre_id)` — `ON DELETE RESTRICT`
Additional constraint: the pair (`movie_id`, `genre_id`) is unique — a movie cannot be linked to the same genre twice.

## Relationships at a glance

- `users` → `ratings`\: one user can leave many ratings (one\-to\-many).
- `movies` → `ratings`\: one movie can receive many ratings (one\-to\-many).
- `movies` ↔ `genres`\: many\-to\-many, resolved through the `movie_genres` junction table.

**Referential actions (`ON DELETE`)**

| Foreign key | Behavior | Effect |
| --- | --- | --- |
| `ratings.user_id → users(user_id)` | `NO ACTION` | Blocks deleting a user with existing ratings — moot in practice, since users are soft\-deleted via `is_active` rather than removed |
| `ratings.movie_id → movies(movie_id)` | `CASCADE` | Deleting a movie automatically deletes its ratings |
| `movie_genres.movie_id → movies(movie_id)` | `CASCADE` | Deleting a movie automatically removes its genre tags |
| `movie_genres.genre_id → genres(genre_id)` | `RESTRICT` | Blocks deleting a genre that is still assigned to any movie |
