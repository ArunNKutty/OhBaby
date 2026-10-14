CREATE TABLE users (
    id UUID PRIMARY KEY,
    email VARCHAR UNIQUE NOT NULL,
    google_sub VARCHAR UNIQUE,
    firebase_uid VARCHAR UNIQUE,
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

-- One row per thing logged for a baby. The API checks type and which fields apply.
CREATE TABLE entries (
    id UUID PRIMARY KEY,
    baby_id UUID NOT NULL,
    type VARCHAR NOT NULL,
    start_utc TIMESTAMPTZ NOT NULL,
    end_utc TIMESTAMPTZ NOT NULL,
    utc_offset_min SMALLINT NOT NULL,
    left_ms INTEGER NOT NULL DEFAULT 0,
    right_ms INTEGER NOT NULL DEFAULT 0,
    end_side VARCHAR,
    amount_ml INTEGER NOT NULL DEFAULT 0,
    left_ml INTEGER NOT NULL DEFAULT 0,
    right_ml INTEGER NOT NULL DEFAULT 0,
    diaper VARCHAR,
    rash BOOLEAN NOT NULL DEFAULT FALSE,
    title VARCHAR NOT NULL DEFAULT '',
    value VARCHAR NOT NULL DEFAULT '',
    unit VARCHAR NOT NULL DEFAULT '',
    notes VARCHAR NOT NULL DEFAULT '',
    created_by UUID NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    deleted_at TIMESTAMPTZ,
    change_no BIGINT NOT NULL DEFAULT nextval('change_seq')
);

CREATE INDEX entries_baby_change ON entries (baby_id, change_no);

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
)
