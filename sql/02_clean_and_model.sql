-- =====================================================================
-- Script  : 02_clean_and_model.sql
-- Purpose : Clean staging data and build a star schema for Power BI
-- Grain   : fact_orders = one row per ORDER ITEM (180,519 rows)
-- Dropped : customer_email/password (masked), product_description (100% NULL),
--           product_status (constant 0), order_zipcode (86% NULL),
--           duplicate columns (benefit_per_order = order_profit_per_order,
--           sales_per_customer = order_item_total, category_id = product_category_id)
-- =====================================================================
USE supply_chain_db;

-- ---------- Dimensions -----------------------------------------------
DROP TABLE IF EXISTS dim_customer;
CREATE TABLE dim_customer AS
SELECT DISTINCT customer_id,
       customer_segment,
       TRIM(customer_city) AS customer_city,
       customer_state,
       CASE WHEN customer_country = 'EE. UU.' THEN 'USA' ELSE customer_country END AS customer_country
FROM stg_orders;
ALTER TABLE dim_customer ADD PRIMARY KEY (customer_id);

DROP TABLE IF EXISTS dim_product;
CREATE TABLE dim_product AS
SELECT DISTINCT product_card_id AS product_id,
       TRIM(product_name)       AS product_name,
       product_category_id      AS category_id,
       TRIM(category_name)      AS category_name,
       product_price
FROM stg_orders;
ALTER TABLE dim_product ADD PRIMARY KEY (product_id);

DROP TABLE IF EXISTS dim_department;
CREATE TABLE dim_department AS
SELECT DISTINCT department_id, TRIM(department_name) AS department_name FROM stg_orders;
ALTER TABLE dim_department ADD PRIMARY KEY (department_id);

-- ---------- Fact table -------------------------------------------------
DROP TABLE IF EXISTS fact_orders;
CREATE TABLE fact_orders AS
SELECT
  order_item_id,
  order_id,
  customer_id,
  product_card_id                                   AS product_id,
  department_id,
  STR_TO_DATE(order_date_raw,    '%m/%d/%Y %H:%i')  AS order_date,
  STR_TO_DATE(shipping_date_raw, '%m/%d/%Y %H:%i')  AS shipping_date,
  type_payment                                      AS payment_type,
  shipping_mode,
  days_shipment_sched                               AS days_scheduled,
  days_shipping_real                                AS days_actual,
  days_shipping_real - days_shipment_sched          AS delay_days,        -- +ve = late
  delivery_status,
  late_delivery_risk                                AS is_late,
  order_status,
  CASE WHEN order_status IN ('CANCELED','SUSPECTED_FRAUD') THEN 1 ELSE 0 END AS is_cancelled_or_fraud,
  market,
  order_region,
  order_country,
  TRIM(order_city)                                  AS order_city,
  order_state,
  order_item_quantity                               AS quantity,
  order_item_product_price                          AS unit_price,
  order_item_discount                               AS discount_amount,
  order_item_discount_rate                          AS discount_rate,
  sales                                             AS gross_sales,        -- before discount
  order_item_total                                  AS net_sales,          -- after discount
  order_profit_per_order                            AS profit,
  order_item_profit_ratio                           AS profit_ratio
FROM stg_orders;
ALTER TABLE fact_orders ADD PRIMARY KEY (order_item_id);
CREATE INDEX ix_fact_date     ON fact_orders(order_date);
CREATE INDEX ix_fact_customer ON fact_orders(customer_id);
CREATE INDEX ix_fact_product  ON fact_orders(product_id);

-- ---------- Date dimension (2015-01-01 .. 2018-01-31) ---------------------
DROP TABLE IF EXISTS dim_date;
CREATE TABLE dim_date (date_key DATE PRIMARY KEY, year INT, quarter INT, month_no INT,
                       month_name VARCHAR(10), ym CHAR(7), day_name VARCHAR(10), is_weekend TINYINT);
INSERT INTO dim_date
WITH RECURSIVE d AS (SELECT DATE('2015-01-01') AS dt UNION ALL SELECT dt + INTERVAL 1 DAY FROM d WHERE dt < '2018-01-31')
SELECT dt, YEAR(dt), QUARTER(dt), MONTH(dt), MONTHNAME(dt), DATE_FORMAT(dt,'%Y-%m'), DAYNAME(dt),
       CASE WHEN DAYOFWEEK(dt) IN (1,7) THEN 1 ELSE 0 END
FROM d;

-- ---------- Validation (all should pass) -------------------------------------
SELECT 'fact rows = 180519'            AS test, COUNT(*) = 180519                         AS passed FROM fact_orders
UNION ALL SELECT 'no NULL order dates', SUM(order_date IS NULL) = 0                       FROM fact_orders
UNION ALL SELECT 'no orphan customers', COUNT(*) = 0 FROM fact_orders f LEFT JOIN dim_customer c USING (customer_id) WHERE c.customer_id IS NULL
UNION ALL SELECT 'no orphan products',  COUNT(*) = 0 FROM fact_orders f LEFT JOIN dim_product  p USING (product_id)  WHERE p.product_id  IS NULL
UNION ALL SELECT 'is_late matches status', SUM((delivery_status='Late delivery') <> is_late) = 0 FROM fact_orders;

-- ---------- Views for Power BI -----------------------------------------------
-- Delivery performance excludes cancelled / fraud orders (they have no real delivery).
CREATE OR REPLACE VIEW vw_delivered_orders AS
SELECT * FROM fact_orders WHERE is_cancelled_or_fraud = 0;

SET SESSION cte_max_recursion_depth = 5000;
SELECT COUNT(*) AS delivered_items FROM vw_delivered_orders;
