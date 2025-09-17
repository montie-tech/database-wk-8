-- Full relational schema for an E-commerce Store (MySQL / InnoDB)
-- Drop existing DB (CAUTION in production) and create new one
DROP DATABASE IF EXISTS ecommerce_store;
CREATE DATABASE ecommerce_store CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ecommerce_store;
SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================
-- USERS: customers & admin accounts
-- =====================================================
CREATE TABLE users (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    role ENUM('customer','admin','seller') NOT NULL DEFAULT 'customer',
    PRIMARY KEY (id),
    UNIQUE KEY ux_users_email (email)
) ENGINE=InnoDB;

-- One-to-one user profile (stores optional profile data)
CREATE TABLE user_profiles (
    user_id INT UNSIGNED NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(30),
    dob DATE,
    bio TEXT,
    PRIMARY KEY (user_id),
    CONSTRAINT fk_user_profiles_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Addresses (one user can have many addresses)
CREATE TABLE addresses (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id INT UNSIGNED NOT NULL,
    label VARCHAR(50) DEFAULT 'home', -- e.g., 'home', 'work'
    recipient_name VARCHAR(200) NOT NULL,
    street VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100),
    postal_code VARCHAR(30) NOT NULL,
    country VARCHAR(100) NOT NULL,
    phone VARCHAR(30),
    is_default TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX ix_addresses_user (user_id),
    CONSTRAINT fk_addresses_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =====================================================
-- CATALOG: products, categories, suppliers
-- =====================================================
CREATE TABLE categories (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(150) NOT NULL,
    slug VARCHAR(180) NOT NULL,
    description TEXT,
    parent_id INT UNSIGNED DEFAULT NULL, -- for hierarchical categories
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY ux_categories_slug (slug),
    CONSTRAINT fk_categories_parent
        FOREIGN KEY (parent_id) REFERENCES categories(id)
        ON DELETE SET NULL
        ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE suppliers (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(200) NOT NULL,
    contact_email VARCHAR(255),
    phone VARCHAR(50),
    website VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY ux_suppliers_name (name)
) ENGINE=InnoDB;

CREATE TABLE products (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    sku VARCHAR(64) NOT NULL, -- stock keeping unit
    name VARCHAR(255) NOT NULL,
    short_description VARCHAR(500),
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    cost_price DECIMAL(10,2) DEFAULT NULL,
    weight_kg DECIMAL(8,3) DEFAULT NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY ux_products_sku (sku),
    CHECK (price >= 0),
    CHECK (cost_price IS NULL OR cost_price >= 0)
) ENGINE=InnoDB;

-- Many-to-Many product <-> category
CREATE TABLE product_categories (
    product_id INT UNSIGNED NOT NULL,
    category_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (product_id, category_id),
    INDEX ix_pc_category (category_id),
    CONSTRAINT fk_pc_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_pc_category FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Many-to-many product <-> supplier (a product can have multiple suppliers)
CREATE TABLE product_suppliers (
    product_id INT UNSIGNED NOT NULL,
    supplier_id INT UNSIGNED NOT NULL,
    supplier_sku VARCHAR(128),
    lead_time_days INT UNSIGNED DEFAULT NULL,
    PRIMARY KEY (product_id, supplier_id),
    CONSTRAINT fk_ps_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_ps_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Images for products (one product many images)
CREATE TABLE product_images (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    product_id INT UNSIGNED NOT NULL,
    url VARCHAR(2048) NOT NULL,
    alt_text VARCHAR(255),
    sort_order INT UNSIGNED DEFAULT 0,
    is_primary TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX ix_product_images_product (product_id),
    CONSTRAINT fk_product_images_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Product reviews (customer review of product)
CREATE TABLE reviews (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    product_id INT UNSIGNED NOT NULL,
    user_id INT UNSIGNED NULL,
    rating TINYINT UNSIGNED NOT NULL, -- 1..5
    title VARCHAR(255),
    body TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX ix_reviews_product (product_id),
    INDEX ix_reviews_user (user_id),
    CONSTRAINT fk_reviews_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_reviews_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Inventory table (one-to-one-ish with product or can be multi-location later)
CREATE TABLE inventory (
    product_id INT UNSIGNED NOT NULL,
    quantity INT UNSIGNED NOT NULL DEFAULT 0,
    reserved INT UNSIGNED NOT NULL DEFAULT 0, -- reserved for carts/orders
    warehouse_location VARCHAR(255),
    last_updated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (product_id),
    CONSTRAINT fk_inventory_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CHECK (quantity >= 0),
    CHECK (reserved >= 0)
) ENGINE=InnoDB;

-- Promotions / coupons
CREATE TABLE promotions (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    code VARCHAR(64) NOT NULL,
    description VARCHAR(500),
    discount_percent DECIMAL(5,2) DEFAULT NULL, -- e.g., 15.00 = 15%
    discount_amount DECIMAL(10,2) DEFAULT NULL, -- fixed amount off
    min_order_amount DECIMAL(10,2) DEFAULT NULL,
    starts_at DATETIME DEFAULT NULL,
    ends_at DATETIME DEFAULT NULL,
    usage_limit INT UNSIGNED DEFAULT NULL, -- global usage limit
    active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY ux_promotions_code (code)
) ENGINE=InnoDB;

-- =====================================================
-- ORDERS & PAYMENTS
-- =====================================================
CREATE TABLE orders (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id INT UNSIGNED NULL,
    order_number VARCHAR(64) NOT NULL, -- human readable, unique
    status ENUM('pending','paid','processing','shipped','delivered','cancelled','refunded') NOT NULL DEFAULT 'pending',
    total_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    currency CHAR(3) NOT NULL DEFAULT 'USD',
    shipping_address_id INT UNSIGNED, -- FK to addresses (nullable in case guest or custom)
    billing_address_id INT UNSIGNED,
    promotion_id INT UNSIGNED DEFAULT NULL,
    placed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY ux_orders_order_number (order_number),
    INDEX ix_orders_user (user_id),
    CONSTRAINT fk_orders_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_orders_shipping_address FOREIGN KEY (shipping_address_id) REFERENCES addresses(id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_orders_billing_address FOREIGN KEY (billing_address_id) REFERENCES addresses(id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_orders_promotion FOREIGN KEY (promotion_id) REFERENCES promotions(id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Order items: many products per order. Composite PK (order_id, product_id, line_no)
CREATE TABLE order_items (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    order_id BIGINT UNSIGNED NOT NULL,
    product_id INT UNSIGNED NOT NULL,
    product_name_snapshot VARCHAR(255) NOT NULL,
    sku_snapshot VARCHAR(64),
    quantity INT UNSIGNED NOT NULL DEFAULT 1,
    unit_price DECIMAL(10,2) NOT NULL, -- price at time of order
    discount DECIMAL(10,2) DEFAULT 0.00,
    tax_amount DECIMAL(10,2) DEFAULT 0.00,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX ix_order_items_order (order_id),
    INDEX ix_order_items_product (product_id),
    CONSTRAINT fk_order_items_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_order_items_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CHECK (quantity > 0)
) ENGINE=InnoDB;

-- Payments: one-to-one-ish with orders (an order may have one payment record; refunds may create multiple payments/refunds depending on design)
CREATE TABLE payments (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    order_id BIGINT UNSIGNED NOT NULL,
    payment_provider VARCHAR(100) NOT NULL, -- e.g., stripe, paypal
    provider_transaction_id VARCHAR(255),
    amount DECIMAL(12,2) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'USD',
    method ENUM('card','paypal','bank_transfer','wallet') NOT NULL,
    status ENUM('initiated','success','failed','refunded') NOT NULL DEFAULT 'initiated',
    paid_at TIMESTAMP NULL DEFAULT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY ux_payments_order (order_id),
    INDEX ix_payments_provider_tx (provider_transaction_id),
    CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CHECK (amount >= 0)
) ENGINE=InnoDB;

-- Shipments (optional tracking)
CREATE TABLE shipments (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    order_id BIGINT UNSIGNED NOT NULL,
    carrier VARCHAR(100),
    tracking_number VARCHAR(200),
    shipped_at TIMESTAMP NULL DEFAULT NULL,
    delivered_at TIMESTAMP NULL DEFAULT NULL,
    status ENUM('label_created','in_transit','delivered','exception') DEFAULT 'label_created',
    PRIMARY KEY (id),
    INDEX ix_shipments_order (order_id),
    CONSTRAINT fk_shipments_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =====================================================
-- CARTS (simple implementation)
-- =====================================================
CREATE TABLE carts (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id INT UNSIGNED,
    session_token VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX ix_carts_user (user_id),
    CONSTRAINT fk_carts_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE cart_items (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    cart_id BIGINT UNSIGNED NOT NULL,
    product_id INT UNSIGNED NOT NULL,
    quantity INT UNSIGNED NOT NULL DEFAULT 1,
    added_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX ix_cart_items_cart (cart_id),
    INDEX ix_cart_items_product (product_id),
    CONSTRAINT fk_cart_items_cart FOREIGN KEY (cart_id) REFERENCES carts(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_cart_items_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CHECK (quantity > 0)
) ENGINE=InnoDB;

-- =====================================================
-- AUDIT / LOGGING (simple)
-- =====================================================
CREATE TABLE audit_logs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actor_user_id INT UNSIGNED,
    entity_type VARCHAR(64),
    entity_id VARCHAR(64),
    action VARCHAR(100),
    details JSON NULL,
    PRIMARY KEY (id),
    INDEX ix_audit_actor (actor_user_id),
    CONSTRAINT fk_audit_actor FOREIGN KEY (actor_user_id) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =====================================================
-- SAMPLE INDEXES / VIEWS
-- =====================================================
-- Example: quick lookup view to get order totals (MySQL view)
DROP VIEW IF EXISTS vw_orders_summary;
CREATE VIEW vw_orders_summary AS
SELECT
  o.id AS order_id,
  o.order_number,
  o.user_id,
  u.email AS user_email,
  o.status,
  o.total_amount,
  o.placed_at
FROM orders o
LEFT JOIN users u ON u.id = o.user_id;

-- =====================================================
-- FINAL NOTES
-- =====================================================
-- You can add triggers to maintain inventory/reserved quantities on order creation/payment events,
-- and add stored procedures for common tasks (e.g., apply_promotion).
-- Schema choices:
--  - orders.total_amount is stored as snapshot; line items preserve product_name_snapshot & unit_price to keep immutable history.
--  - payments has UNIQUE(order_id) to enforce one primary payment record per order (can be relaxed if partial payments/refunds required).
--  - product_categories & product_suppliers model many-to-many relationships.
--  - user_profiles demonstrates an explicit one-to-one relationship using user_id as PK.

