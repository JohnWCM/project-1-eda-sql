-- =========================================================================
-- schema.sql - the tables your database is made of
--
-- Project 1 | SQL: From Data to Insight
-- Team:Jonathan Weininger
-- Dataset:World Bank dataset
--
-- This is a DELIVERABLE: it is how someone rebuilds your database from
-- nothing, and the tables here must match the ERD you drew.
--
-- Written for SQLite. On MySQL, add a CREATE DATABASE / USE at the top and
-- swap the types (TEXT -> VARCHAR(n), REAL -> DECIMAL, INTEGER PRIMARY KEY
-- -> INT PRIMARY KEY AUTO_INCREMENT).

-- =========================================================================

-- SQLite does not enforce foreign keys unless you ask it to, once per
-- connection. Without this line a broken key is accepted in silence.
PRAGMA foreign_keys = ON;


-- --- Lookup tables -------------------------------------------------------
-- The categorical columns you pulled out: an id and the value it stands for.
-- These have no foreign keys of their own, so they are created and loaded
-- FIRST.

-- Table 1: Countries
CREATE TABLE IF NOT EXISTS countries (
    country_code TEXT PRIMARY KEY NOT NULL,
    country_name TEXT NOT NULL,
    region TEXT
);

-- Table 2: Indicators
CREATE TABLE IF NOT EXISTS indicators (
    indicator_code TEXT PRIMARY KEY NOT NULL,
    indicator_name TEXT NOT NULL,
    description TEXT,
    unit TEXT
);

-- --- Your main table -----------------------------------------------------
-- The rows you are actually analysing: the numbers you care about, plus one
-- foreign key pointing at each lookup table above. Created and loaded LAST,
-- because every key it carries has to already exist somewhere else.

-- Table 3: Economic observations
CREATE TABLE IF NOT EXISTS observations (
    country_code TEXT NOT NULL,
    indicator_code TEXT NOT NULL,
    year INTEGER NOT NULL,
    value REAL,

    PRIMARY KEY (country_code, indicator_code, year),

    FOREIGN KEY (country_code)
        REFERENCES countries(country_code),

    FOREIGN KEY (indicator_code)
        REFERENCES indicators(indicator_code),

    CHECK (year BETWEEN 2019 AND 2024)
);


-- --- Indexes (optional) --------------------------------------------------
-- Worth adding on your foreign keys if a query starts to feel slow.
CREATE INDEX IF NOT EXISTS idx_observations_country
    ON observations(country_code);

CREATE INDEX IF NOT EXISTS idx_observations_indicator
    ON observations(indicator_code);

CREATE INDEX IF NOT EXISTS idx_observations_year
    ON observations(year);