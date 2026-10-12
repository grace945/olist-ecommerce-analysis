USE olist_analytics;

-- =========================================================
-- 02_data_profiling.sql
-- Purpose:
-- Profile the Olist dataset before cleaning and analysis.
-- Focus areas:
-- - Row counts
-- - Uniqueness
-- - NULL values
-- - Data quality issues
-- - Value ranges
-- - Referential integrity
-- - Table grain
-- =========================================================


-- =========================================================
-- 1. CUSTOMERS
-- Grain:
-- One row represents one customer record associated with an order.
-- customer_id is the record-level identifier.
-- customer_unique_id is the better identifier for the same real customer
-- across multiple orders.
-- =========================================================

-- Total rows
SELECT COUNT(*) AS total_rows
FROM customers;

-- Uniqueness checks
SELECT COUNT(DISTINCT customer_id) AS distinct_customer_ids
FROM customers;

SELECT COUNT(DISTINCT customer_unique_id) AS distinct_unique_customers
FROM customers;

-- NULL / empty-value checks
SELECT COUNT(*) AS missing_customer_id
FROM customers
WHERE customer_id IS NULL OR customer_id = '';

SELECT COUNT(*) AS missing_customer_unique_id
FROM customers
WHERE customer_unique_id IS NULL OR customer_unique_id = '';

SELECT COUNT(*) AS missing_customer_zip_code_prefix
FROM customers
WHERE customer_zip_code_prefix IS NULL;

SELECT COUNT(*) AS missing_customer_city
FROM customers
WHERE customer_city IS NULL OR customer_city = '';

SELECT COUNT(*) AS missing_customer_state
FROM customers
WHERE customer_state IS NULL OR customer_state = '';

-- State code length check
-- This exposed an extra carriage-return character (\r)
-- caused by CSV import line endings.
SELECT
    customer_state,
    LENGTH(customer_state) AS state_length
FROM customers
GROUP BY customer_state, LENGTH(customer_state)
ORDER BY customer_state;

-- Sample city inspection for suspicious whitespace / formatting
SELECT DISTINCT
    customer_city,
    LENGTH(customer_city) AS city_length
FROM customers
ORDER BY customer_city
LIMIT 30;

-- Customer distribution by state
SELECT
    customer_state,
    COUNT(*) AS customer_count
FROM customers
GROUP BY customer_state
ORDER BY customer_count DESC;


-- =========================================================
-- 2. ORDERS
-- Grain:
-- One row represents one order.
-- order_id is expected to be unique.
-- =========================================================

-- Schema inspection
DESCRIBE orders;

-- Total rows and order_id uniqueness
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders
FROM orders;

-- Order status distribution
SELECT
    order_status,
    COUNT(*) AS order_count
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;

-- IMPORTANT:
-- During profiling, the datetime columns were found to be corrupted
-- because the CSV used M/D/YYYY H:MM format.
-- The import issue was fixed in 03_data_cleaning.sql.

-- NULL checks for order lifecycle timestamps
SELECT COUNT(*) AS null_purchase_timestamp
FROM orders
WHERE order_purchase_timestamp IS NULL;

SELECT COUNT(*) AS null_approved_at
FROM orders
WHERE order_approved_at IS NULL;

SELECT COUNT(*) AS null_delivered_carrier_date
FROM orders
WHERE order_delivered_carrier_date IS NULL;

SELECT COUNT(*) AS null_delivered_customer_date
FROM orders
WHERE order_delivered_customer_date IS NULL;

SELECT COUNT(*) AS null_estimated_delivery_date
FROM orders
WHERE order_estimated_delivery_date IS NULL;

-- Dataset date range
SELECT
    MIN(order_purchase_timestamp) AS first_order,
    MAX(order_purchase_timestamp) AS last_order
FROM orders;

-- Missing customer delivery dates by order status
-- Most NULL delivery dates are consistent with orders that did not
-- reach the delivered stage.
SELECT
    order_status,
    COUNT(*) AS null_delivery_count
FROM orders
WHERE order_delivered_customer_date IS NULL
GROUP BY order_status
ORDER BY null_delivery_count DESC;

-- Data-quality inconsistency:
-- A small number of orders are marked as delivered but have no
-- recorded customer delivery timestamp.
-- These records are documented but not imputed because there is
-- not enough evidence to reconstruct the missing dates.
SELECT *
FROM orders
WHERE order_delivered_customer_date IS NULL
  AND order_status = 'delivered';


-- =========================================================
-- 3. ORDER_ITEMS
-- Grain:
-- One row represents one item within an order.
-- order_id is not expected to be unique.
-- The expected logical key is:
-- (order_id, order_item_id)
-- =========================================================

-- Total rows and distinct orders
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS distinct_orders
FROM order_items;

-- Duplicate check on the expected composite key
SELECT
    order_id,
    order_item_id,
    COUNT(*) AS row_count
FROM order_items
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;

-- NULL checks
SELECT
    SUM(product_id IS NULL) AS null_product_id,
    SUM(seller_id IS NULL) AS null_seller_id,
    SUM(price IS NULL) AS null_price,
    SUM(freight_value IS NULL) AS null_freight_value,
    SUM(shipping_limit_date IS NULL) AS null_shipping_limit_date
FROM order_items;

-- Price range
SELECT
    MIN(price) AS min_price,
    MAX(price) AS max_price
FROM order_items;

-- Freight range
SELECT
    MIN(freight_value) AS min_freight,
    MAX(freight_value) AS max_freight
FROM order_items;

-- Zero / negative values
SELECT
    SUM(price = 0) AS zero_price,
    SUM(price < 0) AS negative_price,
    SUM(freight_value = 0) AS zero_freight,
    SUM(freight_value < 0) AS negative_freight
FROM order_items;

-- Items per order
WITH item_count AS (
    SELECT
        order_id,
        COUNT(*) AS item_count
    FROM order_items
    GROUP BY order_id
)
SELECT
    MIN(item_count) AS min_items_per_order,
    MAX(item_count) AS max_items_per_order,
    AVG(item_count) AS avg_items_per_order
FROM item_count;

-- Top 10 orders by item count
WITH item_count AS (
    SELECT
        order_id,
        COUNT(*) AS item_count
    FROM order_items
    GROUP BY order_id
)
SELECT
    order_id,
    item_count
FROM item_count
ORDER BY item_count DESC
LIMIT 10;

-- Referential integrity:
-- order_items.order_id -> orders.order_id
SELECT
    item.order_id
FROM order_items AS item
LEFT JOIN orders AS o
    ON item.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Referential integrity:
-- order_items.product_id -> products.product_id
SELECT
    item.product_id
FROM order_items AS item
LEFT JOIN products AS p
    ON item.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Referential integrity:
-- order_items.seller_id -> sellers.seller_id
SELECT
    item.seller_id
FROM order_items AS item
LEFT JOIN sellers AS s
    ON item.seller_id = s.seller_id
WHERE s.seller_id IS NULL;


-- =========================================================
-- 3. ORDER_ITEMS
-- Grain:
-- orphan order_id.
-- NULLs.
-- duplicate (order_id, payment_sequential)
-- payment types distribution
-- payment_value zero/negative/min/max
-- payment_installments zero/negative/min/max
-- payment rows per order
-- understanding join-grain risk
-- =========================================================

-- Referential integrity:
-- pay.order_id -> orders.order_id
SELECT
     pay.order_id
FROM order_payments AS pay
LEFT JOIN orders  AS orders
    ON pay.order_id = orders.order_id
WHERE orders.order_id IS NULL;

-- NULL checks
SELECT
    SUM(order_id IS NULL) AS null_order_id,
    SUM(payment_sequential IS NULL) AS null_payment_sequential ,
    SUM(payment_type IS NULL) AS payment_type,
    SUM(payment_installments IS NULL) AS null_payment_installments,
    SUM(payment_value IS NULL) AS null_payment_value
FROM order_payments;

-- duplicate (order_id, payment_sequential)
SELECT
    order_id,
    payment_sequential,
    COUNT(*) AS row_count
FROM order_payments
GROUP BY order_id,payment_sequential
HAVING COUNT(*) > 1;

-- payment types distribution
SELECT
    payment_type,
    COUNT(*) AS row_count
FROM order_payments
GROUP BY payment_type;


SELECT *
FROM order_payments
where payment_type='not_defined';

-- check the status of the orders that have payment_type not_defined to see the bussines behavoire
SELECT
     pay.order_id,
     pay.payment_type,
     orders.order_status
FROM order_payments AS pay
inner JOIN orders  AS orders
    ON pay.order_id = orders.order_id
where payment_type='not_defined';

-- payment_value: zero / negative / range
SELECT
    SUM(payment_value = 0) AS zero_payment_value,
    SUM(payment_value < 0) AS negative_payment_value,
    MIN(payment_value) AS min_payment_value,
    MAX(payment_value) AS max_payment_value
FROM order_payments;

SELECT
    order_id,
    payment_type,
    payment_value
FROM order_payments
WHERE payment_value = 0;


SELECT
    p.order_id,
    p.payment_sequential,
    p.payment_type,
    p.payment_value,
    o.order_status
FROM order_payments AS p
JOIN orders AS o
    ON p.order_id = o.order_id
WHERE p.payment_value = 0
  AND p.payment_type = 'voucher'
ORDER BY p.order_id, p.payment_sequential;

SELECT
    p.order_id,
    p.payment_sequential,
    p.payment_type,
    p.payment_installments,
    p.payment_value
FROM order_payments AS p
WHERE p.order_id IN (
    SELECT DISTINCT order_id
    FROM order_payments
    WHERE payment_value = 0
      AND payment_type = 'voucher'
)
ORDER BY p.order_id, p.payment_sequential;

-- installments: zero / negative / range
SELECT
    SUM(payment_installments = 0) AS zero_installments,
    SUM(payment_installments < 0) AS negative_installments,
    MIN(payment_installments) AS min_installments,
    MAX(payment_installments) AS max_installments
FROM order_payments;


SELECT
    order_id,
    payment_type,
    payment_installments,
    payment_value
FROM order_payments
WHERE payment_installments = 0;

SELECT
    p.order_id,
    p.payment_sequential,
    p.payment_type,
    p.payment_value,
    p.payment_installments,
    o.order_status
FROM order_payments AS p
JOIN orders AS o
    ON p.order_id = o.order_id
WHERE p. payment_installments = 0
  AND p.payment_type = 'credit_card'
ORDER BY p.order_id, p.payment_sequential;



-- Distribution of installments
SELECT
    payment_installments,
    COUNT(*) AS payment_count
FROM order_payments
GROUP BY payment_installments
ORDER BY payment_installments;

WITH payment_count AS (
    SELECT
        order_id,
        COUNT(*) AS payment_rows
    FROM order_payments
    GROUP BY order_id
)
SELECT
    MIN(payment_rows) AS min_payments_per_order,
    MAX(payment_rows) AS max_payments_per_order,
    AVG(payment_rows) AS avg_payments_per_order
FROM payment_count;


WITH payment_count AS (
    SELECT
        order_id,
        COUNT(*) AS payment_rows
    FROM order_payments
    GROUP BY order_id
)
SELECT
    order_id,
    payment_rows
FROM payment_count
ORDER BY payment_rows DESC
LIMIT 10;

-- ============================================
-- ORDER_REVIEWS PROFILING
-- ============================================


-- 1. Total rows + distinct review IDs + distinct order IDs
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT review_id) AS distinct_review_ids,
    COUNT(DISTINCT order_id) AS distinct_order_ids
FROM order_reviews;


-- 2. Check duplicate review_id
SELECT
    review_id,
    COUNT(*) AS row_count
FROM order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1;


-- 3. Check duplicate logical combination (review_id, order_id)
SELECT
    review_id,
    order_id,
    COUNT(*) AS row_count
FROM order_reviews
GROUP BY review_id, order_id
HAVING COUNT(*) > 1;

SELECT
    review_id,
    order_id,
    review_score,
    review_creation_date
FROM order_reviews
WHERE review_id IN (
    SELECT review_id
    FROM order_reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
)
ORDER BY review_id, order_id
LIMIT 50;
-- 4. Check how many reviews each order has
WITH review_count AS (
    SELECT
        order_id,
        COUNT(*) AS reviews_per_order
    FROM order_reviews
    GROUP BY order_id
)
SELECT
    MIN(reviews_per_order) AS min_reviews_per_order,
    MAX(reviews_per_order) AS max_reviews_per_order,
    AVG(reviews_per_order) AS avg_reviews_per_order
FROM review_count;


-- 5. Show orders with the highest number of reviews
WITH review_count AS (
    SELECT
        order_id,
        COUNT(*) AS reviews_per_order
    FROM order_reviews
    GROUP BY order_id
)
SELECT
    order_id,
    reviews_per_order
FROM review_count
ORDER BY reviews_per_order DESC
LIMIT 10;


-- 6. NULL checks
SELECT
    SUM(review_id IS NULL) AS null_review_id,
    SUM(order_id IS NULL) AS null_order_id,
    SUM(review_score IS NULL) AS null_review_score,

    SUM(review_comment_title IS NULL OR review_comment_title = '') 
        AS missing_comment_title,

    SUM(review_comment_message IS NULL OR review_comment_message = '') 
        AS missing_comment_message,

    SUM(review_creation_date IS NULL) AS null_creation_date,
    SUM(review_answer_timestamp IS NULL) AS null_answer_timestamp
FROM order_reviews;


-- 7. Review score distribution
SELECT
    review_score,
    COUNT(*) AS review_count
FROM order_reviews
GROUP BY review_score
ORDER BY review_score;


-- 8. Check invalid review scores
SELECT
    review_score,
    COUNT(*) AS review_count
FROM order_reviews
WHERE review_score NOT BETWEEN 1 AND 5
GROUP BY review_score
ORDER BY review_score;


-- 9. Review date ranges
SELECT
    MIN(review_creation_date) AS first_review_creation,
    MAX(review_creation_date) AS last_review_creation,
    MIN(review_answer_timestamp) AS first_review_answer,
    MAX(review_answer_timestamp) AS last_review_answer
FROM order_reviews;


-- 10. Check if review was answered before it was created
SELECT
    review_id,
    order_id,
    review_creation_date,
    review_answer_timestamp
FROM order_reviews
WHERE review_answer_timestamp < review_creation_date;


-- 11. Count reviews with/without written comments
SELECT
    SUM(review_comment_title IS NULL OR review_comment_title = '') AS missing_titles,
    SUM(review_comment_message IS NULL OR review_comment_message = '') AS missing_messages,
    SUM(review_comment_message IS NOT NULL AND review_comment_message <> '') AS reviews_with_message
FROM order_reviews;


-- 12. Referential integrity:
-- Every order_id in order_reviews should exist in orders
SELECT
    r.order_id
FROM order_reviews AS r
LEFT JOIN orders AS o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;

-- ============================================
-- PRODUCTS PROFILING
-- ============================================

-- 1. Total rows + distinct product IDs
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT product_id) AS distinct_product_ids
FROM products;


-- 2. Check duplicate product_id
SELECT
    product_id,
    COUNT(*) AS row_count
FROM products
GROUP BY product_id
HAVING COUNT(*) > 1;


-- 3. NULL / missing checks
SELECT
    SUM(product_id IS NULL) AS null_product_id,
    SUM(product_category_name IS NULL OR TRIM(product_category_name) = '') AS missing_category,
    SUM(product_name_lenght IS NULL) AS null_name_length,
    SUM(product_description_lenght IS NULL) AS null_description_length,
    SUM(product_photos_qty IS NULL) AS null_photos_qty,
    SUM(product_weight_g IS NULL) AS null_weight,
    SUM(product_length_cm IS NULL) AS null_length,
    SUM(product_height_cm IS NULL) AS null_height,
    SUM(product_width_cm IS NULL) AS null_width
FROM products;


-- 4. Category distribution
SELECT
    product_category_name,
    COUNT(*) AS product_count
FROM products
GROUP BY product_category_name
ORDER BY product_count DESC;


-- 5. Number of distinct categories
SELECT
    COUNT(DISTINCT product_category_name) AS distinct_categories
FROM products;


-- 6. Check numeric ranges
SELECT
    MIN(product_name_lenght) AS min_name_length,
    MAX(product_name_lenght) AS max_name_length,

    MIN(product_description_lenght) AS min_description_length,
    MAX(product_description_lenght) AS max_description_length,

    MIN(product_photos_qty) AS min_photos_qty,
    MAX(product_photos_qty) AS max_photos_qty,

    MIN(product_weight_g) AS min_weight_g,
    MAX(product_weight_g) AS max_weight_g,

    MIN(product_length_cm) AS min_length_cm,
    MAX(product_length_cm) AS max_length_cm,

    MIN(product_height_cm) AS min_height_cm,
    MAX(product_height_cm) AS max_height_cm,

    MIN(product_width_cm) AS min_width_cm,
    MAX(product_width_cm) AS max_width_cm
FROM products;


-- 7. Check zero or negative physical values
SELECT
    SUM(product_weight_g <= 0) AS invalid_weight,
    SUM(product_length_cm <= 0) AS invalid_length,
    SUM(product_height_cm <= 0) AS invalid_height,
    SUM(product_width_cm <= 0) AS invalid_width
FROM products;


-- 8. Check zero / negative metadata values
SELECT
    SUM(product_name_lenght < 0) AS negative_name_length,
    SUM(product_description_lenght < 0) AS negative_description_length,
    SUM(product_photos_qty < 0) AS negative_photos_qty
FROM products;


-- 9. Check whether every category exists in category_translation
SELECT DISTINCT
    p.product_category_name
FROM products AS p
LEFT JOIN category_translation AS ct
    ON p.product_category_name = ct.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND ct.product_category_name IS NULL;
  
  
  SELECT
    SUM(product_weight_g = 0) AS zero_weight,
    SUM(product_weight_g < 0) AS negative_weight,

    SUM(product_length_cm = 0) AS zero_length,
    SUM(product_length_cm < 0) AS negative_length,

    SUM(product_height_cm = 0) AS zero_height,
    SUM(product_height_cm < 0) AS negative_height,

    SUM(product_width_cm = 0) AS zero_width,
    SUM(product_width_cm < 0) AS negative_width
FROM products;


SELECT
    product_id,
    product_category_name,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
FROM products
WHERE product_weight_g <= 0
   OR product_length_cm <= 0
   OR product_height_cm <= 0
   OR product_width_cm <= 0;
  
  SELECT
    product_category_name,
    COUNT(*) AS product_count
FROM products
WHERE product_category_name IN (
    'pc_gamer',
    'portateis_cozinha_e_preparadores_de_alimentos'
)
GROUP BY product_category_name;




-- ============================================
-- SELLERS PROFILING
-- ============================================

-- 1. Total rows + distinct seller IDs
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT seller_id) AS distinct_seller_ids
FROM sellers;


-- 2. Duplicate seller_id
SELECT
    seller_id,
    COUNT(*) AS row_count
FROM sellers
GROUP BY seller_id
HAVING COUNT(*) > 1;


-- 3. NULL / missing checks
SELECT
    SUM(seller_id IS NULL) AS null_seller_id,
    SUM(seller_zip_code_prefix IS NULL) AS null_zip_code,
    SUM(seller_city IS NULL OR TRIM(seller_city) = '') AS missing_city,
    SUM(seller_state IS NULL OR TRIM(seller_state) = '') AS missing_state
FROM sellers;


-- 4. State distribution
SELECT
    seller_state,
    COUNT(*) AS seller_count
FROM sellers
GROUP BY seller_state
ORDER BY seller_count DESC;


-- 5. Distinct states and cities
SELECT
    COUNT(DISTINCT seller_state) AS distinct_states,
    COUNT(DISTINCT seller_city) AS distinct_cities
FROM sellers;


-- 6. Check suspicious state lengths
SELECT
    seller_state,
    LENGTH(seller_state) AS state_length,
    COUNT(*) AS seller_count
FROM sellers
GROUP BY seller_state, LENGTH(seller_state)
ORDER BY seller_state;


-- 7. City length range
SELECT
    MIN(LENGTH(TRIM(seller_city))) AS min_city_length,
    MAX(LENGTH(TRIM(seller_city))) AS max_city_length
FROM sellers;


-- 8. Referential integrity:
-- Every seller_id used in order_items should exist in sellers
SELECT DISTINCT
    oi.seller_id
FROM order_items AS oi
LEFT JOIN sellers AS s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;


-- ============================================
-- CATEGORY_TRANSLATION PROFILING
-- ============================================

-- 1. Total rows + distinct Portuguese categories
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT product_category_name) AS distinct_category_names
FROM category_translation;


-- 2. Duplicate Portuguese category names
SELECT
    product_category_name,
    COUNT(*) AS row_count
FROM category_translation
GROUP BY product_category_name
HAVING COUNT(*) > 1;


-- 3. NULL / missing values
SELECT
    SUM(product_category_name IS NULL OR TRIM(product_category_name) = '')
        AS missing_category_name,

    SUM(product_category_name_english IS NULL OR TRIM(product_category_name_english) = '')
        AS missing_english_translation
FROM category_translation;


-- 4. Duplicate English translations
SELECT
    product_category_name_english,
    COUNT(*) AS row_count
FROM category_translation
GROUP BY product_category_name_english
HAVING COUNT(*) > 1;


-- 5. Categories in translation table that are not used in products
SELECT
    ct.product_category_name
FROM category_translation AS ct
LEFT JOIN products AS p
    ON ct.product_category_name = p.product_category_name
WHERE p.product_category_name IS NULL;