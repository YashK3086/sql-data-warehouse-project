/*
===============================================================================
Quality Checks
===============================================================================
Script Purpose:
    This script performs various quality checks for data consistency, accuracy,
    and standardization across the 'silver' schemas. It includes checks for:
    - Null or duplicate primary keys.
    - Unwanted spaces in string fields.
    - Data standardization and consistency.
    - Invalid date ranges and orders.
    - Data consistency between related fields.

Usage Notes:
    - Run these checks after data loading Silver Layer.
    - Investigate and resolve any discrepancies found during the checks.
===============================================================================
*/

--------------------------------------------------------------------------------
--crm_cust_info table info
--------------------------------------------------------------------------------
--Check for Nulls and Duplicates 

SELECT cust_id, 
COUNT(*)
FROM bronze.crm_cust_info
GROUP BY cust_id
HAVING COUNT(*)>1 OR cust_id IS NULL;

--check for unwanted spaces

SELECT cust_firstname, cust_lastname, cust_gndr
FROM silver.crm_cust_info
WHERE cust_firstname != TRIM(cust_firstname) OR cust_lastname != TRIM(cust_lastname) OR cust_gndr != TRIM(cust_gndr);

--Data standardization & Consistency

SELECT DISTINCT cust_gndr FROM silver.crm_cust_info;

--------------------------------------------------------------------------------
--crm_prd_info table info
--------------------------------------------------------------------------------
--Check for Nulls and Duplicates 

SELECT prd_id, 
COUNT(*)
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*)>1 OR prd_id IS NULL;

--check for unwanted spaces

SELECT prd_nm
FROM silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

--check for NULLS AND NEGATIVES

SELECT prd_cost
FROM silver.crm_prd_info
WHERE prd_cost<0 OR prd_cost IS NULL;

--Data standardization & Consistency

SELECT DISTINCT prd_line FROM silver.crm_prd_info;

--DATE quality check

SELECT * 
FROM silver.crm_prd_info
WHERE prd_start_dt>prd_end_dt;

--------------------------------------------------------------------------------
--crm_sales_details table info
--------------------------------------------------------------------------------
--Check for Nulls and Duplicates 

SELECT sls_ord_num, 
COUNT(*)
FROM silver.crm_sales_details
GROUP BY sls_ord_num
HAVING COUNT(*)>1 OR sls_ord_num IS NULL;

--check for unwanted spaces

SELECT sls_ord_num
FROM bronze.crm_sales_details
WHERE sls_ord_num != TRIM(sls_ord_num);

--Check for invalid dates

SELECT sls_ship_dt, sls_ship_dt
FROM silver.crm_sales_details
WHERE sls_ship_dt <= 0 OR LEN(sls_ship_dt) !=8 OR sls_ship_dt>20500101 OR sls_ship_dt<19000101;

--Check for invalid dates(2)

SELECT * FROM silver.crm_sales_details
WHERE sls_ord_dt>sls_ship_dt OR sls_ord_dt>sls_due_dt;

--Check for invalid sales

SELECT DISTINCT 
sls_sales,
sls_quantity,
sls_price
FROM silver.crm_sales_details
WHERE sls_sales != sls_quantity*sls_price 
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales<=0 OR sls_quantity <= 0 OR sls_price <=0;

--------------------------------------------------------------------------------
--erp_cust_az12 table info
--------------------------------------------------------------------------------
--Check for matching keys and join capacity

SELECT 
CASE 
	WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4,LEN(cid))
	ELSE cid
END cid
FROM silver.erp_cust_az12
 WHERE CASE 
	WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4,LEN(cid))
	ELSE cid
END NOT IN (SELECT DISTINCT cust_key FROM silver.crm_cust_info);

--check for out-of-range dates

SELECT bdate
FROM silver.erp_cust_az12
WHERE  bdate> GETDATE();

--Data standardization & Consistency

SELECT DISTINCT 
gen,
CASE 
	WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
	WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
	ELSE 'n/a' 
END gen
FROM silver.erp_cust_az12;

SELECT * FROM silver.erp_cust_az12
WHERE gen = 'M' OR gen = 'F' OR gen IS NULL;

--------------------------------------------------------------------------------
--erp_loc_a101 table info
--------------------------------------------------------------------------------
--check for invalid and not joinable keys and make them joinable

SELECT cid,cntry FROM silver.erp_loc_a101
WHERE REPLACE(cid, '-', '') NOT IN (SELECT cust_key FROM silver.crm_cust_info);

--Data standardization & Consistency

SELECT DISTINCT cntry AS old_cntry
FROM silver.erp_loc_a101

--------------------------------------------------------------------------------
--erp_px_cat_g1v2 table info
--------------------------------------------------------------------------------
--check for unwanted spaces

SELECT cat, subcat
FROM bronze.erp_px_cat_g1v2
WHERE cat != TRIM(cat) OR subcat != TRIM(subcat) OR maintainance != TRIM(maintainance);

--Data standardization & Consistency

SELECT DISTINCT cat FROM bronze.erp_px_cat_g1v2;
SELECT DISTINCT subcat FROM bronze.erp_px_cat_g1v2;
SELECT DISTINCT maintainance FROM bronze.erp_px_cat_g1v2;








