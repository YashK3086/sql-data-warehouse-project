/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================
Script Purpose:
    This stored procedure loads data into the 'bronze' schema from external CSV files.
    It performs the following actions:
    - Truncates the bronze tables before loading data.
    - Uses the `BULK INSERT` command to load data from csv Files to bronze tables.

Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC bronze.load_bronze;
===============================================================================
*/

--BULK LOADING USING FULL LOAD METHOD, INSIDE A STANDARD PROCEDURE
CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
	DECLARE @st_time DATETIME, @ed_time DATETIME, @batch_st_time DATETIME, @batch_ed_time DATETIME
	BEGIN TRY 
	SET @batch_st_time=GETDATE();
	PRINT'==================================================';
	PRINT'LOADING BRONZE LAYER';
	PRINT'==================================================';
	PRINT'==================================================';
	PRINT'LOADING CRM TABLES';
	PRINT'==================================================';
		-- bronze cust_info table
		SET @st_time = GETDATE();
		PRINT'==================================================';
		PRINT'>>TRUNCATING TABLE: bronze.crm_cust_info';
		TRUNCATE TABLE bronze.crm_cust_info;
		PRINT'>>INSERTING DATA INTO TABLE: bronze.crm_cust_info';
		BULK INSERT bronze.crm_cust_info
		FROM 'C:\Users\yashv\Downloads\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_crm\cust_info.csv'
		WITH(
			FIRSTROW=2,
			FIELDTERMINATOR=',',
			TABLOCK
		);
		SET @ed_time = GETDATE();
		PRINT'>>LOADING DURATION:'+CAST(DATEDIFF(second,@st_time,@ed_time) AS NVARCHAR)+' seconds';
		PRINT'==================================================';

		--bronze prd_info table
		SET @st_time = GETDATE();
		PRINT'==================================================';
		PRINT'>>TRUNCATING TABLE: bronze.crm_prd_info';
		TRUNCATE TABLE bronze.crm_prd_info;
		PRINT'>>INSERTING DATA INTO TABLE: bronze.crm_prd_info';
		BULK INSERT bronze.crm_prd_info
		FROM 'C:\Users\yashv\Downloads\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_crm\prd_info.csv'
		WITH(
			FIRSTROW=2,
			FIELDTERMINATOR=',',
			TABLOCK
		);
		SET @ed_time = GETDATE();
		PRINT'>>LOADING DURATION:'+CAST(DATEDIFF(second,@st_time,@ed_time) AS NVARCHAR)+' seconds';
		PRINT'==================================================';

		--bronze sales_details table
		SET @st_time = GETDATE();
		PRINT'==================================================';
		PRINT'>>TRUNCATING TABLE: bronze.crm_sales_details';
		TRUNCATE TABLE bronze.crm_sales_details;
		PRINT'>>INSERTING DATA INTO TABLE: bronze.crm_sales_details';
		BULK INSERT bronze.crm_sales_details
		FROM 'C:\Users\yashv\Downloads\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_crm\sales_details.csv'
		WITH(
			FIRSTROW=2,
			FIELDTERMINATOR=',',
			TABLOCK
		);
		SET @ed_time = GETDATE();
		PRINT'>>LOADING DURATION:'+CAST(DATEDIFF(second,@st_time,@ed_time) AS NVARCHAR)+' seconds';
		PRINT'==================================================';
		PRINT'==================================================';
		PRINT'LOADING ERP TABLES';
		PRINT'==================================================';

		--bronze cust_az12
		SET @st_time = GETDATE();
		PRINT'==================================================';
		PRINT'>>TRUNCATING TABLE: bronze.erp_cust_az12';
		TRUNCATE TABLE bronze.erp_cust_az12;
		PRINT'>>INSERTING DATA INTO TABLE: bronze.erp_cust_az12';
		BULK INSERT bronze.erp_cust_az12
		FROM 'C:\Users\yashv\Downloads\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_erp\CUST_AZ12.csv'
		WITH(
			FIRSTROW=2,
			FIELDTERMINATOR=',',
			TABLOCK
		);
		SET @ed_time = GETDATE();
		PRINT'>>LOADING DURATION:'+CAST(DATEDIFF(second,@st_time,@ed_time) AS NVARCHAR)+' seconds';
		PRINT'==================================================';

		--bronze loc101
		SET @st_time = GETDATE();
		PRINT'==================================================';
		PRINT'>>TRUNCATING TABLE: bronze.erp_loc_a101';
		TRUNCATE TABLE bronze.erp_loc_a101;
		PRINT'>>INSERTING DATA INTO TABLE: bronze.erp_loc_a101';
		BULK INSERT bronze.erp_loc_a101
		FROM 'C:\Users\yashv\Downloads\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_erp\LOC_A101.csv'
		WITH(
			FIRSTROW=2,
			FIELDTERMINATOR=',',
			TABLOCK
		);
		SET @ed_time = GETDATE();
		PRINT'>>LOADING DURATION:'+CAST(DATEDIFF(second,@st_time,@ed_time) AS NVARCHAR)+' seconds';
		PRINT'==================================================';

		--bronze px_cat_g1v2
		SET @st_time = GETDATE();
		PRINT'==================================================';
		PRINT'>>TRUNCATING TABLE: bronze.erp_px_cat_g1v2';
		TRUNCATE TABLE bronze.erp_px_cat_g1v2;
		PRINT'>>INSERTING DATA INTO TABLE: bronze.erp_px_cat_g1v2';
		BULK INSERT bronze.erp_px_cat_g1v2
		FROM 'C:\Users\yashv\Downloads\sql-data-warehouse-project\sql-data-warehouse-project\datasets\source_erp\PX_CAT_G1V2.csv'
		WITH(
			FIRSTROW=2,
			FIELDTERMINATOR=',',
			TABLOCK
		);
		SET @ed_time = GETDATE();
		PRINT'>>LOADING DURATION:'+CAST(DATEDIFF(second,@st_time,@ed_time) AS NVARCHAR)+' seconds';
		PRINT'==================================================';
		SET @batch_ed_time=GETDATE();
		PRINT'============================================='
		PRINT'BRONZE LAYER LOADING COMPLETED'
		PRINT'BRONZE LAYER LOADING DURATION:'+CAST(DATEDIFF(second,@batch_st_time,@batch_ed_time) AS NVARCHAR)+' seconds';
		PRINT'============================================='
	END TRY		
	BEGIN CATCH
	PRINT'============================================='
	PRINT'AN ERROR OCCURED IN LOADING BRONZE LAYER'
	PRINT'ERROR MESSAGE:'+''+ERROR_MESSAGE();
	PRINT'ERROR NUMBER:'+''+CAST(ERROR_NUMBER() AS NVARCHAR);
	PRINT'ERROR STATE:'+''+CAST(ERROR_STATE() AS NVARCHAR);
	PRINT'============================================='
	END CATCH
END
