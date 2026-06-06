-- Gmail Archive Schema
-- Database: gmailarchive
-- Owner: tgoogs
-- Project EST — Eastslide Google Exit
-- Created: June 2026
--
-- Apply with:
--   psql -U tgoogs -d gmailarchive -f gmail_schema.sql

-- ─────────────────────────────────────────
-- ADDRESSES
-- Normalized people/email address table
-- ─────────────────────────────────────────

CREATE TABLE addresses (
    id          SERIAL PRIMARY KEY,
    email       TEXT NOT NULL UNIQUE,
    name        TEXT,                          -- display name if available
    created_at  TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_addresses_email ON addresses(email);
CREATE INDEX idx_addresses_name ON addresses(name);

-- ─────────────────────────────────────────
-- MESSAGES
-- One row per email message
-- ─────────────────────────────────────────

CREATE TABLE messages (
    id              SERIAL PRIMARY KEY,
    message_id      TEXT UNIQUE NOT NULL,      -- RFC 2822 Message-ID header
    thread_id       TEXT,                      -- groups conversation threads
    date            TIMESTAMP,                 -- sent/received timestamp
    subject         TEXT,
    body_plain      TEXT,                      -- plain text body
    body_html       TEXT,                      -- HTML body
    direction       TEXT CHECK (direction IN ('received', 'sent')),
    size_bytes      INTEGER,                   -- total message size
    has_attachments BOOLEAN DEFAULT FALSE,
    attachment_types TEXT[],                   -- array of mimetypes e.g. {'application/pdf','image/jpeg'}
    is_read         BOOLEAN DEFAULT TRUE,
    is_starred      BOOLEAN DEFAULT FALSE,
    labels          TEXT[],                    -- Gmail labels e.g. {'INBOX','IMPORTANT'}
    raw_headers     TEXT,                      -- full unparsed headers
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_messages_date ON messages(date);
CREATE INDEX idx_messages_thread ON messages(thread_id);
CREATE INDEX idx_messages_direction ON messages(direction);
CREATE INDEX idx_messages_has_attachments ON messages(has_attachments);
CREATE INDEX idx_messages_is_starred ON messages(is_starred);
CREATE INDEX idx_messages_labels ON messages USING GIN(labels);
CREATE INDEX idx_messages_attachment_types ON messages USING GIN(attachment_types);

-- Full text search index on subject + body
ALTER TABLE messages ADD COLUMN fts_vector TSVECTOR;

CREATE INDEX idx_messages_fts ON messages USING GIN(fts_vector);

-- Function to update fts_vector automatically
CREATE OR REPLACE FUNCTION messages_fts_update() RETURNS TRIGGER AS $$
BEGIN
    NEW.fts_vector :=
        setweight(to_tsvector('english', COALESCE(NEW.subject, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.body_plain, '')), 'B');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER messages_fts_trigger
    BEFORE INSERT OR UPDATE ON messages
    FOR EACH ROW EXECUTE FUNCTION messages_fts_update();

-- ─────────────────────────────────────────
-- MESSAGE_ADDRESSES
-- Links messages to addresses with role
-- Enables people-centric queries
-- ─────────────────────────────────────────

CREATE TABLE message_addresses (
    id          SERIAL PRIMARY KEY,
    message_id  INTEGER NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    address_id  INTEGER NOT NULL REFERENCES addresses(id),
    role        TEXT NOT NULL CHECK (role IN ('from', 'to', 'cc', 'bcc')),
    UNIQUE (message_id, address_id, role)
);

CREATE INDEX idx_message_addresses_message ON message_addresses(message_id);
CREATE INDEX idx_message_addresses_address ON message_addresses(address_id);
CREATE INDEX idx_message_addresses_role ON message_addresses(role);

-- ─────────────────────────────────────────
-- ATTACHMENTS
-- One row per attachment
-- ─────────────────────────────────────────

CREATE TABLE attachments (
    id          SERIAL PRIMARY KEY,
    message_id  INTEGER NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    filename    TEXT,
    mimetype    TEXT,
    size_bytes  INTEGER,
    content     BYTEA,                         -- optional: store attachment content
    created_at  TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_attachments_message ON attachments(message_id);
CREATE INDEX idx_attachments_mimetype ON attachments(mimetype);
CREATE INDEX idx_attachments_filename ON attachments(filename);

-- ─────────────────────────────────────────
-- USEFUL VIEWS
-- ─────────────────────────────────────────

-- All senders with message counts
CREATE VIEW correspondent_frequency AS
SELECT
    a.email,
    a.name,
    ma.role,
    COUNT(*) as message_count,
    MIN(m.date) as first_contact,
    MAX(m.date) as last_contact
FROM message_addresses ma
JOIN addresses a ON ma.address_id = a.id
JOIN messages m ON ma.message_id = m.id
GROUP BY a.email, a.name, ma.role
ORDER BY message_count DESC;

-- Thread summary view
CREATE VIEW thread_summary AS
SELECT
    thread_id,
    COUNT(*) as message_count,
    MIN(date) as started,
    MAX(date) as last_activity,
    array_agg(DISTINCT subject) as subjects
FROM messages
GROUP BY thread_id
ORDER BY last_activity DESC;

-- Monthly email volume
CREATE VIEW monthly_volume AS
SELECT
    DATE_TRUNC('month', date) as month,
    direction,
    COUNT(*) as message_count
FROM messages
GROUP BY month, direction
ORDER BY month DESC;

-- ─────────────────────────────────────────
-- EXAMPLE QUERIES (comments only)
-- ─────────────────────────────────────────

-- Full text search:
-- SELECT subject, date FROM messages
-- WHERE fts_vector @@ plainto_tsquery('english', 'search term here');

-- All emails from a specific person:
-- SELECT m.subject, m.date FROM messages m
-- JOIN message_addresses ma ON m.id = ma.message_id
-- JOIN addresses a ON ma.address_id = a.id
-- WHERE a.email = 'person@example.com' AND ma.role = 'from';

-- All emails where someone was CC'd:
-- SELECT m.subject, m.date FROM messages m
-- JOIN message_addresses ma ON m.id = ma.message_id
-- JOIN addresses a ON ma.address_id = a.id
-- WHERE a.email = 'person@example.com' AND ma.role = 'cc';

-- Emails with PDF attachments:
-- SELECT m.subject, m.date FROM messages m
-- WHERE 'application/pdf' = ANY(m.attachment_types);

-- Everyone I have ever emailed:
-- SELECT email, name, message_count FROM correspondent_frequency
-- WHERE role = 'to' ORDER BY message_count DESC;

-- Largest emails:
-- SELECT subject, date, size_bytes FROM messages
-- ORDER BY size_bytes DESC LIMIT 20;
