/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse.
    The Gold layer represents the final dimension and fact tables (Star Schema)

    Each view performs transformations and combines data from the Silver layer
    to produce a clean, enriched, and business-ready dataset.

Usage:
    - These views can be queried directly for analytics and reporting.
===============================================================================
*/

--==============================
--Dimension: gold.dim_customers
--==============================
IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
	DROP VIEW gold.dim_customers;

GO

CREATE VIEW gold.dim_customers AS
SELECT
	ROW_NUMBER() OVER(ORDER BY cust_id) AS customer_key,
	ci.cust_id AS customer_id,
	ci.cust_key AS customer_number,
	ci.cust_firstname AS first_name,
	ci.cust_lastname AS last_name,
	la.cntry AS country,
	ca.bdate AS birthdate,
	CASE WHEN ci.cust_gndr != 'n/a' THEN ci.cust_gndr
		 ELSE COALESCE(ca.gen,'n/a')
	END AS gender,
	ci.cust_marital_status AS marital_status,
	ci.cst_create_date AS create_date
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
ON ci.cust_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON ci.cust_key = la.cid;

GO

--==============================
--Dimension: gold.dim_products
--==============================
IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
	DROP VIEW gold.dim_products;

GO

CREATE VIEW gold.dim_products AS 
SELECT 
ROW_NUMBER() OVER(ORDER BY pn.prd_start_dt, pn.prd_key ASC) AS product_key,
pn.prd_id AS product_id,
pn.prd_key AS product_number,
pn.prd_nm AS product_name,
pn.cat_id AS category_id,
pc.cat AS category_name,
pc.subcat AS subcategory_name,
pc.maintainance AS maintainance,
pn.prd_cost AS product_cost,
pn.prd_line AS product_line,
pn.prd_start_dt AS product_start_date
FROM silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc
ON pn.cat_id=pc.id
WHERE prd_end_dt IS NULL --only selecting the current users/current data(no end date means user/data is still live)

GO

--==============================
--Fact: gold.fact_sales
--==============================
IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
	DROP VIEW gold.fact_sales;

GO

CREATE VIEW gold.fact_sales AS 
SELECT 
sd.sls_ord_num AS order_number,
pr.product_key,
cu.customer_key,
sd.sls_ord_dt AS order_date,
sd.sls_ship_dt AS shipping_date,
sd.sls_due_dt AS due_date,
sd.sls_sales AS sales,
sd.sls_quantity AS quantity,
sd.sls_price AS price
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_products pr
ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers cu
ON sd.sls_cust_id = cu.customer_id;

--------------------------------------------------
--Customer report
--------------------------------------------------
/*
purpose:
	-This report consolidates key customer metrics and behaviours 
highlights:
	1.) gather essential fields such as name, age and transaction details.
	2.) segment customers into categories (VIP, Regular, New) and age groups.
	3.) Aggregatre customer-level metrics:
		-total orders
		-total sales
		-total quantity purchased
		-total products
		-lifespan(in months)
	4.) calculates valuable KPIs
		-recency(months since last orders)
		-average order value
		-average monthly spend
*/
IF OBJECT_ID('gold.report_customers', 'V') IS NOT NULL
	DROP VIEW gold.report_customers;

GO
CREATE VIEW gold.report_customers AS 
WITH base_query AS( --CTE Base query
SELECT 
f.order_number,
f.product_key,
f.order_date,
f.sales,
f.quantity,
c.customer_key,
c.customer_number,
CONCAT(c.first_name,' ',c.last_name) AS full_name,
DATEDIFF(year,c.birthdate, GETDATE()) AS age
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON f.customer_key=c.customer_key
WHERE order_date IS NOT NULL	
), customer_agg AS(		--CTE AGG
SELECT
customer_key,
customer_number,
full_name,
age,
COUNT(DISTINCT order_number) AS tot_orders,
SUM(sales) AS tot_sales,
SUM(quantity) AS tot_quantity,
COUNT(DISTINCT product_key) AS tot_products,
MAX(order_date) AS last_order_date,
MIN(order_date) AS first_order_date,
DATEDIFF(MONTH, MIN(order_date),MAX(order_date)) AS lifespan
FROM base_query
GROUP BY 
	customer_key,
	customer_number,
	full_name,
	age
)
SELECT  --Final table
	customer_key,
	customer_number,
	full_name,
	age,
	CASE 
		 WHEN age<20 THEN 'Below 20'
		 WHEN age BETWEEN 20 AND 29 THEN '20-29'
		 WHEN age BETWEEN 30 AND 39 THEN '30-39'
		 WHEN age BETWEEN 40 AND 49 THEN '40-49'
		 ELSE 'Above 50'
	END AS age_cat,
	CASE 
		 WHEN tot_sales>5000 AND lifespan>=12 THEN 'VIP'
		 WHEN tot_sales<=5000 AND lifespan>=12 THEN 'Regular'
		 ELSE 'New'
	END AS spending_cat,
	tot_orders,
	tot_sales,
	tot_quantity,
	tot_products,
	last_order_date,
	DATEDIFF(MONTH,last_order_date,GETDATE()) AS recency,
	first_order_date,
	lifespan,
	CASE WHEN tot_sales=0 THEN 0
		 ELSE tot_sales/tot_orders
		 END AS avg_order_value,
	CASE WHEN lifespan =0 THEN	tot_sales
		 ELSE tot_sales/lifespan
	END AS avg_monthly_spend
FROM customer_agg a
