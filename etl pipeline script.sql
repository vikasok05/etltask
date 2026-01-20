--Row ID,Order ID,Order Date,Ship Date,Ship Mode,
--Customer ID,Customer Name,Segment,
--Country,City,State,Postal Code,Region,
--Product ID,Category,Sub-Category,Product Name
--Sales,Quantity,Discount,Profit

CREATE TABLE IF NOT EXISTS superstore (
    row_id         INTEGER,
	
    order_id       VARCHAR(50),
    order_date     DATE,
    ship_date      DATE,
    ship_mode      VARCHAR(50),
	
    customer_id    VARCHAR(50),
    customer_name  VARCHAR(100),
    segment        VARCHAR(50),
	
    country        VARCHAR(50),
    city           VARCHAR(100),
    statee         VARCHAR(50),
    postal_code    VARCHAR(20),
    region         VARCHAR(50),
	
    product_id     VARCHAR(50),
    category       VARCHAR(50),
    sub_category   VARCHAR(50),
    product_name   VARCHAR(200),
	
    sales          NUMERIC(12,3),
    quantity       INTEGER,
    discount       NUMERIC(5,2),
    profit         NUMERIC(12,2)
);

SET datestyle = 'MDY';

COPY superstore(row_id, order_id, order_date, ship_date, ship_mode, customer_id, customer_name, segment, country, city, statee, postal_code, 
region, product_id, category, sub_category, product_name, sales, quantity, discount, profit)
FROM 'D:\Inn\BI task\Sample - Superstore 9000.csv'
WITH (
	FORMAT csv,
	DELIMITER ',',
	HEADER true
)

CREATE TABLE customers
(
	customer_pk	   BIGSERIAL PRIMARY KEY,
 	customer_id    VARCHAR(50),
    customer_name  VARCHAR(100),
    segment        VARCHAR(50),
	CONSTRAINT unique_customer UNIQUE (customer_id, customer_name, segment)
);

INSERT INTO customers (customer_id, customer_name, segment)
SELECT customer_id, customer_name, segment
FROM superstore
GROUP BY customer_id, customer_name, segment;

CREATE TABLE locations(
	location_pk BIGSERIAL PRIMARY KEY,
	country VARCHAR(50),
	city VARCHAR(50),
	statee VARCHAR(50),
	postal_code VARCHAR(10),
	region VARCHAR(20),
	CONSTRAINT unique_location UNIQUE (country, city, statee, postal_code, region)
);

INSERT INTO locations (country, city, statee, postal_code, region)
SELECT country, city, statee, postal_code, region
FROM superstore
GROUP BY country, city, statee, postal_code, region;

CREATE TABLE products (
	product_pk BIGSERIAL PRIMARY KEY,
	product_id     VARCHAR(50),
    category       VARCHAR(50),
    sub_category   VARCHAR(50),
    product_name   VARCHAR(200),
	CONSTRAINT unique_product UNIQUE(product_id, category, sub_category, product_name)
);

INSERT INTO products (product_id, category, sub_category, product_name)
SELECT product_id, category, sub_category, product_name
FROM superstore
GROUP BY product_id, category, sub_category, product_name;

CREATE TABLE orders(
	order_pk 	   BIGSERIAL PRIMARY KEY,

	order_id       VARCHAR(50),
    order_date     DATE,
    ship_date      DATE,
    ship_mode      VARCHAR(50),
	sales          NUMERIC(12,3),
    quantity       INTEGER,
    discount       NUMERIC(5,2),
    profit         NUMERIC(12,2),

	customer_id INTEGER,
	location_id INTEGER,
	product_id INTEGER,

	CONSTRAINT fk_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_pk),
	CONSTRAINT fk_product FOREIGN KEY (product_id) REFERENCES products(product_pk),
	CONSTRAINT fk_location FOREIGN KEY (location_id) REFERENCES locations(location_pk),

	CONSTRAINT unique_order UNIQUE (order_id, order_date, ship_date, ship_mode, sales, quantity, discount, profit, customer_id, location_id, product_id)
	);

INSERT INTO orders (order_id, order_date, ship_date, ship_mode, sales, quantity, discount, profit, customer_id, location_id, product_id)
SELECT order_id, order_date, ship_date, ship_mode, sales, quantity, discount, profit, customer_pk, location_pk, product_pk
FROM superstore s
LEFT JOIN customers c ON s.customer_id = c.customer_id
	AND s.customer_name = c.customer_name
	AND s.segment = c.segment
LEFT JOIN products p ON s.product_id = p.product_id
	AND s.category = p.category
	AND s.sub_category = p.sub_category
	AND s.product_name = p.product_name
LEFT JOIN locations l ON s.country = l.country
	AND s.city = l.city
	AND s.statee = l.statee
	AND s.postal_code = l.postal_code
	AND s.region = l.region
GROUP BY order_id, order_date, ship_date, ship_mode, sales, quantity, discount, profit, customer_pk, location_pk, product_pk;

DROP TABLE superstore;

CREATE TABLE superstore_sec(
	row_id         INTEGER,
	
    order_id       VARCHAR(50),
    order_date     DATE,
    ship_date      DATE,
    ship_mode      VARCHAR(50),
	
    customer_id    VARCHAR(50),
    customer_name  VARCHAR(100),
    segment        VARCHAR(50),
	
    country        VARCHAR(50),
    city           VARCHAR(100),
    statee         VARCHAR(50),
    postal_code    VARCHAR(20),
    region         VARCHAR(50),
	
    product_id     VARCHAR(50),
    category       VARCHAR(50),
    sub_category   VARCHAR(50),
    product_name   VARCHAR(200),
	
    sales          NUMERIC(12,3),
    quantity       INTEGER,
    discount       NUMERIC(5,2),
    profit         NUMERIC(12,2)
);

COPY superstore_sec(row_id, order_id, order_date, ship_date, ship_mode, customer_id, customer_name, segment, country, city, statee, postal_code, 
region, product_id, category, sub_category, product_name, sales, quantity, discount, profit)
FROM 'D:\Inn\BI task\Sample - Superstore 8990-9994.csv'
WITH (
	FORMAT csv,
	HEADER true,
	DELIMITER ','
)

SELECT *
FROM superstore_sec;

ALTER TABLE customers
ADD COLUMN is_current BOOLEAN,
ADD COLUMN valid_from DATE,
ADD COLUMN valid_to DATE;

UPDATE customers
SET is_current = TRUE,
	valid_from = CURRENT_DATE;

CREATE TEMP TABLE stg_customers AS
SELECT DISTINCT ON (customer_id)
    customer_id,
    customer_name,
    segment
FROM superstore_sec
ORDER BY customer_id, order_date DESC;

UPDATE customers c
SET
    valid_to = CURRENT_DATE - INTERVAL '1 day',
    is_current = FALSE
FROM stg_customers s
WHERE c.customer_id = s.customer_id
  AND c.is_current = TRUE
  AND (
        c.segment IS DISTINCT FROM s.segment
     OR c.customer_name IS DISTINCT FROM s.customer_name
  );

INSERT INTO customers (
    customer_id,
    customer_name,
    segment,
    valid_from,
    is_current
)
SELECT
    s.customer_id,
    s.customer_name,
    s.segment,
    CURRENT_DATE,
    TRUE
FROM stg_customers s
LEFT JOIN customers c
    ON c.customer_id = s.customer_id
   AND c.is_current = TRUE
WHERE c.customer_id IS NULL
   OR (
        c.segment IS DISTINCT FROM s.segment
     OR c.customer_name IS DISTINCT FROM s.customer_name
   );

ALTER TABLE products
ADD COLUMN is_current BOOLEAN,
ADD COLUMN valid_from DATE,
ADD COLUMN valid_to DATE;

UPDATE products
SET is_current = TRUE,
	valid_from = CURRENT_DATE;

CREATE TEMP TABLE stg_products AS
SELECT DISTINCT ON (product_id)
    product_id,
    category,
    sub_category,
    product_name
FROM superstore_sec
ORDER BY product_id;

UPDATE products p
SET
    valid_to = CURRENT_DATE - INTERVAL '1 day',
    is_current = FALSE
FROM stg_products s
WHERE p.product_id = s.product_id
  AND p.is_current = TRUE
  AND (
      p.category     IS DISTINCT FROM s.category OR
      p.sub_category IS DISTINCT FROM s.sub_category OR
      p.product_name IS DISTINCT FROM s.product_name
  );

INSERT INTO products (
    product_id,
    category,
    sub_category,
    product_name,
    valid_from,
    is_current
)
SELECT
    s.product_id,
    s.category,
    s.sub_category,
    s.product_name,
    CURRENT_DATE,
    TRUE
FROM stg_products s
LEFT JOIN products p
    ON p.product_id = s.product_id
   AND p.is_current = TRUE
WHERE p.product_id IS NULL
   OR (
       p.category     IS DISTINCT FROM s.category OR
       p.sub_category IS DISTINCT FROM s.sub_category OR
       p.product_name IS DISTINCT FROM s.product_name
   );

INSERT INTO locations (country, city, statee, postal_code, region)
SELECT DISTINCT
    country, city, statee, postal_code, region
FROM superstore_sec
ON CONFLICT (country, city, statee, postal_code, region) DO NOTHING;

INSERT INTO orders (
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
FROM superstore_sec s
JOIN customers c ON s.customer_id = c.customer_id AND c.is_current = TRUE
JOIN products p ON s.product_id = p.product_id   AND p.is_current = TRUE
JOIN locations l
    ON s.country = l.country
   AND s.city = l.city
   AND s.statee = l.statee
   AND s.postal_code = l.postal_code
   AND s.region = l.region
ON CONFLICT (order_id, order_date, ship_date, ship_mode, sales, quantity, discount, profit, customer_id, location_id, product_id) DO NOTHING;

CREATE TABLE dim_customer (
    customer_sk   BIGSERIAL PRIMARY KEY,
    customer_pk   INTEGER,      
    customer_id   VARCHAR(50),
    customer_name VARCHAR(100),
    segment       VARCHAR(50),
    valid_from    DATE,
    valid_to      DATE,
    is_current    BOOLEAN
);

INSERT INTO dim_customer (
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
FROM customers;

CREATE TABLE dim_product (
    product_sk   BIGSERIAL PRIMARY KEY,
    product_pk   INTEGER,
    product_id   VARCHAR(50),
    category     VARCHAR(50),
    sub_category VARCHAR(50),
    product_name VARCHAR(200),
    valid_from   DATE,
    valid_to     DATE,
    is_current   BOOLEAN
);

INSERT INTO dim_product (
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
FROM products;

CREATE TABLE dim_location (
    location_sk BIGSERIAL PRIMARY KEY,
    location_pk INTEGER,
    country     VARCHAR(50),
    city        VARCHAR(50),
    statee      VARCHAR(50),
    postal_code VARCHAR(10),
    region      VARCHAR(20)
);

INSERT INTO dim_location (
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
FROM locations;

CREATE TABLE dim_date (
    date_sk    INTEGER PRIMARY KEY,
    full_date  DATE,
    year       INTEGER,
    month      INTEGER,
    month_name VARCHAR(20),
    day        INTEGER,
    quarter    INTEGER
);

INSERT INTO dim_date
SELECT DISTINCT
    TO_CHAR(order_date, 'YYYYMMDD')::INTEGER,
    order_date,
    EXTRACT(YEAR FROM order_date),
    EXTRACT(MONTH FROM order_date),
    TO_CHAR(order_date, 'Month'),
    EXTRACT(DAY FROM order_date),
    EXTRACT(QUARTER FROM order_date)
FROM orders;


CREATE TABLE fact_sales (
    order_sk     BIGSERIAL PRIMARY KEY,

    order_id     VARCHAR(50),

    date_sk      INTEGER,
    customer_sk  INTEGER,
    product_sk   INTEGER,
    location_sk  INTEGER,

    sales        NUMERIC(12,3),
    quantity     INTEGER,
    discount     NUMERIC(5,2),
    profit       NUMERIC(12,2),

    CONSTRAINT fk_date     FOREIGN KEY (date_sk)     REFERENCES dim_date(date_sk),
    CONSTRAINT fk_customer FOREIGN KEY (customer_sk) REFERENCES dim_customer(customer_sk),
    CONSTRAINT fk_product  FOREIGN KEY (product_sk)  REFERENCES dim_product(product_sk),
    CONSTRAINT fk_location FOREIGN KEY (location_sk) REFERENCES dim_location(location_sk)
);

INSERT INTO fact_sales (
    order_id,
    date_sk,
    customer_sk,
    product_sk,
    location_sk,
    sales,
    quantity,
    discount,
    profit
)
SELECT
    o.order_id,
    TO_CHAR(o.order_date, 'YYYYMMDD')::INTEGER,

    dc.customer_sk,
    dp.product_sk,
    dl.location_sk,

    o.sales,
    o.quantity,
    o.discount,
    o.profit
FROM orders o

JOIN dim_customer dc
    ON o.customer_id = dc.customer_pk
   AND dc.is_current = TRUE

JOIN dim_product dp
    ON o.product_id = dp.product_pk
   AND dp.is_current = TRUE

JOIN dim_location dl
    ON o.location_id = dl.location_pk;

