# Business Insights

This analysis highlights the main business patterns identified from the Olist e-commerce dataset using SQL and Tableau.

## 1. Revenue Trend Over Time

Revenue showed an overall upward trend, with clear growth throughout 2017.

A decline appears toward the end of 2018; however, this should be interpreted cautiously because the dataset contains only partial data for the final period of 2018.

The beginning of the dataset in 2016 is also incomplete, so comparisons involving the first and last periods should be treated carefully.

---

## 2. Product Category Performance

Health & Beauty generated the highest product revenue among the analyzed categories.

High revenue was not necessarily associated with the highest number of items sold. For example, Health & Beauty generated more revenue than Bed, Bath & Table despite having fewer items sold.

The difference was supported by product pricing:

- Health & Beauty average item price: approximately R$130.16
- Bed, Bath & Table average item price: approximately R$93.30

This indicates that both sales volume and product price contribute to category revenue performance.

---

## 3. Geographic Revenue Performance

São Paulo (SP) generated the highest total revenue and also had the largest order volume.

However, the state with the highest total revenue was not necessarily the state with the highest Average Order Value (AOV).

A state can generate high revenue because of a large number of orders even when its average order value is relatively moderate. Conversely, a state may have a high AOV but still generate lower total revenue because of lower transaction volume.

Therefore, geographic performance should be evaluated using both order volume and customer spending per order.

---

## 4. Delivery Performance and Customer Satisfaction

Delivery performance showed a strong relationship with customer review scores.

- Orders delivered on time had an average review score of approximately 4.29.
- Late orders had an average review score of approximately 2.57.

Late deliveries were therefore associated with substantially lower customer satisfaction.

This result shows a clear relationship between delivery performance and review scores, although the analysis does not by itself prove that delivery delays were the sole cause of lower ratings.

---

## 5. Seller Performance

High seller revenue was not driven by sales volume alone.

The highest-revenue seller generated approximately R$229K from 1,132 orders, while another seller generated approximately R$223K from only 358 orders.

Although their revenues were relatively close, the second seller generated much more revenue per order.

This demonstrates that seller performance depends not only on the number of transactions but also on the average value of those transactions.

---

## 6. Payment Behavior

Credit cards were by far the dominant payment method.

Credit card payments accounted for approximately:

- 76,795 payment records
- 76,505 orders
- R$12.54M in payment value

Boleto was the second most important payment method, with approximately R$2.87M in payment value.

The number of payment records was not always equal to the number of orders because an individual order could contain multiple payment records.

This pattern was particularly noticeable for voucher payments, where 5,775 payment records represented only 3,866 orders.

---

## 7. Repeat Customer Behavior

Most customers in the dataset purchased only once.

Out of approximately 96,096 unique customers, only 2,997 placed more than one valid order, resulting in a repeat-customer rate of approximately 3.12%.

The highest observed number of orders placed by a single customer was 17.

This indicates that repeat purchasing was relatively uncommon within the available dataset.

---

## Overall Findings

The analysis suggests that Olist's performance was influenced by several different factors:

- Revenue growth was strong during the main complete period of the dataset.
- Product revenue depended on both sales volume and average product price.
- São Paulo represented the largest geographic market by order volume and revenue.
- Delivery delays were associated with considerably lower customer ratings.
- Seller revenue could be driven by either high transaction volume or high-value orders.
- Credit cards dominated customer payment behavior.
- Repeat purchasing represented a relatively small proportion of customers.

These findings provide the foundation for business recommendations and for the final Tableau dashboard.