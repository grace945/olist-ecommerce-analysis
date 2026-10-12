


-- ============================================================
-- OLIST E-COMMERCE DATA ANALYSIS
-- Phase 4: Business Analysis
-- Database: olist_analytics
--
-- Purpose:
-- Answer key business questions related to sales trends,
-- product categories, customer geography, delivery performance,
-- seller performance, payments, and customer retention.
-- ============================================================

USE olist_analytics;


-- ============================================================
-- 1. SALES PERFORMANCE OVER TIME
-- Business Question:
-- How did order volume and revenue change over time?
-- ============================================================


-- 1.1 Monthly Order Volume
SELECT
    DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS order_month,
    COUNT(*) AS orders_per_month
FROM orders
GROUP BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m')
ORDER BY order_month;


-- 1.2 Monthly Revenue
-- Product revenue excludes freight.
-- Total order value includes product price + freight value.

SELECT
    DATE_FORMAT(ord.order_purchase_timestamp, '%Y-%m') AS order_month,
    SUM(item.price) AS product_revenue,
    SUM(item.freight_value) AS freight_revenue,
    SUM(item.price + item.freight_value) AS total_order_value
FROM orders AS ord
INNER JOIN order_items AS item
    ON ord.order_id = item.order_id
GROUP BY DATE_FORMAT(ord.order_purchase_timestamp, '%Y-%m')
ORDER BY order_month;


-- 1.3 Monthly Average Order Value (AOV)
-- Orders are first aggregated to one row per order to avoid
-- calculating the average item price instead of order value.

WITH order_revenue AS (
    SELECT
        ord.order_id,
        DATE_FORMAT(ord.order_purchase_timestamp, '%Y-%m') AS order_month,
        SUM(item.price) AS order_product_revenue
    FROM orders AS ord
    INNER JOIN order_items AS item
        ON ord.order_id = item.order_id
    GROUP BY
        ord.order_id,
        DATE_FORMAT(ord.order_purchase_timestamp, '%Y-%m')
)

SELECT
    order_month,
    ROUND(AVG(order_product_revenue), 2) AS avg_order_value
FROM order_revenue
GROUP BY order_month
ORDER BY order_month;



-- ============================================================
-- 2. PRODUCT CATEGORY PERFORMANCE
-- Business Question:
-- Which product categories generate the most revenue?
-- ============================================================


-- 2.1 Top 10 Categories by Product Revenue

SELECT
    pro.product_category_name,
    cat.product_category_name_english,
    COUNT(*) AS number_of_items_sold,
    ROUND(SUM(item.price), 2) AS revenue,
    COUNT(DISTINCT item.order_id) AS number_of_distinct_orders
FROM products AS pro
INNER JOIN category_translation AS cat
    ON pro.product_category_name = cat.product_category_name
INNER JOIN order_items AS item
    ON pro.product_id = item.product_id
GROUP BY
    pro.product_category_name,
    cat.product_category_name_english
ORDER BY revenue DESC
LIMIT 10;


-- 2.2 Supporting Analysis:
-- Compare average item prices between Health & Beauty
-- and Bed, Bath & Table.

SELECT
    pro.product_category_name,
    cat.product_category_name_english,
    COUNT(*) AS number_of_items_sold,
    ROUND(AVG(item.price), 2) AS avg_item_price,
    COUNT(DISTINCT item.order_id) AS number_of_distinct_orders
FROM products AS pro
INNER JOIN category_translation AS cat
    ON pro.product_category_name = cat.product_category_name
INNER JOIN order_items AS item
    ON pro.product_id = item.product_id
WHERE cat.product_category_name_english IN (
    'health_beauty',
    'bed_bath_table'
)
GROUP BY
    pro.product_category_name,
    cat.product_category_name_english
ORDER BY avg_item_price DESC;



-- ============================================================
-- 3. GEOGRAPHIC CUSTOMER PERFORMANCE
-- Business Question:
-- Which customer states generate the highest order volume
-- and product revenue?
-- ============================================================

SELECT
    cust.customer_state,
    COUNT(DISTINCT ord.order_id) AS number_of_distinct_orders,
    ROUND(SUM(item.price), 2) AS product_revenue,
    ROUND(
        SUM(item.price) / COUNT(DISTINCT ord.order_id),
        2
    ) AS average_order_value
FROM customers AS cust
INNER JOIN orders AS ord
    ON ord.customer_id = cust.customer_id
INNER JOIN order_items AS item
    ON ord.order_id = item.order_id
GROUP BY cust.customer_state
ORDER BY product_revenue DESC;



-- ============================================================
-- 4. DELIVERY PERFORMANCE AND CUSTOMER SATISFACTION
-- Business Question:
-- Do late deliveries receive lower review scores
-- than on-time deliveries?
--
-- Grain:
-- Reviews are first aggregated to one row per order because
-- some orders contain more than one review record.
-- ============================================================

WITH review_per_order AS (
    SELECT
        order_id,
        AVG(review_score) AS avg_review_score
    FROM order_reviews
    GROUP BY order_id
),

delivery_analysis AS (
    SELECT
        ord.order_id,

        CASE
            WHEN ord.order_delivered_customer_date
                 <= ord.order_estimated_delivery_date
                THEN 'On Time'
            ELSE 'Late'
        END AS delivery_status,

        rev.avg_review_score,

        DATEDIFF(
            ord.order_delivered_customer_date,
            ord.order_estimated_delivery_date
        ) AS delivery_delay_days

    FROM orders AS ord
    INNER JOIN review_per_order AS rev
        ON ord.order_id = rev.order_id

    WHERE ord.order_delivered_customer_date IS NOT NULL
      AND ord.order_estimated_delivery_date IS NOT NULL
)

SELECT
    delivery_status,
    COUNT(*) AS orders_count,
    ROUND(AVG(avg_review_score), 2) AS avg_review_score,
    ROUND(AVG(delivery_delay_days), 2) AS avg_delivery_delay_days
FROM delivery_analysis
GROUP BY delivery_status
ORDER BY delivery_status;



-- ============================================================
-- 5. SELLER PERFORMANCE
-- Business Question:
-- Which sellers generate the highest product revenue?
-- ============================================================

SELECT
    sel.seller_id,
    COUNT(*) AS number_of_items_sold,
    COUNT(DISTINCT item.order_id) AS number_of_distinct_orders,
    ROUND(SUM(item.price), 2) AS revenue
FROM sellers AS sel
INNER JOIN order_items AS item
    ON sel.seller_id = item.seller_id
GROUP BY sel.seller_id
ORDER BY revenue DESC
LIMIT 10;



-- ============================================================
-- 6. PAYMENT BEHAVIOR
-- Business Question:
-- Which payment methods are used most frequently,
-- and how do payment value and installments differ by method?
--
-- Note:
-- One order may contain multiple payment records.
-- ============================================================

SELECT
    payment_type,
    COUNT(*) AS payment_records,
    COUNT(DISTINCT order_id) AS distinct_orders,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(AVG(payment_value), 2) AS avg_payment_value,
    ROUND(AVG(payment_installments), 2) AS avg_installments
FROM order_payments
GROUP BY payment_type
ORDER BY distinct_orders DESC;



-- ============================================================
-- 7. CUSTOMER RETENTION
-- Business Question:
-- How many customers purchased more than once?
--
-- customer_unique_id is used instead of customer_id because
-- customer_unique_id identifies the same real customer across
-- multiple orders.
-- ============================================================

WITH customer_orders AS (
    SELECT
        cust.customer_unique_id,
        COUNT(DISTINCT ord.order_id) AS order_count
    FROM customers AS cust
    INNER JOIN orders AS ord
        ON cust.customer_id = ord.customer_id
    GROUP BY cust.customer_unique_id
)

SELECT
    COUNT(*) AS total_customers,
    SUM(order_count > 1) AS repeat_customers,
    ROUND(
        100.0 * SUM(order_count > 1) / COUNT(*),
        2
    ) AS repeat_customer_percentage,
    MAX(order_count) AS max_orders_by_customer
FROM customer_orders;