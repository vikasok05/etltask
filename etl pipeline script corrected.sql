BEGIN;

CREATE SCHEMA IF NOT EXISTS stage;

DROP TABLE IF EXISTS stage.superstore;
DROP TABLE IF EXISTS stage.superstore_sec;

CREATE TABLE stage.superstore (
    row_id INTEGER,
    order_id VARCHAR(50),
    order_date DATE,
    ship_date DATE,
    ship_mode VARCHAR(50),
    customer_id VARCHAR(50),
    customer_name VARCHAR(100),
    segment VARCHAR(50),
    country VARCHAR(50),
    city VARCHAR(100),
    statee VARCHAR(50),
    postal_code VARCHAR(20),
    region VARCHAR(50),
    product_id VARCHAR(50),
    category VARCHAR(50),
    sub_category VARCHAR(50),
    product_name VARCHAR(200),
    sales NUMERIC(12,3),
    quantity INTEGER,
    discount NUMERIC(5,2),
    profit NUMERIC(12,2)
);

CREATE TABLE stage.superstore_sec (LIKE stage.superstore);

COMMIT;

SET datestyle = 'MDY';

COPY stage.superstore
FROM 'D:/Inn/BI task/Sample - Superstore 9000.csv'
WITH (FORMAT csv, HEADER true);

COPY stage.superstore_sec
FROM 'D:/Inn/BI task/Sample - Superstore 8990-9994.csv'
WITH (FORMAT csv, HEADER true);

BEGIN;

CREATE SCHEMA IF NOT EXISTS core;

CREATE TABLE IF NOT EXISTS core.customers (
    customer_pk BIGSERIAL PRIMARY KEY,
    customer_id VARCHAR(50),
    customer_name VARCHAR(100),
    segment VARCHAR(50),
    valid_from DATE,
    valid_to DATE,
    is_current BOOLEAN,
    CONSTRAINT unique_customer UNIQUE (customer_id, customer_name, segment, valid_from)
);

INSERT INTO core.customers (
    customer_id,
    customer_name,
    segment,
    valid_from,
    valid_to,
    is_current
)
SELECT DISTINCT
    customer_id,
    customer_name,
    segment,
    CURRENT_DATE,
    DATE '3000-12-31',
    TRUE
FROM stage.superstore;

CREATE TABLE IF NOT EXISTS core.products (
    product_pk BIGSERIAL PRIMARY KEY,
    product_id VARCHAR(50),
    category VARCHAR(50),
    sub_category VARCHAR(50),
    product_name VARCHAR(200),
    valid_from DATE,
    valid_to DATE,
    is_current BOOLEAN,
	CONSTRAINT unique_product UNIQUE(product_id, category, sub_category, product_name)
);

INSERT INTO core.products (
    product_id,
    category,
    sub_category,
    product_name,
    valid_from,
    valid_to,
    is_current
)
SELECT DISTINCT
    product_id,
    category,
    sub_category,
    product_name,
    CURRENT_DATE,
    DATE '3000-12-31',
    TRUE
FROM stage.superstore;

CREATE TABLE IF NOT EXISTS core.locations (
    location_pk BIGSERIAL PRIMARY KEY,
    country VARCHAR(50),
    city VARCHAR(100),
    statee VARCHAR(50),
    postal_code VARCHAR(20),
    region VARCHAR(50),
    CONSTRAINT unique_location UNIQUE (country, city, statee, postal_code, region)
);

INSERT INTO core.locations (
    country,
    city,
    statee,
    postal_code,
    region
)
SELECT DISTINCT
    country,
    city,
    statee,
    postal_code,
    region
FROM stage.superstore;

CREATE TABLE IF NOT EXISTS core.orders (
    order_pk BIGSERIAL PRIMARY KEY,
    order_id VARCHAR(50),
    order_date DATE,
    ship_date DATE,
    ship_mode VARCHAR(50),
    sales NUMERIC(12,3),
    quantity INTEGER,
    discount NUMERIC(5,2),
    profit NUMERIC(12,2),
    customer_id BIGINT REFERENCES core.customers(customer_pk),
    product_id BIGINT REFERENCES core.products(product_pk),
    location_id BIGINT REFERENCES core.locations(location_pk),
	
    CONSTRAINT fk_customer FOREIGN KEY (customer_id) REFERENCES core.customers(customer_pk),
	CONSTRAINT fk_product FOREIGN KEY (product_id) REFERENCES core.products(product_pk),
	CONSTRAINT fk_location FOREIGN KEY (location_id) REFERENCES core.locations(location_pk),

	CONSTRAINT unique_order UNIQUE (order_id, order_date, ship_date, ship_mode, sales, quantity, discount, profit, customer_id, location_id, product_id)
);

INSERT INTO core.orders (
    order_id,
    order_date,
    ship_date,
    ship_mode,
    sales,
    quantity,
    discount,
    profit,
    customer_id,
    product_id,
    location_id
)
SELECT DISTINCT
    s.order_id,
    s.order_date,
    s.ship_date,
    s.ship_mode,
    s.sales,
    s.quantity,
    s.discount,
    s.profit,
    c.customer_pk,
    p.product_pk,
    l.location_pk
FROM stage.superstore s
JOIN core.customers c
    ON s.customer_id = c.customer_id AND c.is_current
JOIN core.products p
    ON s.product_id = p.product_id AND p.is_current
JOIN core.locations l
    ON s.country = l.country
   AND s.city = l.city
   AND s.statee = l.statee
   AND s.postal_code = l.postal_code
   AND s.region = l.region;

COMMIT;

BEGIN;

UPDATE core.customers c
SET customer_name = s.customer_name
FROM stage.superstore_sec s
WHERE c.customer_id = s.customer_id
  AND c.is_current
  AND c.customer_name IS DISTINCT FROM s.customer_name;

COMMIT;

BEGIN;

UPDATE core.customers c
SET valid_to = CURRENT_DATE - 1,
    is_current = FALSE
FROM stage.superstore_sec s
WHERE c.customer_id = s.customer_id
  AND c.is_current
  AND c.segment IS DISTINCT FROM s.segment;

INSERT INTO core.customers (
    customer_id,
    customer_name,
    segment,
    valid_from,
    valid_to,
    is_current
)
SELECT DISTINCT
    s.customer_id,
    s.customer_name,
    s.segment,
    CURRENT_DATE,
    DATE '9999-12-31',
    TRUE
FROM stage.superstore_sec s
LEFT JOIN core.customers c
    ON s.customer_id = c.customer_id AND c.is_current
WHERE c.customer_id IS NULL
   OR c.segment IS DISTINCT FROM s.segment
ON CONFLICT ON CONSTRAINT unique_customer DO NOTHING;

COMMIT;

BEGIN;

UPDATE core.products p
SET valid_to = CURRENT_DATE - 1,
    is_current = FALSE
FROM stage.superstore_sec s
WHERE p.product_id = s.product_id
  AND p.is_current
  AND (
        p.category IS DISTINCT FROM s.category OR
        p.sub_category IS DISTINCT FROM s.sub_category OR
        p.product_name IS DISTINCT FROM s.product_name
      );

INSERT INTO core.products (
    product_id,
    category,
    sub_category,
    product_name,
    valid_from,
    valid_to,
    is_current
)
SELECT DISTINCT
    s.product_id,
    s.category,
    s.sub_category,
    s.product_name,
    CURRENT_DATE,
    DATE '9999-12-31',
    TRUE
FROM stage.superstore_sec s
LEFT JOIN core.products p
    ON s.product_id = p.product_id AND p.is_current
WHERE p.product_id IS NULL
   OR (
        p.category IS DISTINCT FROM s.category OR
        p.sub_category IS DISTINCT FROM s.sub_category OR
        p.product_name IS DISTINCT FROM s.product_name
     )
ON CONFLICT ON CONSTRAINT unique_product DO NOTHING;

COMMIT;

BEGIN;

INSERT INTO core.orders (
    order_id,
    order_date,
    ship_date,
    ship_mode,
    sales,
    quantity,
    discount,
    profit,
    customer_id,
    product_id,
    location_id
)
SELECT
    s.order_id,
    s.order_date,
    s.ship_date,
    s.ship_mode,
    s.sales,
    s.quantity,
    s.discount,
    s.profit,
    c.customer_pk,
    p.product_pk,
    l.location_pk
FROM stage.superstore_sec s
JOIN core.customers c ON s.customer_id = c.customer_id AND c.is_current
JOIN core.products p ON s.product_id = p.product_id AND p.is_current
JOIN core.locations l
 ON s.country = l.country
AND s.city = l.city
AND s.statee = l.statee
AND s.postal_code = l.postal_code
AND s.region = l.region
ON CONFLICT ON CONSTRAINT unique_order DO NOTHING;

COMMIT;

BEGIN;

CREATE SCHEMA IF NOT EXISTS mart;

CREATE TABLE IF NOT EXISTS mart.dim_customer (
    customer_sk BIGSERIAL PRIMARY KEY,
    customer_pk BIGINT,
    customer_id VARCHAR(50),
    customer_name VARCHAR(100),
    segment VARCHAR(50),
    valid_from DATE,
    valid_to DATE,
    is_current BOOLEAN
);

TRUNCATE mart.dim_customer;

INSERT INTO mart.dim_customer (
    customer_pk,
    customer_id,
    customer_name,
    segment,
    valid_from,
    valid_to,
    is_current
)
SELECT
    customer_pk,
    customer_id,
    customer_name,
    segment,
    valid_from,
    valid_to,
    is_current
FROM core.customers;

CREATE TABLE IF NOT EXISTS mart.dim_product (
    product_sk BIGSERIAL PRIMARY KEY,
    product_pk BIGINT,
    product_id VARCHAR(50),
    category VARCHAR(50),
    sub_category VARCHAR(50),
    product_name VARCHAR(200),
    valid_from DATE,
    valid_to DATE,
    is_current BOOLEAN
);

TRUNCATE mart.dim_product;

INSERT INTO mart.dim_product (
    product_pk,
    product_id,
    category,
    sub_category,
    product_name,
    valid_from,
    valid_to,
    is_current
)
SELECT
    product_pk,
    product_id,
    category,
    sub_category,
    product_name,
    valid_from,
    valid_to,
    is_current
FROM core.products;

CREATE TABLE IF NOT EXISTS mart.dim_location (
    location_sk BIGSERIAL PRIMARY KEY,
    location_pk BIGINT,
    country VARCHAR(50),
    city VARCHAR(100),
    statee VARCHAR(50),
    postal_code VARCHAR(20),
    region VARCHAR(50)
);

TRUNCATE mart.dim_location;

INSERT INTO mart.dim_location (
    location_pk,
    country,
    city,
    statee,
    postal_code,
    region
)
SELECT
    location_pk,
    country,
    city,
    statee,
    postal_code,
    region
FROM core.locations;

CREATE TABLE IF NOT EXISTS mart.fact_sales (
    order_sk BIGSERIAL PRIMARY KEY,
    order_id VARCHAR(50),
    customer_sk BIGINT,
    product_sk BIGINT,
    location_sk BIGINT,
    sales NUMERIC(12,3),
    quantity INTEGER,
    discount NUMERIC(5,2),
    profit NUMERIC(12,2),
    order_date DATE
);

TRUNCATE mart.fact_sales;

INSERT INTO mart.fact_sales (
    order_id,
    customer_sk,
    product_sk,
    location_sk,
    sales,
    quantity,
    discount,
    profit,
    order_date
)
SELECT
    o.order_id,
    dc.customer_sk,
    dp.product_sk,
    dl.location_sk,
    o.sales,
    o.quantity,
    o.discount,
    o.profit,
    o.order_date
FROM core.orders o
JOIN mart.dim_customer dc
    ON o.customer_id = dc.customer_pk AND dc.is_current
JOIN mart.dim_product dp
    ON o.product_id = dp.product_pk AND dp.is_current
JOIN mart.dim_location dl
    ON o.location_id = dl.location_pk;

COMMIT;