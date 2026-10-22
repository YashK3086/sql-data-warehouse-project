--------------------------------------------------
--Change over time
--------------------------------------------------
--sales per year 
SELECT 
YEAR(order_date) AS order_year,
MONTH(order_date) AS order_month,
SUM(sales) AS tot_sales_per_day,
COUNT(DISTINCT customer_key) AS tot_custom,
SUM(quantity) AS tot_quant
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY YEAR(order_date), MONTH(order_date) ASC;
 
--------------------------------------------------
--cumulative analysis
--------------------------------------------------
--calculate the total sales per month and the running total of sales over time
SELECT 
	order_month,
	tot_sales AS tot_sales_per_month,
	SUM(tot_sales) OVER(PARTITION BY order_month) AS running_total_per_year,
	AVG(avg_price) OVER(ORDER BY order_month) AS moving_avg_price
FROM(
	SELECT 
		AVG(sales) AS avg_price,
		DATETRUNC(YEAR,order_date) AS order_month,
		SUM(sales) AS tot_sales
	FROM gold.fact_sales
	WHERE DATETRUNC(YEAR,order_date) IS NOT NULL
	GROUP BY DATETRUNC(YEAR,order_date)
)t;

--------------------------------------------------
--performance analysis
--------------------------------------------------
--analyse the yearly performance of products by comparing their sales to both 
--the average sales performance of the product and the previous year sales
WITH yearly_product_sales AS(
	SELECT 
		p.product_name,
		YEAR(f.order_date) AS order_year,
		SUM(sales) AS current_sales
	FROM gold.fact_sales f
	LEFT JOIN gold.dim_products p
	ON f.product_key=p.product_key
	WHERE f.order_date IS NOT NULL
	GROUP BY 
		YEAR(f.order_date),
		p.product_name
)

SELECT
product_name,
order_year,
current_sales,
AVG(current_sales) OVER(PARTITION BY product_name) AS avg_sales,
current_sales-AVG(current_sales) OVER(PARTITION BY product_name) AS diff_avg,
CASE 
	WHEN current_sales-AVG(current_sales) OVER(PARTITION BY product_name)>0 THEN 'ABOVE AVG'
	WHEN current_sales-AVG(current_sales) OVER(PARTITION BY product_name)<0 THEN 'BELOW AVG'	
	ELSE 'AVG'
END AS avg_change,
LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year ASC) AS prev_year_sales,
current_sales-LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year ASC) AS prev_year_diff_in_sales,
CASE 
	WHEN current_sales-LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year ASC)>0 THEN 'INCREASE'
	WHEN current_sales-LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year ASC)<0 THEN 'DECREASE'	
	ELSE 'NO CHANGE'
END AS prev_avg_change
FROM yearly_product_sales
ORDER BY product_name, order_year;

--------------------------------------------------
--part-to-whole analysis
--------------------------------------------------
--which category contribute to the most sales
WITH category_sales AS(
	SELECT 
		p.category_name,
		SUM(f.sales) AS tot_sales
	FROM gold.fact_sales f
	LEFT JOIN gold.dim_products p
	ON f.product_key= p.product_key
	GROUP BY 
		p.category_name
)
SELECT 
	category_name,
	tot_sales,
	SUM(tot_sales) OVER() AS overall_sales,
	CONCAT(ROUND((tot_sales /CAST(SUM(tot_sales) OVER() AS FLOAT) )*100,2),'%') AS percentage_of_tot_sales
FROM category_sales
ORDER BY percentage_of_tot_sales DESC;

--------------------------------------------------
--Data Segmentation
--------------------------------------------------
--segment products into cost ranges and count how many products fall into each segment
WITH product_segment AS(
SELECT
	product_key,
	product_name,
	product_cost,
	CASE WHEN product_cost<100 THEN 'Below 100'
		 WHEN product_cost BETWEEN 100 AND 500 THEN '100-500'
		 WHEN product_cost BETWEEN 500 AND 1000 THEN '500-1000'
		 ELSE 'ABOVE 1000'
	END AS cost_range
FROM gold.dim_products
)

SELECT 
	cost_range, 
	COUNT(product_key) AS tot_products
FROM product_segment
GROUP BY cost_range
ORDER BY tot_products DESC

--group customers into 3 segments based on their spending behaiviour 
--VIP: Atleast 12 Months of History and	spending more than 5000
--Regular: Atleast 12 Months of History and	spending 5000 or less
--New: Lifespan less than 12 months
--and find total number of customers by each group
WITH behavior_analysis AS (
SELECT 
	c.customer_key,
	SUM(f.sales) AS tot_spendings,
	MIN(order_date) AS first_order,
	MAX(order_date) AS last_order,
	DATEDIFF(month,MIN(order_date),MAX(order_date)) AS lifespan
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON f.customer_key=c.customer_key
GROUP BY c.customer_key
)
SELECT 
	COUNT(customer_key) AS tot_custoners,spending_cat
	FROM (
	SELECT 
	customer_key,
	CASE WHEN tot_spendings>5000 AND lifespan>=12 THEN 'VIP'
		 WHEN tot_spendings<=5000 AND lifespan>=12 THEN 'Regular'
		 ELSE 'New'
	END AS spending_cat
	FROM behavior_analysis
)t
GROUP BY spending_cat;

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

--------------------------------------------------
--product report 
--------------------------------------------------
/*
Purpose:
  - This report consolidates key product metrics and behaviors.

Highlights:
  1. Gathers essential fields such as product name, category, subcategory, and cost.
  2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
  3. Aggregates product-level metrics:
     - total orders
     - total sales
     - total quantity sold
     - total customers (unique)
     - lifespan (in months)
  4. Calculates valuable KPIs:
     - recency (months since last sale)
     - average order revenue (AOR)
     - average monthly revenue
===============================================================================
*/
IF OBJECT_ID('gold.report_products', 'V') IS NOT NULL
	DROP VIEW gold.report_products;
GO

CREATE VIEW gold.report_products AS
WITH base_query AS( --BASE QUERY
SELECT 
    f.order_number,
    f.order_date,
    f.customer_key,
    f.sales,
    f.quantity,
    p.product_key,
    p.product_name,
    p.category_name,
    p.subcategory_name,
    p.product_cost
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON f.product_key=p.product_key
WHERE order_number IS NOT NULL
), product_agg AS( --AGG QUERY
SELECT
    product_key,
    product_name,
    category_name,
    subcategory_name,
    product_cost,
    DATEDIFF(MONTH,MIN(order_date),MAX(order_date)) AS lifespan,
    MAX(order_date) AS last_sales_day,
    COUNT(DISTINCT order_number) AS tot_orders,
    COUNT(DISTINCT customer_key) AS tot_customers,
    SUM(sales) AS tot_sales,
    SUM(quantity) AS tot_quantity,
    ROUND(AVG(CAST(sales AS FLOAT)/NULLIF(quantity,0)),2) AS avg_selling_price
FROM base_query
WHERE order_date IS NOT NULL
GROUP BY   
    product_key,
    product_name,
    category_name,
    subcategory_name,
    product_cost   
)
SELECT --FINAL QUERY
    product_key,
    product_name,
    category_name,
    subcategory_name,
    product_cost,
    last_sales_day,
    DATEDIFF(MONTH, last_sales_day, GETDATE()) AS recency_in_months,
    CASE WHEN tot_sales>50000 THEN 'High Performance'
         WHEN tot_sales>=10000 THEN 'Mid-Range'
         ELSE 'Low Performance' 
    END AS  product_segment,
    lifespan,
    tot_orders,
    tot_sales,
    tot_quantity,
    tot_customers,
    avg_selling_price,
    CASE WHEN tot_orders = 0 THEN 0
         ELSE tot_sales/tot_orders 
    END AS avg_order_revenue,
    CASE WHEN lifespan=0 THEN 0
         ELSE tot_sales/lifespan
    END AS avg_monthly_revenue
FROM product_agg
