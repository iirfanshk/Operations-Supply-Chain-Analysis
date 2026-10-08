-- =====================================================================
-- Project : Operations & Supply Chain Analysis (DataCo)
-- Script  : 01_create_and_load.sql   (MySQL 8.x)
-- Purpose : Create database + raw staging table and load the Kaggle CSV
-- =====================================================================
CREATE DATABASE IF NOT EXISTS supply_chain_db CHARACTER SET utf8mb4;
USE supply_chain_db;

DROP TABLE IF EXISTS stg_orders;
CREATE TABLE stg_orders (          -- column ORDER must match the CSV header
  type_payment            VARCHAR(20),
  days_shipping_real      INT,
  days_shipment_sched     INT,
  benefit_per_order       DECIMAL(12,2),
  sales_per_customer      DECIMAL(12,2),
  delivery_status         VARCHAR(30),
  late_delivery_risk      TINYINT,
  category_id             INT,
  category_name           VARCHAR(60),
  customer_city           VARCHAR(60),
  customer_country        VARCHAR(30),
  customer_email          VARCHAR(30),
  customer_fname          VARCHAR(60),
  customer_id             INT,
  customer_lname          VARCHAR(60),
  customer_password       VARCHAR(30),
  customer_segment        VARCHAR(20),
  customer_state          VARCHAR(10),
  customer_street         VARCHAR(100),
  customer_zipcode        VARCHAR(15),
  department_id           INT,
  department_name         VARCHAR(40),
  latitude                DECIMAL(10,6),
  longitude               DECIMAL(10,6),
  market                  VARCHAR(20),
  order_city              VARCHAR(80),
  order_country           VARCHAR(80),
  order_customer_id       INT,
  order_date_raw          VARCHAR(25),
  order_id                INT,
  order_item_cardprod_id  INT,
  order_item_discount     DECIMAL(10,2),
  order_item_discount_rate DECIMAL(5,2),
  order_item_id           INT,
  order_item_product_price DECIMAL(10,2),
  order_item_profit_ratio DECIMAL(6,2),
  order_item_quantity     INT,
  sales                   DECIMAL(10,2),
  order_item_total        DECIMAL(12,2),
  order_profit_per_order  DECIMAL(12,2),
  order_region            VARCHAR(30),
  order_state             VARCHAR(80),
  order_status            VARCHAR(20),
  order_zipcode           VARCHAR(15),
  product_card_id         INT,
  product_category_id     INT,
  product_description     VARCHAR(10),
  product_image           VARCHAR(200),
  product_name            VARCHAR(80),
  product_price           DECIMAL(10,2),
  product_status          TINYINT,
  shipping_date_raw       VARCHAR(25),
  shipping_mode           VARCHAR(20)
);

-- ---- OPTION A (fast): LOAD DATA --------------------------------------
-- 1) In MySQL Workbench: Connection > Advanced > "Others" box, add:  OPT_LOCAL_INFILE=1
-- 2) Run:  SET GLOBAL local_infile = 1;
-- 3) Edit the path below (use forward slashes), then run:
LOAD DATA LOCAL INFILE 'C:/Users/123/OneDrive/Desktop/Operations-Supply-Chain-Analysis/data/DataCoSupplyChainDataset.csv'
INTO TABLE stg_orders
CHARACTER SET latin1
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

-- ---- OPTION B: Workbench > right-click stg_orders > Table Data Import Wizard
--      (slower, but no settings needed; choose the same CSV, encoding latin1)

-- ---- Sanity checks: expect 180519 rows, 65752 distinct orders ---------
SELECT COUNT(*) AS row_count, COUNT(DISTINCT order_id) AS orders FROM stg_orders;
   TRUNCATE TABLE stg_orders;

   SELECT ROUND(SUM(sales),2) AS total_sales,
          ROUND(SUM(order_profit_per_order),2) AS total_profit,
          MIN(STR_TO_DATE(order_date_raw,'%m/%d/%Y %H:%i')) AS first_order,
          MAX(STR_TO_DATE(order_date_raw,'%m/%d/%Y %H:%i')) AS last_order
   FROM stg_orders;