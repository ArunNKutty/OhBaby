CREATE TYPE feeding_type AS ENUM ('breast', 'formula', 'breast_milk');

CREATE TYPE side AS ENUM ('left', 'right');

CREATE TABLE users (
    id UUID PRIMARY KEY,
    email VARCHAR UNIQUE NOT NULL,
    google_sub VARCHAR UNIQUE,
    created_at TIMESTAMPTZ NOT NULL,
    deleted_at TIMESTAMPTZ
);

CREATE TABLE babies (
    id UUID PRIMARY KEY,
    name VARCHAR NOT NULL,
    birth_date DATE,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE memberships (
    user_id UUID NOT NULL,
    baby_id UUID NOT NULL,
    role VARCHAR NOT NULL CHECK (role IN ('owner', 'partner')),
    PRIMARY KEY (user_id, baby_id)
);

CREATE SEQUENCE change_seq;

CREATE TABLE feedings (
    id UUID PRIMARY KEY,
    baby_id UUID NOT NULL,
    type feeding_type NOT NULL,
    start_utc TIMESTAMPTZ NOT NULL,
    end_utc TIMESTAMPTZ NOT NULL,
    utc_offset_min SMALLINT NOT NULL,
    left_ms INTEGER DEFAULT 0,
    right_ms INTEGER DEFAULT 0,
    end_side side,
    amount_ml INTEGER DEFAULT 0,
    notes VARCHAR DEFAULT '',
    created_by UUID NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    deleted_at TIMESTAMPTZ,
    change_no BIGINT NOT NULL DEFAULT nextval('change_seq')
);

CREATE INDEX feedings_baby_change ON feedings (baby_id, change_no);

CREATE TABLE events (
    event_id UUID PRIMARY KEY,
    name VARCHAR NOT NULL,
    client_ts TIMESTAMPTZ NOT NULL,
    received_at TIMESTAMPTZ NOT NULL,
    anon_id UUID NOT NULL,
    user_id UUID,
    session_id UUID NOT NULL,
    platform VARCHAR NOT NULL,
    app_version VARCHAR NOT NULL,
    props JSON
);

CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    token_hash VARCHAR NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL
);
