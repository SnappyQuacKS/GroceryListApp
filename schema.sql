-- GroceryList PostgreSQL Schema
-- Run once on the PostgreSQL server:
--   psql -U postgres -d grocerylist -f schema.sql

CREATE TABLE IF NOT EXISTS users (
    username      TEXT PRIMARY KEY,
    password_hash TEXT NOT NULL,
    first_name    TEXT DEFAULT '',
    last_name     TEXT DEFAULT '',
    zip_code      TEXT DEFAULT ''
);

CREATE TABLE IF NOT EXISTS items (
    item_id   TEXT PRIMARY KEY,
    item_name TEXT NOT NULL
);

-- theme and created_date extend the base Python model for iOS app
CREATE TABLE IF NOT EXISTS grocery_lists (
    list_id      TEXT PRIMARY KEY,
    list_name    TEXT NOT NULL,
    parent_id    TEXT REFERENCES grocery_lists(list_id) DEFERRABLE INITIALLY DEFERRED,
    user_id      TEXT REFERENCES users(username) ON DELETE SET NULL,
    theme        TEXT DEFAULT 'natural',
    created_date TEXT DEFAULT ''
);

CREATE TABLE IF NOT EXISTS list_entries (
    list_id              TEXT REFERENCES grocery_lists(list_id) ON DELETE CASCADE,
    item_id              TEXT REFERENCES items(item_id) ON DELETE CASCADE,
    is_checked           BOOLEAN DEFAULT FALSE,
    is_masked_hidden     BOOLEAN DEFAULT FALSE,
    custom_name_override TEXT,
    PRIMARY KEY (list_id, item_id)
);
