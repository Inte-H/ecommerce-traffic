-- =============================================
-- E-commerce Test Database - PostgreSQL 15+
-- =============================================

-- CREATE DATABASE ecommerce OWNER postgres ENCODING 'UTF8';
-- \c ecommerce

-- Custom ENUM types
CREATE TYPE order_status AS ENUM (
    'pending','paid','preparing','shipped','delivered','confirmed',
    'cancelled','return_requested','returned'
);
CREATE TYPE payment_method AS ENUM (
    'card','bank_transfer','virtual_account','kakao_pay','naver_pay','point'
);
CREATE TYPE payment_status AS ENUM (
    'pending','completed','failed','refunded'
);
CREATE TYPE shipping_status AS ENUM (
    'preparing','shipped','in_transit','delivered','returned'
);
CREATE TYPE customer_grade AS ENUM (
    'BRONZE','SILVER','GOLD','VIP'
);
CREATE TYPE gender_type AS ENUM ('M','F');
CREATE TYPE coupon_type AS ENUM ('percent','fixed');
CREATE TYPE return_type AS ENUM ('refund','exchange');
CREATE TYPE return_reason AS ENUM (
    'defective','wrong_item','change_of_mind','damaged_in_transit',
    'not_as_described','late_delivery'
);
CREATE TYPE return_status AS ENUM (
    'requested','pickup_scheduled','in_transit','completed'
);
CREATE TYPE refund_status AS ENUM (
    'pending','refunded','exchanged','partial_refund'
);
CREATE TYPE inspection_result AS ENUM (
    'good','opened_good','defective','unsellable'
);
CREATE TYPE image_type AS ENUM (
    'main','angle','side','back','detail','package','lifestyle','accessory','size_comparison'
);
CREATE TYPE referrer_source AS ENUM (
    'direct','search','ad','recommendation','social','email'
);
CREATE TYPE device_type AS ENUM (
    'desktop','mobile','tablet'
);
CREATE TYPE staff_role AS ENUM ('admin','manager','staff');
CREATE TYPE complaint_category AS ENUM (
    'product_defect','delivery_issue','wrong_item','refund_request',
    'exchange_request','general_inquiry','price_inquiry'
);
CREATE TYPE complaint_channel AS ENUM (
    'website','phone','email','chat','kakao'
);
CREATE TYPE priority_level AS ENUM ('low','medium','high','urgent');
CREATE TYPE complaint_status AS ENUM ('open','resolved','closed');
CREATE TYPE complaint_type AS ENUM ('inquiry','claim','report');
CREATE TYPE compensation_type AS ENUM (
    'refund','exchange','partial_refund','point_compensation','none'
);
CREATE TYPE acquisition_channel AS ENUM (
    'organic','search_ad','social','referral','direct'
);
CREATE TYPE cart_status AS ENUM ('active','converted','abandoned');
CREATE TYPE inventory_type AS ENUM ('inbound','outbound','return','adjustment');
CREATE TYPE promo_type AS ENUM ('seasonal','flash','category');
CREATE TYPE change_reason_type AS ENUM (
    'regular','promotion','price_drop','cost_increase'
);
CREATE TYPE grade_change_reason AS ENUM (
    'signup','upgrade','downgrade','yearly_review'
);
CREATE TYPE tag_category AS ENUM ('feature','use_case','target','spec');

-- =============================================
-- Product categories (hierarchical)
-- =============================================
CREATE TABLE categories (
    id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    parent_id       INT NULL REFERENCES categories(id),
    name            VARCHAR(100) NOT NULL,
    slug            VARCHAR(100) NOT NULL UNIQUE,
    depth           INT NOT NULL DEFAULT 0,
    sort_order      INT NOT NULL DEFAULT 0,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP NOT NULL,
    updated_at      TIMESTAMP NOT NULL
);

-- =============================================
-- Suppliers
-- =============================================
CREATE TABLE suppliers (
    id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    company_name    VARCHAR(200) NOT NULL,
    business_number VARCHAR(20) NOT NULL,
    contact_name    VARCHAR(100) NOT NULL,
    phone           VARCHAR(20) NOT NULL,
    email           VARCHAR(200) NOT NULL,
    address         VARCHAR(500) NULL,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP NOT NULL,
    updated_at      TIMESTAMP NOT NULL
);

-- =============================================
-- Products
-- =============================================
CREATE TABLE products (
    id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_id     INT NOT NULL REFERENCES categories(id),
    supplier_id     INT NOT NULL REFERENCES suppliers(id),
    successor_id    INT NULL REFERENCES products(id),
    name            VARCHAR(500) NOT NULL,
    sku             VARCHAR(50) NOT NULL UNIQUE,
    brand           VARCHAR(100) NOT NULL,
    model_number    VARCHAR(50) NULL,
    description     TEXT NULL,
    specs           JSONB NULL,
    price           NUMERIC(12,2) NOT NULL CHECK (price >= 0),
    cost_price      NUMERIC(12,2) NOT NULL CHECK (cost_price >= 0),
    stock_qty       INT NOT NULL DEFAULT 0,
    weight_grams    INT NULL,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    discontinued_at TIMESTAMP NULL,
    created_at      TIMESTAMP NOT NULL,
    updated_at      TIMESTAMP NOT NULL
);

-- =============================================
-- Product images
-- =============================================
CREATE TABLE product_images (
    id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id      INT NOT NULL REFERENCES products(id),
    image_url       VARCHAR(500) NOT NULL,
    file_name       VARCHAR(200) NOT NULL,
    image_type      image_type NOT NULL,
    alt_text        VARCHAR(500) NULL,
    width           INT NULL,
    height          INT NULL,
    file_size       INT NULL,
    sort_order      INT NOT NULL DEFAULT 1,
    is_primary      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMP NOT NULL
);

-- =============================================
-- Product price history
-- =============================================
CREATE TABLE product_prices (
    id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id      INT NOT NULL REFERENCES products(id),
    price           NUMERIC(12,2) NOT NULL,
    started_at      TIMESTAMP NOT NULL,
    ended_at        TIMESTAMP NULL,
    change_reason   change_reason_type NULL
);

-- =============================================
-- Customers
-- =============================================
CREATE TABLE customers (
    id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email           VARCHAR(200) NOT NULL UNIQUE,
    password_hash   VARCHAR(64) NOT NULL,
    name            VARCHAR(100) NOT NULL,
    phone           VARCHAR(20) NOT NULL,
    birth_date      DATE NULL,
    gender          gender_type NULL,
    grade           customer_grade NOT NULL DEFAULT 'BRONZE',
    point_balance   INT NOT NULL DEFAULT 0 CHECK (point_balance >= 0),
    acquisition_channel acquisition_channel NULL,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    last_login_at   TIMESTAMP NULL,
    created_at      TIMESTAMP NOT NULL,
    updated_at      TIMESTAMP NOT NULL
);

-- =============================================
-- Customer addresses
-- =============================================
CREATE TABLE customer_addresses (
    id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id     INT NOT NULL REFERENCES customers(id),
    label           VARCHAR(50) NOT NULL,
    recipient_name  VARCHAR(100) NOT NULL,
    phone           VARCHAR(20) NOT NULL,
    zip_code        VARCHAR(10) NOT NULL,
    address1        VARCHAR(300) NOT NULL,
    address2        VARCHAR(300) NULL,
    is_default      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMP NOT NULL,
    updated_at      TIMESTAMP NULL
);

-- =============================================
-- Staff
-- =============================================
CREATE TABLE staff (
    id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    manager_id      INT NULL REFERENCES staff(id),
    email           VARCHAR(200) NOT NULL UNIQUE,
    name            VARCHAR(100) NOT NULL,
    phone           VARCHAR(20) NOT NULL,
    department      VARCHAR(50) NOT NULL,
    role            staff_role NOT NULL,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    hired_at        TIMESTAMP NOT NULL,
    created_at      TIMESTAMP NOT NULL
);

-- =============================================
-- Orders (partitioned by year on ordered_at)
-- =============================================
CREATE TABLE orders (
    id              INT GENERATED ALWAYS AS IDENTITY,
    order_number    VARCHAR(30) NOT NULL,
    customer_id     INT NOT NULL,
    address_id      INT NOT NULL,
    staff_id        INT NULL,
    status          order_status NOT NULL,
    total_amount    NUMERIC(12,2) NOT NULL,
    discount_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    shipping_fee    NUMERIC(12,2) NOT NULL DEFAULT 0,
    point_used      INT NOT NULL DEFAULT 0,
    point_earned    INT NOT NULL DEFAULT 0,
    notes           TEXT NULL,
    ordered_at      TIMESTAMP NOT NULL,
    completed_at    TIMESTAMP NULL,
    cancelled_at    TIMESTAMP NULL,
    created_at      TIMESTAMP NOT NULL,
    updated_at      TIMESTAMP NOT NULL,
    PRIMARY KEY (id, ordered_at),
    UNIQUE (order_number, ordered_at)
) PARTITION BY RANGE (ordered_at);

CREATE TABLE orders_2015 PARTITION OF orders
    FOR VALUES FROM ('2015-01-01') TO ('2016-01-01');
CREATE TABLE orders_2016 PARTITION OF orders
    FOR VALUES FROM ('2016-01-01') TO ('2017-01-01');
CREATE TABLE orders_2017 PARTITION OF orders
    FOR VALUES FROM ('2017-01-01') TO ('2018-01-01');
CREATE TABLE orders_2018 PARTITION OF orders
    FOR VALUES FROM ('2018-01-01') TO ('2019-01-01');
CREATE TABLE orders_2019 PARTITION OF orders
    FOR VALUES FROM ('2019-01-01') TO ('2020-01-01');
CREATE TABLE orders_2020 PARTITION OF orders
    FOR VALUES FROM ('2020-01-01') TO ('2021-01-01');
CREATE TABLE orders_2021 PARTITION OF orders
    FOR VALUES FROM ('2021-01-01') TO ('2022-01-01');
CREATE TABLE orders_2022 PARTITION OF orders
    FOR VALUES FROM ('2022-01-01') TO ('2023-01-01');
CREATE TABLE orders_2023 PARTITION OF orders
    FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');
CREATE TABLE orders_2024 PARTITION OF orders
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE orders_2025 PARTITION OF orders
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE orders_default PARTITION OF orders DEFAULT;

CREATE INDEX idx_orders_customer ON orders (customer_id);
CREATE INDEX idx_orders_status ON orders (status);
CREATE INDEX idx_orders_ordered_at ON orders (ordered_at);

-- =============================================
-- Order items
-- =============================================
CREATE TABLE order_items (
    id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id        INT NOT NULL,
    product_id      INT NOT NULL REFERENCES products(id),
    quantity        INT NOT NULL CHECK (quantity > 0),
    unit_price      NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
    discount_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    subtotal        NUMERIC(12,2) NOT NULL
);

CREATE INDEX idx_order_items_order ON order_items (order_id);
CREATE INDEX idx_order_items_product ON order_items (product_id);

-- =============================================
-- Payments
-- =============================================
CREATE TABLE payments (
    id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id        INT NOT NULL,
    method          payment_method NOT NULL,
    amount          NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
    status          payment_status NOT NULL,
    pg_transaction_id VARCHAR(100) NULL,
    card_issuer     VARCHAR(50) NULL,
    card_approval_no VARCHAR(20) NULL,
    installment_months INT NULL,
    bank_name       VARCHAR(50) NULL,
    account_no      VARCHAR(50) NULL,
    depositor_name  VARCHAR(100) NULL,
    easy_pay_method VARCHAR(50) NULL,
    receipt_type    VARCHAR(20) NULL,
    receipt_no      VARCHAR(50) NULL,
    paid_at         TIMESTAMP NULL,
    refunded_at     TIMESTAMP NULL,
    created_at      TIMESTAMP NOT NULL
);

CREATE INDEX idx_payments_order ON payments (order_id);

-- =============================================
-- Shipping
-- =============================================
CREATE TABLE shipping (
    id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id        INT NOT NULL,
    carrier         VARCHAR(50) NOT NULL,
    tracking_number VARCHAR(50) NULL,
    status          shipping_status NOT NULL,
    shipped_at      TIMESTAMP NULL,
    delivered_at    TIMESTAMP NULL,
    created_at      TIMESTAMP NOT NULL,
    updated_at      TIMESTAMP NOT NULL
);

CREATE INDEX idx_shipping_order ON shipping (order_id);

-- =============================================
-- Reviews
-- =============================================
CREATE TABLE reviews (
    id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id      INT NOT NULL REFERENCES products(id),
    customer_id     INT NOT NULL REFERENCES customers(id),
    order_id        INT NOT NULL,
    rating          SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    title           VARCHAR(200) NULL,
    content         TEXT NULL,
    is_verified     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP NOT NULL,
    updated_at      TIMESTAMP NOT NULL
);

CREATE INDEX idx_reviews_product ON reviews (product_id);
CREATE INDEX idx_reviews_customer ON reviews (customer_id);

-- =============================================
-- Inventory transactions
-- =============================================
CREATE TABLE inventory_transactions (
    id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id      INT NOT NULL REFERENCES products(id),
    type            inventory_type NOT NULL,
    quantity        INT NOT NULL,
    reference_id    INT NULL,
    notes           VARCHAR(500) NULL,
    created_at      TIMESTAMP NOT NULL
);

-- =============================================
-- Carts
-- =============================================
CREATE TABLE carts (
    id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id     INT NOT NULL REFERENCES customers(id),
    status          cart_status NOT NULL DEFAULT 'active',
    created_at      TIMESTAMP NOT NULL,
    updated_at      TIMESTAMP NOT NULL
);

-- =============================================
-- Cart items
-- =============================================
CREATE TABLE cart_items (
    id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cart_id         INT NOT NULL REFERENCES carts(id),
    product_id      INT NOT NULL REFERENCES products(id),
    quantity        INT NOT NULL DEFAULT 1,
    added_at        TIMESTAMP NOT NULL
);

-- =============================================
-- Coupons
-- =============================================
CREATE TABLE coupons (
    id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code            VARCHAR(30) NOT NULL UNIQUE,
    name            VARCHAR(200) NOT NULL,
    type            coupon_type NOT NULL,
    discount_value  NUMERIC(12,2) NOT NULL CHECK (discount_value > 0),
    min_order_amount NUMERIC(12,2) NULL,
    max_discount    NUMERIC(12,2) NULL,
    usage_limit     INT NULL,
    per_user_limit  INT NOT NULL DEFAULT 1,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    started_at      TIMESTAMP NOT NULL,
    expired_at      TIMESTAMP NOT NULL,
    created_at      TIMESTAMP NOT NULL
);

-- =============================================
-- Coupon usage
-- =============================================
CREATE TABLE coupon_usage (
    id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    coupon_id       INT NOT NULL REFERENCES coupons(id),
    customer_id     INT NOT NULL REFERENCES customers(id),
    order_id        INT NOT NULL,
    discount_amount NUMERIC(12,2) NOT NULL,
    used_at         TIMESTAMP NOT NULL
);

-- =============================================
-- Complaints
-- =============================================
CREATE TABLE complaints (
    id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id        INT NULL,
    customer_id     INT NOT NULL REFERENCES customers(id),
    staff_id        INT NULL REFERENCES staff(id),
    category        complaint_category NOT NULL,
    channel         complaint_channel NOT NULL,
    priority        priority_level NOT NULL,
    status          complaint_status NOT NULL,
    title           VARCHAR(300) NOT NULL,
    content         TEXT NOT NULL,
    resolution      TEXT NULL,
    type            complaint_type NOT NULL DEFAULT 'inquiry',
    sub_category    VARCHAR(100) NULL,
    compensation_type compensation_type NULL,
    compensation_amount NUMERIC(12,2) NULL DEFAULT 0,
    escalated       BOOLEAN NOT NULL DEFAULT FALSE,
    response_count  INT NOT NULL DEFAULT 1,
    created_at      TIMESTAMP NOT NULL,
    resolved_at     TIMESTAMP NULL,
    closed_at       TIMESTAMP NULL
);

CREATE INDEX idx_complaints_customer ON complaints (customer_id);
CREATE INDEX idx_complaints_status ON complaints (status);

-- =============================================
-- Returns/exchanges
-- =============================================
CREATE TABLE returns (
    id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id        INT NOT NULL,
    customer_id     INT NOT NULL REFERENCES customers(id),
    return_type     return_type NOT NULL,
    reason          return_reason NOT NULL,
    reason_detail   TEXT NOT NULL,
    status          return_status NOT NULL,
    is_partial      BOOLEAN NOT NULL DEFAULT FALSE,
    refund_amount   NUMERIC(12,2) NOT NULL,
    refund_status   refund_status NOT NULL,
    carrier         VARCHAR(50) NOT NULL,
    tracking_number VARCHAR(50) NOT NULL,
    requested_at    TIMESTAMP NOT NULL,
    pickup_at       TIMESTAMP NOT NULL,
    received_at     TIMESTAMP NULL,
    inspected_at    TIMESTAMP NULL,
    inspection_result inspection_result NULL,
    completed_at    TIMESTAMP NULL,
    claim_id        INT NULL REFERENCES complaints(id),
    exchange_product_id INT NULL REFERENCES products(id),
    restocking_fee  NUMERIC(12,2) NOT NULL DEFAULT 0,
    created_at      TIMESTAMP NOT NULL
);

CREATE INDEX idx_returns_order ON returns (order_id);
CREATE INDEX idx_returns_customer ON returns (customer_id);

-- =============================================
-- Wishlists
-- =============================================
CREATE TABLE wishlists (
    id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id     INT NOT NULL REFERENCES customers(id),
    product_id      INT NOT NULL REFERENCES products(id),
    is_purchased    BOOLEAN NOT NULL DEFAULT FALSE,
    notify_on_sale  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMP NOT NULL,
    UNIQUE (customer_id, product_id)
);

-- =============================================
-- Calendar dimension
-- =============================================
CREATE TABLE calendar (
    date_key        DATE NOT NULL PRIMARY KEY,
    year            INT NOT NULL,
    month           INT NOT NULL,
    day             INT NOT NULL,
    quarter         INT NOT NULL,
    day_of_week     INT NOT NULL,
    day_name        VARCHAR(20) NOT NULL,
    is_weekend      BOOLEAN NOT NULL DEFAULT FALSE,
    is_holiday      BOOLEAN NOT NULL DEFAULT FALSE,
    holiday_name    VARCHAR(100) NULL
);

CREATE INDEX idx_calendar_year_month ON calendar (year, month);

-- =============================================
-- Customer grade history
-- =============================================
CREATE TABLE customer_grade_history (
    id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id     INT NOT NULL REFERENCES customers(id),
    old_grade       customer_grade NULL,
    new_grade       customer_grade NOT NULL,
    changed_at      TIMESTAMP NOT NULL,
    reason          grade_change_reason NOT NULL
);

CREATE INDEX idx_grade_history_customer ON customer_grade_history (customer_id);

-- =============================================
-- Tags
-- =============================================
CREATE TABLE tags (
    id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name            VARCHAR(100) NOT NULL UNIQUE,
    category        tag_category NOT NULL
);

CREATE TABLE product_tags (
    product_id      INT NOT NULL REFERENCES products(id),
    tag_id          INT NOT NULL REFERENCES tags(id),
    PRIMARY KEY (product_id, tag_id)
);

-- =============================================
-- Product views (partitioned by year)
-- =============================================
CREATE TABLE product_views (
    id              INT GENERATED ALWAYS AS IDENTITY,
    customer_id     INT NOT NULL,
    product_id      INT NOT NULL,
    referrer_source referrer_source NOT NULL,
    device_type     device_type NOT NULL,
    duration_seconds INT NOT NULL,
    viewed_at       TIMESTAMP NOT NULL,
    PRIMARY KEY (id, viewed_at)
) PARTITION BY RANGE (viewed_at);

CREATE TABLE product_views_2015 PARTITION OF product_views
    FOR VALUES FROM ('2015-01-01') TO ('2016-01-01');
CREATE TABLE product_views_2016 PARTITION OF product_views
    FOR VALUES FROM ('2016-01-01') TO ('2017-01-01');
CREATE TABLE product_views_2017 PARTITION OF product_views
    FOR VALUES FROM ('2017-01-01') TO ('2018-01-01');
CREATE TABLE product_views_2018 PARTITION OF product_views
    FOR VALUES FROM ('2018-01-01') TO ('2019-01-01');
CREATE TABLE product_views_2019 PARTITION OF product_views
    FOR VALUES FROM ('2019-01-01') TO ('2020-01-01');
CREATE TABLE product_views_2020 PARTITION OF product_views
    FOR VALUES FROM ('2020-01-01') TO ('2021-01-01');
CREATE TABLE product_views_2021 PARTITION OF product_views
    FOR VALUES FROM ('2021-01-01') TO ('2022-01-01');
CREATE TABLE product_views_2022 PARTITION OF product_views
    FOR VALUES FROM ('2022-01-01') TO ('2023-01-01');
CREATE TABLE product_views_2023 PARTITION OF product_views
    FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');
CREATE TABLE product_views_2024 PARTITION OF product_views
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE product_views_2025 PARTITION OF product_views
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE product_views_default PARTITION OF product_views DEFAULT;

CREATE INDEX idx_views_customer ON product_views (customer_id);
CREATE INDEX idx_views_product ON product_views (product_id);
CREATE INDEX idx_views_viewed_at ON product_views (viewed_at);

-- =============================================
-- Point transactions
-- =============================================
CREATE TABLE point_transactions (
    id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id     INT NOT NULL REFERENCES customers(id),
    order_id        INT NULL,
    type            VARCHAR(10) NOT NULL CHECK (type IN ('earn','use','expire')),
    reason          VARCHAR(20) NOT NULL CHECK (reason IN ('purchase','confirm','review','signup','use','expiry')),
    amount          INT NOT NULL,
    balance_after   INT NOT NULL,
    expires_at      TIMESTAMP NULL,
    created_at      TIMESTAMP NOT NULL
);

CREATE INDEX idx_point_tx_customer ON point_transactions (customer_id);
CREATE INDEX idx_point_tx_type ON point_transactions (type);

-- =============================================
-- Promotions
-- =============================================
CREATE TABLE promotions (
    id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name            VARCHAR(200) NOT NULL,
    type            promo_type NOT NULL,
    discount_type   coupon_type NOT NULL,
    discount_value  NUMERIC(12,2) NOT NULL,
    min_order_amount NUMERIC(12,2) NULL,
    started_at      TIMESTAMP NOT NULL,
    ended_at        TIMESTAMP NOT NULL,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP NOT NULL
);

CREATE TABLE promotion_products (
    promotion_id    INT NOT NULL REFERENCES promotions(id),
    product_id      INT NOT NULL REFERENCES products(id),
    override_price  NUMERIC(12,2) NULL,
    PRIMARY KEY (promotion_id, product_id)
);

-- =============================================
-- Product Q&A
-- =============================================
CREATE TABLE product_qna (
    id              INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id      INT NOT NULL REFERENCES products(id),
    customer_id     INT NULL REFERENCES customers(id),
    staff_id        INT NULL REFERENCES staff(id),
    parent_id       INT NULL REFERENCES product_qna(id),
    content         TEXT NOT NULL,
    is_answered     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMP NOT NULL
);

CREATE INDEX idx_qna_product ON product_qna (product_id);

-- =============================================
-- Materialized views
-- =============================================

-- Monthly sales summary
CREATE MATERIALIZED VIEW mv_monthly_sales AS
SELECT
    date_trunc('month', o.ordered_at)::DATE AS month,
    COUNT(DISTINCT o.id) AS order_count,
    COUNT(DISTINCT o.customer_id) AS customer_count,
    SUM(o.total_amount)::BIGINT AS revenue,
    AVG(o.total_amount)::INT AS avg_order,
    SUM(o.discount_amount)::BIGINT AS total_discount
FROM orders o
WHERE o.status != 'cancelled'
GROUP BY date_trunc('month', o.ordered_at)
ORDER BY month;

CREATE UNIQUE INDEX idx_mv_monthly_sales_month ON mv_monthly_sales (month);

-- Product performance summary
CREATE MATERIALIZED VIEW mv_product_performance AS
SELECT
    p.id AS product_id,
    p.name,
    p.brand,
    p.sku,
    c.name AS category,
    p.price,
    p.cost_price,
    ROUND((p.price - p.cost_price) / NULLIF(p.price, 0) * 100, 1) AS margin_pct,
    p.stock_qty,
    p.is_active,
    COALESCE(s.total_sold, 0) AS total_sold,
    COALESCE(s.total_revenue, 0)::BIGINT AS total_revenue,
    COALESCE(s.order_count, 0) AS order_count,
    COALESCE(rv.review_count, 0) AS review_count,
    COALESCE(rv.avg_rating, 0) AS avg_rating,
    COALESCE(rt.return_count, 0) AS return_count
FROM products p
JOIN categories c ON p.category_id = c.id
LEFT JOIN (
    SELECT oi.product_id,
           SUM(oi.quantity) AS total_sold,
           SUM(oi.subtotal)::BIGINT AS total_revenue,
           COUNT(DISTINCT oi.order_id) AS order_count
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.id
    WHERE o.status != 'cancelled'
    GROUP BY oi.product_id
) s ON p.id = s.product_id
LEFT JOIN (
    SELECT product_id,
           COUNT(*) AS review_count,
           ROUND(AVG(rating), 1) AS avg_rating
    FROM reviews
    GROUP BY product_id
) rv ON p.id = rv.product_id
LEFT JOIN (
    SELECT oi.product_id, COUNT(DISTINCT r.id) AS return_count
    FROM returns r
    JOIN order_items oi ON r.order_id = oi.order_id
    GROUP BY oi.product_id
) rt ON p.id = rt.product_id;

CREATE UNIQUE INDEX idx_mv_product_perf_id ON mv_product_performance (product_id);

-- =============================================
-- Views
-- =============================================

CREATE OR REPLACE VIEW v_customer_summary AS
SELECT
    c.id,
    c.name,
    c.email,
    c.grade,
    c.gender,
    CASE
        WHEN c.birth_date IS NULL THEN NULL
        ELSE EXTRACT(YEAR FROM AGE('2025-06-30'::DATE, c.birth_date))::INT
    END AS age,
    c.created_at AS joined_at,
    COALESCE(os.order_count, 0) AS total_orders,
    COALESCE(os.total_spent, 0) AS total_spent,
    COALESCE(os.first_order, ''::TEXT) AS first_order_at,
    COALESCE(os.last_order, ''::TEXT) AS last_order_at,
    COALESCE(rv.review_count, 0) AS review_count,
    COALESCE(rv.avg_rating, 0) AS avg_rating_given,
    COALESCE(ws.wishlist_count, 0) AS wishlist_count,
    c.is_active,
    c.last_login_at,
    CASE
        WHEN c.is_active = FALSE THEN 'inactive'
        WHEN c.last_login_at IS NULL THEN 'never_logged_in'
        WHEN c.last_login_at < '2025-06-30'::DATE - INTERVAL '365 days' THEN 'dormant'
        ELSE 'active'
    END AS activity_status
FROM customers c
LEFT JOIN (
    SELECT customer_id,
           COUNT(*) AS order_count,
           SUM(total_amount)::BIGINT AS total_spent,
           MIN(ordered_at)::TEXT AS first_order,
           MAX(ordered_at)::TEXT AS last_order
    FROM orders
    WHERE status != 'cancelled'
    GROUP BY customer_id
) os ON c.id = os.customer_id
LEFT JOIN (
    SELECT customer_id,
           COUNT(*) AS review_count,
           ROUND(AVG(rating), 1) AS avg_rating
    FROM reviews
    GROUP BY customer_id
) rv ON c.id = rv.customer_id
LEFT JOIN (
    SELECT customer_id, COUNT(*) AS wishlist_count
    FROM wishlists
    GROUP BY customer_id
) ws ON c.id = ws.customer_id;

CREATE OR REPLACE VIEW v_category_tree AS
WITH RECURSIVE tree AS (
    SELECT id, name, parent_id, depth,
           name::TEXT AS full_path,
           LPAD(sort_order::TEXT, 4, '0') AS sort_key
    FROM categories
    WHERE parent_id IS NULL
    UNION ALL
    SELECT c.id, c.name, c.parent_id, c.depth,
           tree.full_path || ' > ' || c.name,
           tree.sort_key || '.' || LPAD(c.sort_order::TEXT, 4, '0')
    FROM categories c
    JOIN tree ON c.parent_id = tree.id
)
SELECT t.id, t.name, t.parent_id, t.depth, t.full_path,
       COALESCE(p.product_count, 0) AS product_count
FROM tree t
LEFT JOIN (
    SELECT category_id, COUNT(*) AS product_count
    FROM products
    GROUP BY category_id
) p ON t.id = p.category_id
ORDER BY t.sort_key;

CREATE OR REPLACE VIEW v_daily_orders AS
SELECT
    ordered_at::DATE AS order_date,
    TO_CHAR(ordered_at, 'Day') AS day_of_week,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN status = 'confirmed' THEN 1 ELSE 0 END) AS confirmed,
    SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled,
    SUM(CASE WHEN status IN ('return_requested','returned') THEN 1 ELSE 0 END) AS returned,
    SUM(CASE WHEN status != 'cancelled' THEN total_amount ELSE 0 END)::BIGINT AS revenue,
    AVG(CASE WHEN status != 'cancelled' THEN total_amount END)::INT AS avg_order_amount
FROM orders
GROUP BY ordered_at::DATE, TO_CHAR(ordered_at, 'Day')
ORDER BY order_date;

CREATE OR REPLACE VIEW v_payment_summary AS
SELECT
    method,
    COUNT(*) AS payment_count,
    SUM(amount)::BIGINT AS total_amount,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM payments), 1) AS pct,
    SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed,
    SUM(CASE WHEN status = 'refunded' THEN 1 ELSE 0 END) AS refunded,
    SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) AS failed
FROM payments
GROUP BY method
ORDER BY payment_count DESC;

CREATE OR REPLACE VIEW v_order_detail AS
SELECT
    o.id AS order_id,
    o.order_number,
    o.ordered_at,
    o.status AS order_status,
    o.total_amount,
    o.discount_amount,
    o.shipping_fee,
    o.notes,
    c.id AS customer_id,
    c.name AS customer_name,
    c.email AS customer_email,
    c.grade AS customer_grade,
    p.method AS payment_method,
    p.status AS payment_status,
    p.card_issuer,
    p.installment_months,
    s.carrier,
    s.tracking_number,
    s.status AS shipping_status,
    s.delivered_at,
    ca.address1 || ' ' || COALESCE(ca.address2, '') AS delivery_address
FROM orders o
JOIN customers c ON o.customer_id = c.id
LEFT JOIN payments p ON o.id = p.order_id
LEFT JOIN shipping s ON o.id = s.order_id
LEFT JOIN customer_addresses ca ON o.address_id = ca.id;

CREATE OR REPLACE VIEW v_revenue_growth AS
SELECT
    month,
    revenue,
    prev_revenue,
    CASE
        WHEN prev_revenue > 0
        THEN ROUND((revenue - prev_revenue) * 100.0 / prev_revenue, 1)
        ELSE NULL
    END AS growth_pct
FROM (
    SELECT
        TO_CHAR(ordered_at, 'YYYY-MM') AS month,
        SUM(total_amount)::BIGINT AS revenue,
        LAG(SUM(total_amount)::BIGINT) OVER (ORDER BY TO_CHAR(ordered_at, 'YYYY-MM')) AS prev_revenue
    FROM orders
    WHERE status != 'cancelled'
    GROUP BY TO_CHAR(ordered_at, 'YYYY-MM')
) sub
ORDER BY month;

CREATE OR REPLACE VIEW v_top_products_by_category AS
SELECT
    category_name,
    product_name,
    brand,
    total_revenue,
    total_sold,
    rank_in_category
FROM (
    SELECT
        cat.name AS category_name,
        p.name AS product_name,
        p.brand,
        COALESCE(SUM(oi.subtotal), 0)::BIGINT AS total_revenue,
        COALESCE(SUM(oi.quantity), 0) AS total_sold,
        ROW_NUMBER() OVER (
            PARTITION BY p.category_id
            ORDER BY COALESCE(SUM(oi.subtotal), 0) DESC
        ) AS rank_in_category
    FROM products p
    JOIN categories cat ON p.category_id = cat.id
    LEFT JOIN order_items oi ON p.id = oi.product_id
    LEFT JOIN orders o ON oi.order_id = o.id AND o.status != 'cancelled'
    GROUP BY p.id, cat.name, p.name, p.brand, p.category_id
) sub
WHERE rank_in_category <= 5;

CREATE OR REPLACE VIEW v_customer_rfm AS
WITH rfm_raw AS (
    SELECT
        c.id AS customer_id,
        c.name,
        c.grade,
        ('2025-06-30'::DATE - MAX(ordered_at)::DATE) AS recency_days,
        COUNT(o.id) AS frequency,
        SUM(o.total_amount)::BIGINT AS monetary
    FROM customers c
    JOIN orders o ON c.id = o.customer_id
    WHERE o.status != 'cancelled'
    GROUP BY c.id, c.name, c.grade
),
rfm_scored AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency DESC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary DESC) AS m_score
    FROM rfm_raw
)
SELECT
    customer_id, name, grade,
    recency_days, frequency, monetary,
    r_score, f_score, m_score,
    r_score + f_score + m_score AS rfm_total,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'New Customers'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost'
        ELSE 'Others'
    END AS segment
FROM rfm_scored;

CREATE OR REPLACE VIEW v_cart_abandonment AS
SELECT
    c.id AS cart_id,
    cust.name AS customer_name,
    cust.email,
    c.status,
    c.created_at,
    COUNT(ci.id) AS item_count,
    SUM(p.price * ci.quantity)::BIGINT AS potential_revenue,
    STRING_AGG(p.name, ', ') AS products
FROM carts c
JOIN customers cust ON c.customer_id = cust.id
JOIN cart_items ci ON c.id = ci.cart_id
JOIN products p ON ci.product_id = p.id
WHERE c.status = 'abandoned'
GROUP BY c.id, cust.name, cust.email, c.status, c.created_at;

CREATE OR REPLACE VIEW v_supplier_performance AS
SELECT
    s.id AS supplier_id,
    s.company_name,
    COUNT(DISTINCT p.id) AS product_count,
    SUM(CASE WHEN p.is_active THEN 1 ELSE 0 END) AS active_products,
    COALESCE(sales.total_revenue, 0) AS total_revenue,
    COALESCE(sales.total_sold, 0) AS total_sold,
    COALESCE(ret.return_count, 0) AS return_count,
    CASE
        WHEN COALESCE(sales.total_sold, 0) > 0
        THEN ROUND(COALESCE(ret.return_count, 0) * 100.0 / sales.total_sold, 2)
        ELSE 0
    END AS return_rate_pct
FROM suppliers s
LEFT JOIN products p ON s.id = p.supplier_id
LEFT JOIN (
    SELECT p2.supplier_id,
           SUM(oi.subtotal)::BIGINT AS total_revenue,
           SUM(oi.quantity) AS total_sold
    FROM order_items oi
    JOIN products p2 ON oi.product_id = p2.id
    JOIN orders o ON oi.order_id = o.id
    WHERE o.status != 'cancelled'
    GROUP BY p2.supplier_id
) sales ON s.id = sales.supplier_id
LEFT JOIN (
    SELECT p3.supplier_id, COUNT(*) AS return_count
    FROM returns r
    JOIN order_items oi ON r.order_id = oi.order_id
    JOIN products p3 ON oi.product_id = p3.id
    GROUP BY p3.supplier_id
) ret ON s.id = ret.supplier_id
GROUP BY s.id, s.company_name, sales.total_revenue, sales.total_sold, ret.return_count;

CREATE OR REPLACE VIEW v_hourly_pattern AS
SELECT
    EXTRACT(HOUR FROM ordered_at)::INT AS hour,
    COUNT(*) AS order_count,
    AVG(total_amount)::INT AS avg_amount,
    CASE
        WHEN EXTRACT(HOUR FROM ordered_at) BETWEEN 0 AND 5 THEN 'dawn'
        WHEN EXTRACT(HOUR FROM ordered_at) BETWEEN 6 AND 11 THEN 'morning'
        WHEN EXTRACT(HOUR FROM ordered_at) BETWEEN 12 AND 17 THEN 'afternoon'
        ELSE 'evening'
    END AS time_slot
FROM orders
WHERE status != 'cancelled'
GROUP BY EXTRACT(HOUR FROM ordered_at)::INT,
    CASE
        WHEN EXTRACT(HOUR FROM ordered_at) BETWEEN 0 AND 5 THEN 'dawn'
        WHEN EXTRACT(HOUR FROM ordered_at) BETWEEN 6 AND 11 THEN 'morning'
        WHEN EXTRACT(HOUR FROM ordered_at) BETWEEN 12 AND 17 THEN 'afternoon'
        ELSE 'evening'
    END
ORDER BY hour;

CREATE OR REPLACE VIEW v_product_abc AS
SELECT
    product_id, product_name, brand, total_revenue,
    revenue_pct,
    cumulative_pct,
    CASE
        WHEN cumulative_pct <= 80 THEN 'A'
        WHEN cumulative_pct <= 95 THEN 'B'
        ELSE 'C'
    END AS abc_class
FROM (
    SELECT
        product_id, product_name, brand, total_revenue,
        ROUND(total_revenue * 100.0 / SUM(total_revenue) OVER (), 2) AS revenue_pct,
        ROUND(SUM(total_revenue) OVER (ORDER BY total_revenue DESC) * 100.0
              / SUM(total_revenue) OVER (), 2) AS cumulative_pct
    FROM (
        SELECT
            p.id AS product_id,
            p.name AS product_name,
            p.brand,
            COALESCE(SUM(oi.subtotal), 0)::BIGINT AS total_revenue
        FROM products p
        LEFT JOIN order_items oi ON p.id = oi.product_id
        LEFT JOIN orders o ON oi.order_id = o.id AND o.status != 'cancelled'
        GROUP BY p.id, p.name, p.brand
    ) base
) ranked
ORDER BY total_revenue DESC;

CREATE OR REPLACE VIEW v_staff_workload AS
SELECT
    s.id AS staff_id,
    s.name,
    s.department,
    COALESCE(comp.complaint_count, 0) AS complaint_count,
    COALESCE(comp.resolved_count, 0) AS resolved_count,
    COALESCE(comp.avg_resolve_hours, 0) AS avg_resolve_hours,
    COALESCE(ord.cs_order_count, 0) AS cs_order_count
FROM staff s
LEFT JOIN (
    SELECT
        staff_id,
        COUNT(*) AS complaint_count,
        SUM(CASE WHEN status IN ('resolved','closed') THEN 1 ELSE 0 END) AS resolved_count,
        (AVG(
            CASE WHEN resolved_at IS NOT NULL
            THEN EXTRACT(EPOCH FROM (resolved_at - created_at)) / 3600
            END
        ))::INT AS avg_resolve_hours
    FROM complaints
    GROUP BY staff_id
) comp ON s.id = comp.staff_id
LEFT JOIN (
    SELECT staff_id, COUNT(*) AS cs_order_count
    FROM orders WHERE staff_id IS NOT NULL
    GROUP BY staff_id
) ord ON s.id = ord.staff_id
WHERE s.department = 'CS' OR comp.complaint_count > 0;

CREATE OR REPLACE VIEW v_coupon_effectiveness AS
SELECT
    cp.id AS coupon_id,
    cp.code,
    cp.name,
    cp.type,
    cp.discount_value,
    cp.is_active,
    COALESCE(u.usage_count, 0) AS usage_count,
    cp.usage_limit,
    COALESCE(u.total_discount, 0) AS total_discount_given,
    COALESCE(u.total_order_revenue, 0) AS total_order_revenue,
    CASE
        WHEN COALESCE(u.total_discount, 0) > 0
        THEN ROUND(u.total_order_revenue / u.total_discount, 1)
        ELSE 0
    END AS roi_ratio
FROM coupons cp
LEFT JOIN (
    SELECT
        cu.coupon_id,
        COUNT(*) AS usage_count,
        SUM(cu.discount_amount)::BIGINT AS total_discount,
        SUM(o.total_amount)::BIGINT AS total_order_revenue
    FROM coupon_usage cu
    JOIN orders o ON cu.order_id = o.id
    GROUP BY cu.coupon_id
) u ON cp.id = u.coupon_id
ORDER BY COALESCE(u.usage_count, 0) DESC;

CREATE OR REPLACE VIEW v_return_analysis AS
SELECT
    reason,
    COUNT(*) AS total_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM returns), 1) AS pct,
    SUM(CASE WHEN return_type = 'refund' THEN 1 ELSE 0 END) AS refund_count,
    SUM(CASE WHEN return_type = 'exchange' THEN 1 ELSE 0 END) AS exchange_count,
    AVG(refund_amount)::INT AS avg_refund_amount,
    SUM(CASE WHEN inspection_result = 'defective' THEN 1 ELSE 0 END) AS defective_count,
    SUM(CASE WHEN inspection_result = 'good' THEN 1 ELSE 0 END) AS good_count,
    (AVG(
        CASE WHEN completed_at IS NOT NULL
        THEN EXTRACT(DAY FROM (completed_at - requested_at))
        END
    ))::INT AS avg_process_days
FROM returns
GROUP BY reason
ORDER BY total_count DESC;

CREATE OR REPLACE VIEW v_yearly_kpi AS
SELECT
    o_stats.yr AS year,
    o_stats.total_revenue,
    o_stats.order_count,
    o_stats.customer_count,
    (o_stats.total_revenue / o_stats.order_count)::INT AS avg_order_value,
    (o_stats.total_revenue / o_stats.customer_count)::INT AS revenue_per_customer,
    COALESCE(c.new_customers, 0) AS new_customers,
    o_stats.cancel_count,
    ROUND(o_stats.cancel_count * 100.0 / o_stats.order_count, 1) AS cancel_rate_pct,
    o_stats.return_count,
    ROUND(o_stats.return_count * 100.0 / o_stats.order_count, 1) AS return_rate_pct,
    COALESCE(r.review_count, 0) AS review_count,
    COALESCE(comp.complaint_count, 0) AS complaint_count
FROM (
    SELECT
        EXTRACT(YEAR FROM o.ordered_at)::INT AS yr,
        SUM(CASE WHEN o.status != 'cancelled' THEN o.total_amount ELSE 0 END)::BIGINT AS total_revenue,
        COUNT(*) AS order_count,
        COUNT(DISTINCT o.customer_id) AS customer_count,
        SUM(CASE WHEN o.status = 'cancelled' THEN 1 ELSE 0 END) AS cancel_count,
        SUM(CASE WHEN o.status IN ('return_requested','returned') THEN 1 ELSE 0 END) AS return_count
    FROM orders o
    GROUP BY EXTRACT(YEAR FROM o.ordered_at)::INT
) o_stats
LEFT JOIN (
    SELECT EXTRACT(YEAR FROM created_at)::INT AS yr, COUNT(*) AS new_customers
    FROM customers GROUP BY EXTRACT(YEAR FROM created_at)::INT
) c ON o_stats.yr = c.yr
LEFT JOIN (
    SELECT EXTRACT(YEAR FROM created_at)::INT AS yr, COUNT(*) AS review_count
    FROM reviews GROUP BY EXTRACT(YEAR FROM created_at)::INT
) r ON o_stats.yr = r.yr
LEFT JOIN (
    SELECT EXTRACT(YEAR FROM created_at)::INT AS yr, COUNT(*) AS complaint_count
    FROM complaints GROUP BY EXTRACT(YEAR FROM created_at)::INT
) comp ON o_stats.yr = comp.yr
ORDER BY o_stats.yr;

-- v_monthly_sales and v_product_performance are materialized views (already defined above)

-- =============================================
-- Access control examples (commented out)
-- =============================================
-- CREATE ROLE reader LOGIN PASSWORD 'readonly_password';
-- CREATE ROLE admin_user LOGIN PASSWORD 'admin_password';
-- GRANT CONNECT ON DATABASE ecommerce TO reader;
-- GRANT USAGE ON SCHEMA public TO reader;
-- GRANT SELECT ON ALL TABLES IN SCHEMA public TO reader;
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO admin_user;
-- REVOKE DROP ON SCHEMA public FROM reader;
