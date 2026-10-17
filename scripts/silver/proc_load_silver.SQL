/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to
    populate the 'silver' schema tables from the 'bronze' schema.
    Actions Performed:
        - Truncates Silver tables.
        - Inserts transformed and cleansed data from Bronze into Silver tables.

Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC Silver.load_silver;
===============================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
	DECLARE @st_time DATETIME, @ed_time DATETIME, @batch_ed_time DATETIME, @batch_st_time DATETIME
	BEGIN TRY
		SET @batch_st_time = GETDATE();
		PRINT'==================================================';
		PRINT'LOADING SILVER LAYER';
		PRINT'==================================================';
		PRINT'==================================================';
		PRINT'LOADING CRM TABLES (SILVER)';
		PRINT'==================================================';
		
		--crm_cust_info silver load
		SET @st_time = GETDATE();
		PRINT'==================================================';
		PRINT'>> TRUNCATING TABLE: silver.crm_cust_info';
		TRUNCATE TABLE silver.crm_cust_info;

		PRINT'>> INSERTING DATA INTO: silver.crm_cust_info';
		INSERT INTO silver.crm_cust_info(
			cust_id,
			cust_key,
			cust_firstname,
			cust_lastname,
			cust_marital_status,
			cust_gndr,
			cst_create_date
		)

		SELECT 
		cust_id, 
		cust_key, 
		TRIM(cust_firstname) AS cst_firstname, 
		TRIM(cust_lastname) AS cst_lastname, 
		CASE 
			WHEN UPPER(TRIM(cust_marital_status))='M' THEN 'Married'
			WHEN UPPER(TRIM(cust_marital_status))='S' THEN 'Single'
			ELSE 'n/a'
		END cust_marital_status, 
		CASE 
			WHEN UPPER(TRIM(cust_gndr))='M' THEN 'Male'
			WHEN UPPER(TRIM(cust_gndr))='F' THEN 'Female'
			ELSE 'n/a'
		END cust_gndr, 
		cst_create_date
		FROM(
			SELECT *,
			ROW_NUMBER() OVER(
							PARTITION BY cust_id 
							ORDER BY cst_create_date DESC
							) AS flag_last
			FROM bronze.crm_cust_info
			WHERE cust_id IS NOT NULL
		)t WHERE flag_last=1;
		SET @ed_time = GETDATE();
		PRINT'==================================================';
		PRINT'TABLE LOADING DURATION:'+CAST(DATEDIFF(second, @st_time, @ed_time) AS NVARCHAR)+' seconds';
		PRINT'==================================================';
		PRINT'==================================================';
		
		--crm_prd_info silver load
		SET @st_time = GETDATE();
		PRINT'==================================================';
		PRINT'>> TRUNCATING TABLE: silver.crm_prd_info';
		TRUNCATE TABLE silver.crm_prd_info;

		PRINT'>> INSERTING DATA INTO: silver.crm_prd_info';	
		INSERT INTO silver.crm_prd_info(
			prd_id,				 
			cat_id,		 
			prd_key,			 
			prd_nm,				 
			prd_cost,			 
			prd_line,			 
			prd_start_dt,		 
			prd_end_dt			  
			)
		SELECT prd_id,
			   REPLACE(SUBSTRING(prd_key, 1,5), '-', '_') AS cat_id,
			   SUBSTRING(prd_key, 7,LEN(prd_key)) AS prd_key,
			   prd_nm,
			   ISNULL(prd_cost,0) AS prd_cost,
			   CASE UPPER(TRIM(prd_line)) 
					WHEN 'M' THEN 'Mountain'
					WHEN 'R' THEN 'Road'
					WHEN 'S' THEN 'Other Sales'
					WHEN 'T' THEN 'Touring'
					ELSE 'n/a'
				END AS prd_line,
			   CAST(prd_start_dt AS DATE) AS prd_start_dt,
			  CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt ASC) -1 AS DATE) AS prd_end_dt
		  FROM bronze.crm_prd_info;
		SET @ed_time = GETDATE();
		PRINT'==================================================';
		PRINT'TABLE LOADING DURATION:'+CAST(DATEDIFF(second, @st_time, @ed_time) AS NVARCHAR)+' seconds';
		PRINT'==================================================';
		PRINT'==================================================';
		  
		  --crm_sales_details silver load
		SET @st_time= GETDATE();
		PRINT'==================================================';
		PRINT'>> TRUNCATING TABLE: silver.crm_sales_details';
		TRUNCATE TABLE silver.crm_sales_details;

		PRINT'>> INSERTING DATA INTO: silver.crm_sales_details';	
		INSERT INTO silver.crm_sales_details(
			sls_ord_num,		
			sls_prd_key,
			sls_cust_id,		
			sls_ord_dt,		
			sls_ship_dt,		
			sls_due_dt,		
			sls_sales,		
			sls_quantity,	
			sls_price

		)
		SELECT  
				sls_ord_num,
				sls_prd_key,
				sls_cust_id,
				CASE WHEN sls_ord_dt <= 0 OR LEN(sls_ord_dt) !=8 THEN NULL
						ELSE CAST(CAST(sls_ord_dt AS VARCHAR) AS DATE)
						END AS sls_ord_dt,
				CASE WHEN sls_ship_dt <= 0 OR LEN(sls_ship_dt) !=8 THEN NULL
						ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
				END AS sls_ship_dt,
				CASE WHEN sls_due_dt <= 0 OR LEN(sls_due_dt) !=8 THEN NULL
						ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
				END AS sls_due_dt,
				CASE 
					WHEN sls_sales IS NULL OR sls_sales<0 OR sls_sales != sls_quantity*ABS(sls_price)
					THEN sls_quantity*ABS(sls_price)
					ELSE sls_sales
				END AS sls_sales,
				sls_quantity,
				CASE 
					WHEN sls_price IS NULL OR sls_price<0
					THEN sls_sales/NULLIF(sls_quantity,0)
					ELSE sls_price
				END AS sls_price
		  FROM bronze.crm_sales_details;
		SET @ed_time= GETDATE();
		PRINT'==================================================';
		PRINT'TABLE LOADING DURATION:'+CAST(DATEDIFF(second, @st_time, @ed_time) AS NVARCHAR)+' seconds';
		PRINT'==================================================';
		PRINT'==================================================';
		PRINT'==================================================';
		PRINT'LOADING ERP TABLES (SILVER)';
		PRINT'==================================================';

		  --erp_cust_az12 silver load
		SET @st_time = GETDATE();
		PRINT'==================================================';
		PRINT'>> TRUNCATING TABLE: silver.erp_cust_az12';
		TRUNCATE TABLE silver.erp_cust_az12;

		PRINT'>> INSERTING DATA INTO: silver.erp_cust_az12';
		INSERT INTO silver.erp_cust_az12(
			cid,
			bdate,		 
			gen				
		)

		SELECT 
		CASE 
			WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4,LEN(cid))
			ELSE cid
		END cid,
		CASE
			WHEN bdate > GETDATE() THEN NULL
			ELSE bdate
		END bdate,
		CASE 
			WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
			WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
			ELSE 'n/a' 
		END gen
		FROM bronze.erp_cust_az12;
		SET @ed_time= GETDATE();
		PRINT'==================================================';
		PRINT'TABLE LOADING DURATION:'+CAST(DATEDIFF(second, @st_time, @ed_time) AS NVARCHAR)+' seconds';
		PRINT'==================================================';
		PRINT'==================================================';

		--erp_loc_a101 silver load
		SET @st_time = GETDATE();
		PRINT'==================================================';
		PRINT'>> TRUNCATING TABLE: silver.erp_loc_a101';
		TRUNCATE TABLE silver.erp_loc_a101;

		PRINT'>> INSERTING DATA INTO: silver.erp_loc_a101';
		INSERT INTO silver.erp_loc_a101(
			cid,					 
			cntry	 
		)
		SELECT 
			REPLACE(cid, '-', '') cid,
			CASE
				WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
				WHEN TRIM(cntry) = 'DE' THEN 'Germany'
				WHEN TRIM(cntry)='' OR cntry IS NULL THEN 'n/a'
				ELSE TRIM(cntry)
			END cntry
		FROM bronze.erp_loc_a101;
		SET @ed_time= GETDATE();
		PRINT'==================================================';
		PRINT'TABLE LOADING DURATION:'+CAST(DATEDIFF(second, @st_time, @ed_time) AS NVARCHAR)+' seconds';
		PRINT'==================================================';
		PRINT'==================================================';

		--erp_px_cat_g1v2 silver load
		SET @st_time = GETDATE();
		PRINT'==================================================';
		PRINT'>> TRUNCATING TABLE: silver.erp_px_cat_g1v2';
		TRUNCATE TABLE silver.erp_px_cat_g1v2;

		PRINT'>> INSERTING DATA INTO: silver.erp_px_cat_g1v2';
		INSERT INTO silver.erp_px_cat_g1v2(
			id,				 
			cat,			 
			subcat,			 
			maintainance
		)
		SELECT 
			id,
			cat,
			subcat,
			maintainance
		FROM bronze.erp_px_cat_g1v2;
		SET @ed_time= GETDATE();
		PRINT'==================================================';
		PRINT'TABLE LOADING DURATION:'+CAST(DATEDIFF(second, @st_time, @ed_time) AS NVARCHAR)+' seconds';
		PRINT'==================================================';
		PRINT'==================================================';
		SET @batch_ed_time= GETDATE();
		PRINT'==================================================';
		PRINT'SILVER TABLE LOADING DURATION:'+CAST(DATEDIFF(second, @batch_st_time, @batch_ed_time) AS NVARCHAR)+' seconds';
		PRINT'==================================================';
	END TRY
	BEGIN CATCH
	PRINT'==================================================';
	PRINT 'AN ERROR OCCURED IN LOADING SILVER LAYER';
	PRINT 'ERROR MESSAGE:'+' '+ERROR_MESSAGE();
	PRINT 'ERROR NUMBER:'+' '+ERROR_NUMBER();
	PRINT 'ERROR STATE:'+' '+ERROR_STATE();
	PRINT'==================================================';
	END CATCH
END
