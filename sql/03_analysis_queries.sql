-- =====================================================================
-- Script  : 03_analysis_queries.sql
-- Purpose : Business questions answered in SQL (feeds dashboard design)
-- =====================================================================
USE supply_chain_db;

-- Q1. Headline KPIs
SELECT COUNT(DISTINCT order_id)                         AS total_orders,
       ROUND(SUM(net_sales),0)                          AS net_sales,
       ROUND(SUM(profit),0)                             AS total_profit,
       ROUND(SUM(profit)/SUM(net_sales)*100,2)          AS profit_margin_pct,
       ROUND(AVG(is_late)*100,2)                        AS late_delivery_pct
FROM vw_delivered_orders;

-- Q2. Yearly sales & profit with YoY growth (2018 is only January -> exclude)
WITH y AS (SELECT YEAR(order_date) yr, SUM(net_sales) sales, SUM(profit) profit
           FROM fact_orders WHERE YEAR(order_date) < 2018 GROUP BY 1)
SELECT yr, ROUND(sales) sales, ROUND(profit) profit,
       ROUND((sales - LAG(sales) OVER (ORDER BY yr)) / LAG(sales) OVER (ORDER BY yr) * 100, 2) AS yoy_sales_pct
FROM y;

-- Q3. Late-delivery rate by shipping mode (scheduled vs actual days)
SELECT shipping_mode,
       COUNT(*)                         AS items,
       ROUND(AVG(days_scheduled),2)     AS avg_scheduled_days,
       ROUND(AVG(days_actual),2)        AS avg_actual_days,
       ROUND(AVG(is_late)*100,2)        AS late_pct
FROM vw_delivered_orders
GROUP BY shipping_mode
ORDER BY late_pct DESC;

-- Q4. Late-delivery rate by market and region
SELECT market, order_region, COUNT(*) items, ROUND(AVG(is_late)*100,2) late_pct
FROM vw_delivered_orders
GROUP BY market, order_region
ORDER BY late_pct DESC;

-- Q5. Top 10 categories by net sales + profit margin
SELECT p.category_name, ROUND(SUM(f.net_sales)) net_sales, ROUND(SUM(f.profit)) profit,
       ROUND(SUM(f.profit)/SUM(f.net_sales)*100,2) margin_pct,
       RANK() OVER (ORDER BY SUM(f.net_sales) DESC) AS sales_rank
FROM fact_orders f JOIN dim_product p USING (product_id)
GROUP BY p.category_name
ORDER BY net_sales DESC LIMIT 10;

-- Q6. Loss-making products (profit < 0) - how much money is being lost?
SELECT p.product_name, COUNT(*) loss_items, ROUND(SUM(f.profit)) total_loss
FROM fact_orders f JOIN dim_product p USING (product_id)
WHERE f.profit < 0
GROUP BY p.product_name
ORDER BY total_loss ASC LIMIT 10;

-- Q7. Does discount depth hurt profit?
SELECT discount_rate, COUNT(*) items, ROUND(AVG(profit),2) avg_profit, ROUND(AVG(profit_ratio),3) avg_profit_ratio
FROM fact_orders GROUP BY discount_rate ORDER BY discount_rate;

-- Q8. Monthly sales trend with 3-month moving average
WITH m AS (SELECT DATE_FORMAT(order_date,'%Y-%m') ym, SUM(net_sales) sales
           FROM fact_orders WHERE order_date < '2018-01-01' GROUP BY 1)
SELECT ym, ROUND(sales) sales,
       ROUND(AVG(sales) OVER (ORDER BY ym ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)) AS moving_avg_3m
FROM m;

-- Q9. Customer segment value + top 10 customers by lifetime profit
SELECT c.customer_segment, COUNT(DISTINCT f.customer_id) customers,
       ROUND(SUM(f.net_sales)/COUNT(DISTINCT f.customer_id)) sales_per_customer
FROM fact_orders f JOIN dim_customer c USING (customer_id) GROUP BY c.customer_segment;

SELECT customer_id, ROUND(SUM(net_sales)) sales, ROUND(SUM(profit)) profit
FROM fact_orders GROUP BY customer_id ORDER BY profit DESC LIMIT 10;

-- Q10. Order status mix + fraud exposure
SELECT order_status, COUNT(DISTINCT order_id) orders,
       ROUND(COUNT(*)/SUM(COUNT(*)) OVER ()*100,2) pct_of_items, ROUND(SUM(net_sales)) net_sales
FROM fact_orders GROUP BY order_status ORDER BY orders DESC;
