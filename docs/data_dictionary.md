## Dataset Overview

This project uses the Brazilian E-Commerce Public Dataset by Olist.

The dataset is relational and contains information about customers, orders, order items, products, sellers, payments, and reviews.

### Tables

#### `olist_customers_dataset`

Each row represents a customer record associated with an order.

Main fields:

- `customer_id`: Unique identifier used to link a customer record to an order.
- `customer_unique_id`: Identifier used to track the same real customer across multiple orders.
- `customer_zip_code_prefix`: Customer postal code prefix.
- `customer_city`: Customer city.
- `customer_state`: Customer state.

Primary Key:

- `customer_id`

Important Note:

The same real customer can appear with different `customer_id` values across different orders.  
For customer-level analysis, `customer_unique_id` should be used.

---

#### `olist_orders_dataset`

Each row represents one order.

Main fields:

- `order_id`: Unique order identifier.
- `customer_id`: Links the order to the customer table.
- `order_status`: Current order status.
- `order_purchase_timestamp`: Date and time when the order was placed.
- `order_approved_at`: Date and time when the order was approved.
- `order_delivered_carrier_date`: Date when the order was handed to the carrier.
- `order_delivered_customer_date`: Actual delivery date.
- `order_estimated_delivery_date`: Estimated delivery date.

Primary Key:

- `order_id`

Foreign Key:

- `customer_id`

Relationship:

- One customer record can be linked to one order through `customer_id`.
- One order can contain multiple order items.

---

#### `olist_order_items_dataset`

Each row represents one item inside an order.

An order can contain multiple products, so the same `order_id` can appear multiple times.

Main fields:

- `order_id`: Order identifier.
- `order_item_id`: Sequential item number within the order.
- `product_id`: Product identifier.
- `seller_id`: Seller identifier.
- `shipping_limit_date`: Shipping deadline.
- `price`: Product price.
- `freight_value`: Shipping cost.

Composite Primary Key:

- `order_id`
- `order_item_id`

Foreign Keys:

- `order_id`
- `product_id`
- `seller_id`

Relationship:

- One order can have many order items.
- One product can appear in many order items.
- One seller can sell many order items.

---

#### `olist_order_payments_dataset`

Each row represents a payment record associated with an order.

The same order can have multiple payment records, for example when multiple payment methods are used.

Main fields:

- `order_id`: Order identifier.
- `payment_sequential`: Sequence number of the payment record.
- `payment_type`: Payment method.
- `payment_installments`: Number of installments.
- `payment_value`: Payment amount.

Foreign Key:

- `order_id`



---

#### `olist_order_reviews_dataset`

Each row represents a review record associated with an order.

Main fields:

- `review_id`: Review identifier.
- `order_id`: Order identifier.
- `review_score`: Customer rating from 1 to 5.
- `review_comment_title`: Review title.
- `review_comment_message`: Review text.
- `review_creation_date`: Review creation date.
- `review_answer_timestamp`: Review response timestamp.

Primary Key:

- `review_id`

Foreign Key:

- `order_id`

Relationship:

- An order can have one or more review records in the dataset.

---

#### `olist_products_dataset`

Each row represents one product.

Main fields:

- `product_id`: Unique product identifier.
- `product_category_name`: Product category name in Portuguese.
- `product_name_lenght`: Product name length.
- `product_description_lenght`: Product description length.
- `product_photos_qty`: Number of product photos.
- `product_weight_g`: Product weight.
- `product_length_cm`: Product length.
- `product_height_cm`: Product height.
- `product_width_cm`: Product width.

Primary Key:

- `product_id`

Relationship:

- One product can appear in many order items.
- `product_category_name` can be linked to the category translation table.

---

#### `olist_sellers_dataset`

Each row represents one seller.

Main fields:

- `seller_id`: Unique seller identifier.
- `seller_zip_code_prefix`: Seller postal code prefix.
- `seller_city`: Seller city.
- `seller_state`: Seller state.

Primary Key:

- `seller_id`

Relationship:

- One seller can be associated with many order items.

---

#### `product_category_name_translation`

Each row represents the English translation of one product category.

Main fields:

- `product_category_name`: Original Portuguese category name.
- `product_category_name_english`: English category name.

Primary Key:

- `product_category_name`

Relationship:

- One translated category can be associated with many products.

---

## Main Relationships

```text
customers
    |
    | customer_id
    v
orders
    |
    | order_id
    |
    +------ order_items ------ products ------ category_translation
    |             |
    |             +---------- sellers
    |
    +------ payments
    |
    +------ reviews