# DB design and normalization notes

This project uses a PostgreSQL relational model with three core entities:

- `users` — application accounts.
- `requests` — wedding service requests.
- `reviews` — feedback entries.

Schema definition is in `backend/db_schema.sql`.

## Entity relationships

- `requests.user_id -> users.id` (many requests can belong to one user; nullable for guest submissions).
- `reviews.user_id -> users.id` (many reviews can belong to one user; nullable for guest submissions).

## Why some foreign keys are nullable

API allows unauthenticated users to create requests/reviews.
In such cases `user_id` is `NULL`, but contact identity is still captured by `name` + `email`.

## 1NF, 2NF, 3NF

### 1NF

- All tables have primary keys.
- Attributes are atomic (`name`, `email`, `status`, etc.).
- No repeating groups or array-like columns.

### 2NF

- Each table uses a single-column surrogate primary key (`id`), so there are no partial dependencies on a composite key.
- Non-key fields depend on the whole key (`id`) only.

### 3NF

- In `users`, account fields depend only on `users.id`.
- In `requests`, request-specific attributes (budget, package, status) depend on `requests.id`.
- In `reviews`, moderation and rating fields depend on `reviews.id`.
- We avoid storing derived/cached user data in dependent tables as authoritative source; joins are used when needed.

## Security and data rationale

- Passwords are stored as bcrypt hash (never plaintext).
- Review moderation uses `approved` flag to separate public feed from pending content.
- Request status is constrained to known workflow values.

## Performance notes

Indexes align with current API access patterns:

- Login/user lookup by email.
- User cabinet lists sorted by creation date.
- Admin filtering by request status.
- Public/admin review feeds by moderation + date.
