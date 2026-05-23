-- =============================================
-- RESTAURANT HYBRID SYSTEM — SUPABASE SCHEMA
-- =============================================
-- Run this entire script ONCE in the Supabase SQL Editor.
-- Safe to re-run — all statements use IF NOT EXISTS / OR REPLACE.
-- =============================================


-- =============================================
-- TABLES
-- =============================================

-- users
CREATE TABLE IF NOT EXISTS users (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(255)    NOT NULL,
    email           VARCHAR(255)    UNIQUE NOT NULL,
    phone           VARCHAR(20),
    password_hash   TEXT            NOT NULL,
    role            VARCHAR(20)     NOT NULL DEFAULT 'customer'
                                    CHECK (role IN ('customer', 'admin', 'staff')),
    is_verified     BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- user_otps
-- Supabase-persisted OTP registry. Cron-cleaned every 2 minutes.
CREATE TABLE IF NOT EXISTS user_otps (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    email           VARCHAR(255)    NOT NULL,
    otp_code        VARCHAR(6)      NOT NULL,
    purpose         VARCHAR(20)     NOT NULL CHECK (purpose IN ('signup', 'reset')),
    metadata        JSONB,
    expires_at      TIMESTAMPTZ     NOT NULL,
    is_verified     BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- sessions
CREATE TABLE IF NOT EXISTS sessions (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID            NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token           TEXT            UNIQUE NOT NULL,
    expires_at      TIMESTAMPTZ     NOT NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- menu_items
CREATE TABLE IF NOT EXISTS menu_items (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(255)    NOT NULL,
    description     TEXT,
    price           NUMERIC(10, 2)  NOT NULL CHECK (price >= 0),
    category        VARCHAR(100)    NOT NULL,
    subcategory     VARCHAR(100),
    is_available    BOOLEAN         NOT NULL DEFAULT TRUE,
    image_url       TEXT,
    tags            TEXT[]          DEFAULT '{}',
    sort_order      INTEGER         NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- riders
-- Must be created before orders (orders.rider_id FK references this table)
CREATE TABLE IF NOT EXISTS riders (
    id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(255)    NOT NULL,
    phone       VARCHAR(20)     NOT NULL UNIQUE,
    is_active   BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- restaurant_tables
CREATE TABLE IF NOT EXISTS restaurant_tables (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    table_number    VARCHAR(20)     NOT NULL UNIQUE,
    capacity        INTEGER         NOT NULL DEFAULT 4 CHECK (capacity > 0),
    floor           VARCHAR(50)     NOT NULL DEFAULT 'Ground Floor',
    status          VARCHAR(20)     NOT NULL DEFAULT 'free'
                                    CHECK (status IN ('free', 'occupied', 'reserved', 'inactive')),
    qr_token        TEXT            UNIQUE NOT NULL DEFAULT gen_random_uuid()::TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- orders
-- status includes 'rejected' | new columns: estimated_delivery_time, estimated_table_time,
-- rider_id, accepted_at, rejected_at
CREATE TABLE IF NOT EXISTS orders (
    id                          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                     UUID            REFERENCES users(id) ON DELETE SET NULL,
    order_type                  VARCHAR(20)     NOT NULL CHECK (order_type IN ('dine_in', 'delivery')),
    table_id                    VARCHAR(50),
    delivery_address            JSONB,
    delivery_coordinates        JSONB,
    status                      VARCHAR(30)     NOT NULL DEFAULT 'pending'
                                                CHECK (status IN (
                                                    'pending', 'confirmed', 'preparing',
                                                    'ready', 'out_for_delivery', 'delivered',
                                                    'cancelled', 'rejected'
                                                )),
    subtotal                    NUMERIC(10, 2)  NOT NULL,
    gst_amount                  NUMERIC(10, 2)  NOT NULL,
    total_amount                NUMERIC(10, 2)  NOT NULL,
    payment_status              VARCHAR(20)     NOT NULL DEFAULT 'pending'
                                                CHECK (payment_status IN ('pending', 'paid', 'failed', 'refunded')),
    payment_id                  TEXT,
    special_instructions        TEXT,
    invoice_sent                BOOLEAN         NOT NULL DEFAULT FALSE,
    estimated_delivery_time     TIMESTAMPTZ,
    estimated_table_time        TIMESTAMPTZ,
    rider_id                    UUID            REFERENCES riders(id) ON DELETE SET NULL,
    accepted_at                 TIMESTAMPTZ,
    rejected_at                 TIMESTAMPTZ,
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- order_items
CREATE TABLE IF NOT EXISTS order_items (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id        UUID            NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    menu_item_id    UUID            NOT NULL REFERENCES menu_items(id) ON DELETE RESTRICT,
    item_name       VARCHAR(255)    NOT NULL,
    quantity        INTEGER         NOT NULL CHECK (quantity > 0),
    unit_price      NUMERIC(10, 2)  NOT NULL,
    item_total      NUMERIC(10, 2)  NOT NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- complaints
CREATE TABLE IF NOT EXISTS complaints (
    id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID            REFERENCES users(id) ON DELETE SET NULL,
    order_id    UUID            REFERENCES orders(id) ON DELETE SET NULL,
    raw_text    TEXT            NOT NULL,
    category    VARCHAR(100),
    sentiment   VARCHAR(50),
    priority    VARCHAR(20)     CHECK (priority IN ('low', 'medium', 'high', 'critical')),
    status      VARCHAR(30)     NOT NULL DEFAULT 'open'
                                CHECK (status IN ('open', 'in_review', 'resolved', 'closed')),
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- payments
CREATE TABLE IF NOT EXISTS payments (
    id                      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id                UUID            NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    razorpay_payment_id     TEXT,
    razorpay_order_id       TEXT,
    amount                  NUMERIC(10, 2)  NOT NULL,
    status                  VARCHAR(20)     NOT NULL DEFAULT 'pending'
                                            CHECK (status IN ('pending', 'success', 'failed')),
    gateway_response        JSONB,
    verified_at             TIMESTAMPTZ,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);


-- =============================================
-- INDICES
-- =============================================

CREATE INDEX IF NOT EXISTS idx_users_email         ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role          ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_is_verified   ON users(is_verified);

CREATE INDEX IF NOT EXISTS idx_otp_email_purpose   ON user_otps(email, purpose);
CREATE INDEX IF NOT EXISTS idx_otp_expires_at      ON user_otps(expires_at);
CREATE INDEX IF NOT EXISTS idx_otp_is_verified     ON user_otps(is_verified);

CREATE INDEX IF NOT EXISTS idx_sessions_token      ON sessions(token);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id    ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON sessions(expires_at);

CREATE INDEX IF NOT EXISTS idx_menu_category       ON menu_items(category);
CREATE INDEX IF NOT EXISTS idx_menu_available      ON menu_items(is_available);
CREATE INDEX IF NOT EXISTS idx_menu_price          ON menu_items(price);
CREATE INDEX IF NOT EXISTS idx_menu_sort           ON menu_items(sort_order, name);
CREATE INDEX IF NOT EXISTS idx_menu_name_fts       ON menu_items USING gin(to_tsvector('english', name));

CREATE INDEX IF NOT EXISTS idx_restaurant_tables_status ON restaurant_tables(status);
CREATE INDEX IF NOT EXISTS idx_restaurant_tables_number ON restaurant_tables(table_number);

CREATE INDEX IF NOT EXISTS idx_riders_active            ON riders(is_active);

CREATE INDEX IF NOT EXISTS idx_orders_user_id           ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status            ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_type              ON orders(order_type);
CREATE INDEX IF NOT EXISTS idx_orders_payment_status    ON orders(payment_status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at        ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_table_id          ON orders(table_id) WHERE table_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_orders_rider_id          ON orders(rider_id) WHERE rider_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_order_items_order_id     ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_menu_item_id ON order_items(menu_item_id);

CREATE INDEX IF NOT EXISTS idx_complaints_user_id    ON complaints(user_id);
CREATE INDEX IF NOT EXISTS idx_complaints_priority   ON complaints(priority);
CREATE INDEX IF NOT EXISTS idx_complaints_status     ON complaints(status);
CREATE INDEX IF NOT EXISTS idx_complaints_created_at ON complaints(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_payments_order_id     ON payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_razorpay_id  ON payments(razorpay_payment_id);
CREATE INDEX IF NOT EXISTS idx_payments_status       ON payments(status);


-- =============================================
-- UPDATED_AT TRIGGER
-- =============================================

CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_users_updated_at              ON users;
DROP TRIGGER IF EXISTS trg_menu_items_updated_at         ON menu_items;
DROP TRIGGER IF EXISTS trg_orders_updated_at             ON orders;
DROP TRIGGER IF EXISTS trg_complaints_updated_at         ON complaints;
DROP TRIGGER IF EXISTS trg_restaurant_tables_updated_at  ON restaurant_tables;
DROP TRIGGER IF EXISTS trg_riders_updated_at             ON riders;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_menu_items_updated_at
    BEFORE UPDATE ON menu_items
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_complaints_updated_at
    BEFORE UPDATE ON complaints
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_restaurant_tables_updated_at
    BEFORE UPDATE ON restaurant_tables
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_riders_updated_at
    BEFORE UPDATE ON riders
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();


-- =============================================
-- ROW LEVEL SECURITY
-- =============================================
-- The Flask backend connects using the service_role key which bypasses
-- RLS entirely. These policies protect the tables from:
--   - Direct client-side access using the anon key
--   - Accidental exposure via Supabase auto-generated REST API
--   - Dashboard-level access by non-owner Supabase members
-- =============================================

ALTER TABLE users               ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_otps           ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions            ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_items          ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders              ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items         ENABLE ROW LEVEL SECURITY;
ALTER TABLE complaints          ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments            ENABLE ROW LEVEL SECURITY;
ALTER TABLE restaurant_tables   ENABLE ROW LEVEL SECURITY;
ALTER TABLE riders              ENABLE ROW LEVEL SECURITY;


-- users
DROP POLICY IF EXISTS policy_users_deny_anon    ON users;
DROP POLICY IF EXISTS policy_users_service_all  ON users;

CREATE POLICY policy_users_deny_anon
    ON users FOR ALL TO anon USING (false);

CREATE POLICY policy_users_service_all
    ON users FOR ALL TO service_role USING (true) WITH CHECK (true);


-- user_otps
DROP POLICY IF EXISTS policy_otps_deny_anon    ON user_otps;
DROP POLICY IF EXISTS policy_otps_service_all  ON user_otps;

CREATE POLICY policy_otps_deny_anon
    ON user_otps FOR ALL TO anon USING (false);

CREATE POLICY policy_otps_service_all
    ON user_otps FOR ALL TO service_role USING (true) WITH CHECK (true);


-- sessions
DROP POLICY IF EXISTS policy_sessions_deny_anon    ON sessions;
DROP POLICY IF EXISTS policy_sessions_service_all  ON sessions;

CREATE POLICY policy_sessions_deny_anon
    ON sessions FOR ALL TO anon USING (false);

CREATE POLICY policy_sessions_service_all
    ON sessions FOR ALL TO service_role USING (true) WITH CHECK (true);


-- menu_items
-- Public SELECT allowed for available items only; all writes via service_role.
DROP POLICY IF EXISTS policy_menu_public_read       ON menu_items;
DROP POLICY IF EXISTS policy_menu_deny_anon_write   ON menu_items;
DROP POLICY IF EXISTS policy_menu_service_all       ON menu_items;

CREATE POLICY policy_menu_public_read
    ON menu_items FOR SELECT TO anon USING (is_available = true);

CREATE POLICY policy_menu_deny_anon_write
    ON menu_items FOR ALL TO anon USING (false) WITH CHECK (false);

CREATE POLICY policy_menu_service_all
    ON menu_items FOR ALL TO service_role USING (true) WITH CHECK (true);


-- orders
DROP POLICY IF EXISTS policy_orders_deny_anon    ON orders;
DROP POLICY IF EXISTS policy_orders_service_all  ON orders;

CREATE POLICY policy_orders_deny_anon
    ON orders FOR ALL TO anon USING (false);

CREATE POLICY policy_orders_service_all
    ON orders FOR ALL TO service_role USING (true) WITH CHECK (true);


-- order_items
DROP POLICY IF EXISTS policy_order_items_deny_anon    ON order_items;
DROP POLICY IF EXISTS policy_order_items_service_all  ON order_items;

CREATE POLICY policy_order_items_deny_anon
    ON order_items FOR ALL TO anon USING (false);

CREATE POLICY policy_order_items_service_all
    ON order_items FOR ALL TO service_role USING (true) WITH CHECK (true);


-- complaints
DROP POLICY IF EXISTS policy_complaints_deny_anon    ON complaints;
DROP POLICY IF EXISTS policy_complaints_service_all  ON complaints;

CREATE POLICY policy_complaints_deny_anon
    ON complaints FOR ALL TO anon USING (false);

CREATE POLICY policy_complaints_service_all
    ON complaints FOR ALL TO service_role USING (true) WITH CHECK (true);


-- payments
DROP POLICY IF EXISTS policy_payments_deny_anon    ON payments;
DROP POLICY IF EXISTS policy_payments_service_all  ON payments;

CREATE POLICY policy_payments_deny_anon
    ON payments FOR ALL TO anon USING (false);

CREATE POLICY policy_payments_service_all
    ON payments FOR ALL TO service_role USING (true) WITH CHECK (true);


-- restaurant_tables
-- Anon can SELECT non-inactive tables (QR scan use-case); all writes via service_role.
DROP POLICY IF EXISTS policy_tables_deny_anon    ON restaurant_tables;
DROP POLICY IF EXISTS policy_tables_service_all  ON restaurant_tables;
DROP POLICY IF EXISTS policy_tables_qr_public    ON restaurant_tables;

CREATE POLICY policy_tables_deny_anon
    ON restaurant_tables FOR ALL TO anon USING (false);

CREATE POLICY policy_tables_service_all
    ON restaurant_tables FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Allows customers to scan a table QR (anon can match qr_token → table_number)
CREATE POLICY policy_tables_qr_public
    ON restaurant_tables FOR SELECT TO anon USING (status != 'inactive');


-- riders
DROP POLICY IF EXISTS policy_riders_deny_anon    ON riders;
DROP POLICY IF EXISTS policy_riders_service_all  ON riders;

CREATE POLICY policy_riders_deny_anon
    ON riders FOR ALL TO anon USING (false);

CREATE POLICY policy_riders_service_all
    ON riders FOR ALL TO service_role USING (true) WITH CHECK (true);


-- =============================================
-- CRON JOBS (pg_cron)
-- pg_cron is pre-enabled on all Supabase projects.
-- =============================================

CREATE EXTENSION IF NOT EXISTS pg_cron;

GRANT USAGE ON SCHEMA cron TO postgres;

-- Remove old jobs if they exist so this block is safe to re-run
SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname IN ('purge_expired_otps', 'purge_expired_sessions');

-- Purge expired OTPs every 2 minutes
SELECT cron.schedule(
    'purge_expired_otps',
    '*/2 * * * *',
    $$DELETE FROM user_otps WHERE expires_at < NOW()$$
);

-- Purge expired sessions every 2 minutes
SELECT cron.schedule(
    'purge_expired_sessions',
    '*/2 * * * *',
    $$DELETE FROM sessions WHERE expires_at < NOW()$$
);

-- Verify jobs were registered
SELECT jobid, jobname, schedule, command, active
FROM cron.job
WHERE jobname IN ('purge_expired_otps', 'purge_expired_sessions');
