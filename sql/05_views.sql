USE olist_analytics;

-- ============================================================
-- OLIST E-COMMERCE DATA ANALYSIS
-- Phase 6: Analytics Views for Tableau
-- ============================================================


-- ============================================================
-- 1. ORDER SUMMARY VIEW
-- Grain: One row per order
-- Purpose:
-- Main Tableau dataset for sales KPIs, geographic analysis,
-- delivery performance, customer behavior, and time trends.
-- ============================================================

CREATE OR REPLACE VIEW vw_order_summary AS

WITH item_summary AS (
    SELECT
        order_id,
        COUNT(*) AS item_count,
        SUM(price) AS product_revenue,
        SUM(freight_value) AS freight_value,
        SUM(price + freight_value) AS total_order_value
    FROM order_items
    GROUP BY order_id
),

review_summary AS (
    SELECT
        order_id,
        AVG(review_score) AS avg_review_score
    FROM order_reviews
    GROUP BY order_id
)

SELECT
    ord.order_id,
    cust.customer_unique_id,
    cust.customer_state,

    ord.order_status,
    ord.order_purchase_timestamp,
    DATE(ord.order_purchase_timestamp) AS order_date,
    DATE_FORMAT(
        ord.order_purchase_timestamp,
        '%Y-%m'
    ) AS order_month,

    items.item_count,
    items.product_revenue,
    items.freight_value,
    items.total_order_value,

    ord.order_delivered_customer_date,
    ord.order_estimated_delivery_date,

    CASE
        WHEN ord.order_delivered_customer_date IS NULL
            THEN NULL
        WHEN ord.order_delivered_customer_date
             <= ord.order_estimated_delivery_date
            THEN 'On Time'
        ELSE 'Late'
    END AS delivery_status,

    CASE
        WHEN ord.order_delivered_customer_date IS NOT NULL
        THEN DATEDIFF(
            ord.order_delivered_customer_date,
            ord.order_estimated_delivery_date
        )
        ELSE NULL
    END AS delivery_delay_days,

    reviews.avg_review_score

FROM orders AS ord

INNER JOIN customers AS cust
    ON ord.customer_id = cust.customer_id

LEFT JOIN item_summary AS items
    ON ord.order_id = items.order_id

LEFT JOIN review_summary AS reviews
    ON ord.order_id = reviews.order_id;
    
    SELECT
    COUNT(*) AS rows_count,
    COUNT(DISTINCT order_id) AS distinct_orders
FROM vw_order_summary;





-- ============================================================
-- 2. ITEM ANALYSIS VIEW
-- Grain: One row per order item
-- Purpose:
-- Tableau dataset for product category performance,
-- seller performance, item-level revenue, and sales volume.
-- ============================================================

CREATE OR REPLACE VIEW vw_item_analysis AS

SELECT
    item.order_id,
    item.order_item_id,
    ord.order_purchase_timestamp,
    DATE(ord.order_purchase_timestamp) AS order_date,
    DATE_FORMAT(
        ord.order_purchase_timestamp,
        '%Y-%m'
    ) AS order_month,

    cust.customer_state,

    item.product_id,
    pro.product_category_name,
    cat.product_category_name_english,

    item.seller_id,
    sel.seller_state,

    item.price,
    item.freight_value,
    (item.price + item.freight_value) AS total_item_value

FROM order_items AS item

INNER JOIN orders AS ord
    ON item.order_id = ord.order_id

INNER JOIN customers AS cust
    ON ord.customer_id = cust.customer_id

INNER JOIN products AS pro
    ON item.product_id = pro.product_id

LEFT JOIN category_translation AS cat
    ON pro.product_category_name = cat.product_category_name

INNER JOIN sellers AS sel
    ON item.seller_id = sel.seller_id;
    
    



-- ============================================================
-- 3. PAYMENT ANALYSIS VIEW
-- Grain: One row per payment record
-- Purpose:
-- Tableau dataset for payment method analysis,
-- payment values, installments, and order-level payment behavior.
-- ============================================================

CREATE OR REPLACE VIEW vw_payment_analysis AS

SELECT
    pay.order_id,
    pay.payment_sequential,
    pay.payment_type,
    pay.payment_installments,
    pay.payment_value,

    ord.order_purchase_timestamp,
    DATE(ord.order_purchase_timestamp) AS order_date,
    DATE_FORMAT(
        ord.order_purchase_timestamp,
        '%Y-%m'
    ) AS order_month,

    cust.customer_unique_id,
    cust.customer_state,
    ord.order_status

FROM order_payments AS pay

INNER JOIN orders AS ord
    ON pay.order_id = ord.order_id

INNER JOIN customers AS cust
    ON ord.customer_id = cust.customer_id;