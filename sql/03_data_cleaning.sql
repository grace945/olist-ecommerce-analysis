-- ============================================
-- OLIST DATA CLEANING
-- ============================================
-- Purpose:
-- Clean confirmed import issues and document
-- unresolved data-quality anomalies.
--
-- IMPORTANT:
-- Some sections reload tables from the original CSV files.
-- Make sure the raw CSV files are available before running
-- this script.
-- ============================================

USE olist_analytics;


-- ============================================
-- 1. FIX ORDERS DATE IMPORT
-- ============================================

-- The original CSV stores date/time values in M/D/YYYY H:MM format.
-- Direct import into MySQL DATETIME previously produced invalid zero dates.
--
-- The table is reloaded from the raw CSV so date values can be
-- converted explicitly using STR_TO_DATE().
--
-- Empty date values are converted to NULL.
-- The trailing carriage return in the final CSV column is removed.

TRUNCATE TABLE orders;

LOAD DATA LOCAL INFILE 'C:/Users/ASUS/Desktop/Data Analyst/olist_orders_dataset.csv'
INTO TABLE orders
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    order_id,
    customer_id,
    order_status,
    @order_purchase_timestamp,
    @order_approved_at,
    @order_delivered_carrier_date,
    @order_delivered_customer_date,
    @order_estimated_delivery_date
)
SET
    order_purchase_timestamp =
        STR_TO_DATE(NULLIF(@order_purchase_timestamp, ''), '%c/%e/%Y %H:%i'),

    order_approved_at =
        STR_TO_DATE(NULLIF(@order_approved_at, ''), '%c/%e/%Y %H:%i'),

    order_delivered_carrier_date =
        STR_TO_DATE(NULLIF(@order_delivered_carrier_date, ''), '%c/%e/%Y %H:%i'),

    order_delivered_customer_date =
        STR_TO_DATE(NULLIF(@order_delivered_customer_date, ''), '%c/%e/%Y %H:%i'),

    order_estimated_delivery_date =
        STR_TO_DATE(
            NULLIF(REPLACE(@order_estimated_delivery_date, '\r', ''), ''),
            '%c/%e/%Y %H:%i'
        );


-- ============================================
-- 2. FIX ORDER_ITEMS DATE IMPORT
-- ============================================

-- shipping_limit_date was affected by the same CSV date-format issue.
-- The table is reloaded and the date is converted explicitly.
-- The trailing carriage return in freight_value is also removed.

TRUNCATE TABLE order_items;

LOAD DATA LOCAL INFILE 'C:/Users/ASUS/Desktop/Data Analyst/olist_order_items_dataset.csv'
INTO TABLE order_items
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    order_id,
    order_item_id,
    product_id,
    seller_id,
    @shipping_limit_date,
    price,
    @freight_value
)
SET
    shipping_limit_date =
        STR_TO_DATE(NULLIF(@shipping_limit_date, ''), '%c/%e/%Y %H:%i'),

    freight_value =
        NULLIF(REPLACE(@freight_value, '\r', ''), '');


-- ============================================
-- 3. FIX ORDER_REVIEWS DATE IMPORT
-- ============================================

-- Review date columns were initially imported as invalid zero dates.
-- The table is reloaded from the raw CSV and both date columns
-- are converted explicitly using STR_TO_DATE().

TRUNCATE TABLE order_reviews;

LOAD DATA LOCAL INFILE 'C:/Users/ASUS/Desktop/Data Analyst/olist_order_reviews_dataset.csv'
INTO TABLE order_reviews
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    @review_creation_date,
    @review_answer_timestamp
)
SET
    review_creation_date =
        STR_TO_DATE(NULLIF(@review_creation_date, ''), '%c/%e/%Y %H:%i'),

    review_answer_timestamp =
        STR_TO_DATE(
            NULLIF(REPLACE(@review_answer_timestamp, '\r', ''), ''),
            '%c/%e/%Y %H:%i'
        );


-- ============================================
-- 4. CLEAN CUSTOMER STATE CODES
-- ============================================

-- customer_state contains a trailing carriage-return character
-- introduced during CSV import.

UPDATE customers
SET customer_state = REPLACE(customer_state, '\r', '')
WHERE customer_state LIKE CONCAT('%', '\r');


-- Verify state-code length after cleaning
SELECT
    customer_state,
    LENGTH(customer_state) AS state_length,
    COUNT(*) AS customer_count
FROM customers
GROUP BY customer_state, LENGTH(customer_state)
ORDER BY customer_state;


-- ============================================
-- 5. CLEAN SELLER STATE CODES
-- ============================================

-- seller_state contains the same trailing carriage-return artifact.

UPDATE sellers
SET seller_state = REPLACE(seller_state, '\r', '')
WHERE seller_state LIKE CONCAT('%', '\r');


-- Verify state-code length after cleaning
SELECT
    seller_state,
    LENGTH(seller_state) AS state_length,
    COUNT(*) AS seller_count
FROM sellers
GROUP BY seller_state, LENGTH(seller_state)
ORDER BY seller_state;


-- Verify cleaning
SELECT
    product_category_name_english,
    LENGTH(product_category_name_english) AS category_length
FROM category_translation
ORDER BY product_category_name_english;


-- ============================================
-- 6. CLEAN CATEGORY TRANSLATION VALUES
-- ============================================

-- Remove trailing carriage-return characters
-- from English category names introduced during CSV import.

UPDATE category_translation
SET product_category_name_english =
    REPLACE(product_category_name_english, '\r', '')
WHERE product_category_name_english LIKE CONCAT('%', '\r');
-- ============================================
-- 6. DOCUMENT UNRESOLVED DATA QUALITY ISSUES
-- ============================================

-- ORDERS
-- 8 delivered orders have NULL order_delivered_customer_date.
-- The correct delivery timestamps cannot be inferred reliably.
-- These records are preserved without modification.

-- PAYMENTS
-- 2 delivered credit-card payment records have payment_installments = 0.
-- The intended installment count cannot be determined reliably.
-- These records are preserved without modification.

-- PRODUCTS
-- 610 products have missing product_category_name values.
-- The correct categories cannot be inferred reliably.
-- These records are preserved without modification.

-- PRODUCTS
-- 6 products have product_weight_g = 0.
-- 2 of these also have zero length, height, and width.
-- The correct physical measurements cannot be inferred reliably.
-- These records are preserved without modification.

-- CATEGORY TRANSLATIONS
-- 2 product categories are missing from category_translation:
--   pc_gamer
--   portateis_cozinha_e_preparadores_de_alimentos
--
-- These missing translations affect 13 products.
-- No English translation is invented during cleaning.