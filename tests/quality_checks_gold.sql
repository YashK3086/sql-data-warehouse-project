/*
===============================================================================
Quality Checks
===============================================================================
Script Purpose:
    This script performs quality checks to validate the integrity, consistency,
    and accuracy of the Gold Layer. These checks ensure:
    - Uniqueness of surrogate keys in dimension tables.
    - Referential integrity between fact and dimension tables.
    - Validation of relationships in the data model for analytical purposes.

Usage Notes:
    - Run these checks after data loading Silver Layer.
    - Investigate and resolve any discrepancies found during the checks.
===============================================================================
*/

--=========================================================================
  --Verifications after Aggregations -1
--=========================================================================
--check for duplicates after join

SELECT COUNT(*) FROM (SELECT 
	ci.cust_id,
	ci.cust_key,
	ci.cust_firstname,
	ci.cust_lastname,
	ci.cust_marital_status,
	ci.cust_gndr,
	ci.cst_create_date,
	ca.gen,
	ca.bdate,
	la.cntry
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
ON ci.cust_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON ci.cust_key = la.cid)t 
GROUP BY cust_id
HAVING COUNT(*) > 1;

--Check for unwanted Nulls appearing after joins and removing them, also further geting clear idea of data
--here the main table to be considered is crm, so all genders from crm table are true and are to be followed

SELECT DISTINCT
	ci.cust_gndr,
	ca.gen,
		CASE WHEN ci.cust_gndr != 'n/a' THEN ci.cust_gndr
		 ELSE COALESCE(ca.gen,'n/a')
	END AS New_Gender
FROM silver.crm_cust_info ci 
LEFT JOIN silver.erp_cust_az12 ca
ON ci.cust_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON ci.cust_key = la.cid
ORDER BY ci.cust_gndr, ca.gen

--=========================================================================
  --Verifications after Aggregations -2
--=========================================================================
--Check for repetations and additonal duplicates 

SELECT prd_key, COUNT(*) AS n_repeat FROM 
(SELECT 
pn.prd_id,
pn.cat_id,
pn.prd_key,
pn.prd_nm,
pn.prd_cost,
pn.prd_line,
pn.prd_start_dt,
pc.cat,
pc.subcat,
pc.maintainance
FROM silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc
ON pn.cat_id=pc.id
WHERE prd_end_dt IS NULL)t --only selecting the current users/current data(no end date means user/data is still live)
GROUP BY prd_key
HAVING COUNT(*)>1

--=========================================================================
  --Verifications after Aggregations -3
--=========================================================================
--check if all dimension tables can be joined with facts table successfully

SELECT 
* 
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON f.customer_key=c.customer_key
LEFT JOIN gold.dim_products p
ON f.product_key = p.product_key
WHERE c.customer_key IS NULL OR p.product_key IS NULL
