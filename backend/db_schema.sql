-- Wedding planning database schema (PostgreSQL)
-- This file documents the relational structure used by backend/routes/auth.js.

BEGIN;

CREATE TABLE IF NOT EXISTS users (
    id            BIGSERIAL PRIMARY KEY,
    name          VARCHAR(120) NOT NULL,
    email         VARCHAR(255) NOT NULL UNIQUE,
    password      TEXT NOT NULL,
    role          VARCHAR(20) NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS requests (
    id            BIGSERIAL PRIMARY KEY,
    user_id       BIGINT REFERENCES users(id) ON DELETE SET NULL,
    name          VARCHAR(120) NOT NULL,
    email         VARCHAR(255) NOT NULL,
    message       TEXT NOT NULL DEFAULT '',
    guests        INTEGER CHECK (guests IS NULL OR guests > 0),
    package       VARCHAR(30) CHECK (package IN ('standard', 'premium', 'luxury') OR package IS NULL),
    photographer  VARCHAR(60),
    videographer  VARCHAR(60),
    budget        NUMERIC(12,2) CHECK (budget IS NULL OR budget >= 0),
    status        VARCHAR(30) NOT NULL DEFAULT 'новая' CHECK (status IN ('новая', 'в работе', 'выполнена')),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reviews (
    id            BIGSERIAL PRIMARY KEY,
    user_id       BIGINT REFERENCES users(id) ON DELETE SET NULL,
    text          TEXT NOT NULL,
    rating        SMALLINT CHECK (rating IS NULL OR rating BETWEEN 1 AND 5),
    approved      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Recommended indexes for frequent filters/sorting in the current API.
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_requests_user_created_at ON requests(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_requests_status ON requests(status);
CREATE INDEX IF NOT EXISTS idx_reviews_user_created_at ON reviews(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reviews_approved_created_at ON reviews(approved, created_at DESC);

COMMIT;
