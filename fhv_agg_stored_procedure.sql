USE [TLC_PLCPRG_PRD]
GO
/****** Object:  StoredProcedure [dbo].[usp_data_reports_monthly_indicators_fhv]    Script Date: 9/27/2022 8:15:53 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
------------UPDATE PROCEDURE FOR data_reports_monthly_indicators_fhv
------------author: Nikita Voevodin
------------dept: data engineering & analytics
------------notes: NO PRIMARY KEY, LOOK BACK IS 3 MONTHS TO CAPTURE DATA CORRECTIONS AND RESUBMISSIONS
-- =============================================
ALTER PROCEDURE [dbo].[usp_data_reports_monthly_indicators_fhv] 
       
AS
BEGIN

--------------------------------------------------------------------VARIABLES
DECLARE @start as int;
DECLARE @end as int;
DECLARE @row_count as int;

-------------LOOKBACK IS 3 MONTHS
-------INDEXED FIELD IS datetimeid which looks like 2019010100; this is equal to '2019-01-01' 12:00

SET @start = REPLACE(REPLACE(CONVERT(CHAR(13), DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-3, 0) ,121),'-',''),' ', ''); 
SET @end = REPLACE(REPLACE(CONVERT(CHAR(13), DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) +1, 0) ,121),'-',''),' ', ''); 

--SET @start = 2020010100;
--SET @end = 2020010400;
-------------------------------------------------------------------STAGING TABLES
-------------TRADITIONAL FHV METRICS
WITH fhv_stage as (
SELECT
    floor(datetimeid)/10000 as ym,
    CASE WHEN lic_class = 'APP' THEN 'FHV - High Volume' 
    WHEN lic_class = 'BK' THEN 'FHV - Black Car' 
    WHEN lic_class = 'LV' THEN 'FHV - Livery'
    WHEN lic_class = 'LX' THEN 'FHV - Lux Limo' 
    ELSE lic_class END AS License_Class,
    count(*) as Trips_Per_Month,
    NULL as Farebox_Per_Day,
    count(DISTINCT tlc_drivers_license_number) as Unique_Drivers,
    count(DISTINCT license_plate) as Unique_Vehicles,
    count(DISTINCT ( SUBSTRING(CAST(datetimeid as VARCHAR),1,8) + license_plate)) Vehicles_Per_Month,
    count(DISTINCT ( SUBSTRING(CAST(datetimeid as VARCHAR),1,8) + license_plate)) * 1.0/count(DISTINCT license_plate) as Avg_Days_Vehicles_on_Road,
    count(DISTINCT ( SUBSTRING(CAST(datetimeid as VARCHAR),1,10) + license_plate)) * 1.0/count(DISTINCT (license_plate + SUBSTRING(CAST(datetimeid as VARCHAR),1,8))) * 1.0 as Avg_Hours_Per_Day_Per_Vehicle,
    count(DISTINCT ( SUBSTRING(CAST(datetimeid as VARCHAR),1,8) + tlc_drivers_license_number)) * 1.0/count(DISTINCT tlc_drivers_license_number) as Avg_Days_Drivers_on_Road,
	count(DISTINCT ( SUBSTRING(CAST(datetimeid as VARCHAR),1,10) + tlc_drivers_license_number)) * 1.0/count(DISTINCT (tlc_drivers_license_number + SUBSTRING(CAST(datetimeid as VARCHAR),1,8))) * 1.0 as Avg_Hours_Per_Day_Per_Driver,
	sum(datediff(mi,pickup_datetime, dropoff_datetime))/count(*) as Avg_Minutes_Per_Trip,
    NULL as Percent_of_Trips_Paid_with_Credit_Card,
	NULL as Trips_Per_Day_Shared,
	day(eomonth(MIN(pickup_datetime))) as month_days
	
    FROM
     [TRIPDW_LINK].[TPEPDW].[dbo].[FHV_Prd_TripRecord] 
	AS TRIPS 
    INNER JOIN [TRIPDW_LINK].[TPEPDW].[dbo].[fhv_base_list] bases on 
    TRIPS.[Dispatching_base_num] = bases.[LIC_NO] 
    
    WHERE
    datetimeid >= @start and 
    datetimeid < @end and
    datetimeid is not null and 
    TLC_drivers_License_number is not null and
    Dispatching_base_num is not null and
    lic_class not in ('PR','VN','GR') and
    datediff(mi,pickup_datetime, dropoff_datetime) < 360
    
    GROUP BY
    floor(datetimeid)/10000,
    CASE WHEN lic_class = 'APP' THEN 'FHV - High Volume' 
    WHEN lic_class = 'BK' THEN 'FHV - Black Car' 
    WHEN lic_class = 'LV' THEN 'FHV - Livery'
    WHEN lic_class = 'LX' THEN 'FHV - Lux Limo' 
    ELSE lic_class END
	),

--------HIGH VOLUME METRICS 
hv_stage as (
SELECT
    floor(datetimeid)/10000 as ym,
    'FHV - High Volume' AS License_Class, 
    ------count(pickup_datetime) as trips_per_month,
    count(*) as trips_per_month,
    NULL as Farebox_Per_Day,
    count(DISTINCT TLC_driver_License_num) as Unique_Drivers,
    count(DISTINCT license_plate) as Unique_Vehicles,
    count(DISTINCT ( SUBSTRING(CAST(datetimeid as VARCHAR),1,8) + license_plate)) Vehicles_Per_Month,
    count(DISTINCT ( SUBSTRING(CAST(datetimeid as VARCHAR),1,8) + license_plate)) * 1.0/count(DISTINCT license_plate) as Avg_Days_Vehicles_on_Road,
	count(DISTINCT ( SUBSTRING(CAST(datetimeid as VARCHAR),1,10) + license_plate)) * 1.0/count(DISTINCT (license_plate + SUBSTRING(CAST(datetimeid as VARCHAR),1,8))) * 1.0 as Avg_Hours_Per_Day_Per_Vehicle,
    count(DISTINCT ( SUBSTRING(CAST(datetimeid as VARCHAR),1,8) + tlc_driver_license_num)) * 1.0/count(DISTINCT tlc_driver_license_num) as Avg_Days_Drivers_on_Road,
	count(DISTINCT ( SUBSTRING(CAST(datetimeid as VARCHAR),1,10) + tlc_driver_license_num)) * 1.0/count(DISTINCT (tlc_driver_license_num + SUBSTRING(CAST(datetimeid as VARCHAR),1,8))) * 1.0 as Avg_Hours_Per_Day_Per_Driver,
	--sum(datediff(mi,pickup_datetime, dropoff_datetime))/count(pickup_datetime) as Avg_Minutes_Per_Trip,
    SUM(trip_time * 1.0/60)/count(*) as avg_minutes_per_trip,
	NULL as Percent_of_Trips_Paid_with_Credit_Card,
	SUM(CASE WHEN datetimeid is not null and route_id is not NULL THEN 1 ELSE 0 END) as shared_trips_per_month,
	day(eomonth(MIN(pickup_datetime))) as month_days
	
    FROM
    [TRIPDW_LINK].[TPEPDW].[dbo].[FHVHV_TripRecord]
    
    WHERE
    datetimeid >= @start and 
    datetimeid < @end and
    datetimeid is not null and 
    TLC_driver_License_num is not null and
    ----Dispatching_base_num is not null and
    -----lic_class not in ('PR','VN','GR') and
    trip_time < 21600 --- this is 360 * 60 for seconds to minutes
    
    GROUP BY
    floor(datetimeid)/10000
),
-------FINAL CALCULATIONS AND CLEAN UP FOR TRADITIONAL FHV METRICS
fhv_prod as
(
SELECT
SUBSTRING(CAST(fhv_stage.ym AS VARCHAR),1,4) + '-' + SUBSTRING(CAST(fhv_stage.ym AS VARCHAR),5,6)  as Month_Year,
License_Class,
trips_per_month/month_days as Trips_Per_Day,
Farebox_Per_Day,
Unique_Drivers,
Unique_Vehicles,
Vehicles_Per_Month/month_days as Vehicles_Per_Day,
ROUND(Avg_Days_Vehicles_on_Road,1) as Avg_Days_Vehicles_on_Road,
ROUND(Avg_Hours_Per_Day_Per_Vehicle,1) as Avg_Hours_Per_Day_Per_Vehicle,
ROUND(Avg_Days_Drivers_on_Road, 1) as Avg_Days_Drivers_on_Road,
ROUND(Avg_Hours_Per_Day_Per_Driver, 1) as Avg_Hours_Per_Day_Per_Driver,
ROUND(Avg_Minutes_Per_Trip,1) as Avg_Minutes_Per_Trip,
Percent_of_Trips_Paid_with_Credit_Card,
Trips_Per_Day_Shared
FROM
fhv_stage
),
--------FINAL CALCULATIONS AND CLEAN UP FOR HIGH VOLUME METRICS
hv_prod as(
SELECT
SUBSTRING(CAST(ym AS VARCHAR),1,4) + '-' + SUBSTRING(CAST(ym AS VARCHAR),5,6)   as Month_Year,	
License_Class,	
trips_per_month/month_days as Trips_Per_Day, 	
Farebox_Per_Day,	
Unique_Drivers,	
Unique_Vehicles,	
hv_stage.vehicles_per_month/month_days as Vehicles_Per_Day,	
ROUND(Avg_Days_Vehicles_on_Road,1) as Avg_Days_Vehicles_on_Road,
ROUND(Avg_Hours_Per_Day_Per_Vehicle,1) as Avg_Hours_Per_Day_Per_Vehicle,
ROUND(Avg_Days_Drivers_on_Road, 1) as Avg_Days_Drivers_on_Road,
ROUND(Avg_Hours_Per_Day_Per_Driver, 1) as Avg_Hours_Per_Day_Per_Driver,
ROUND(Avg_Minutes_Per_Trip,1) as Avg_Minutes_Per_Trip,	
Percent_of_Trips_Paid_with_Credit_Card, 	
shared_trips_per_month/month_days Trips_Per_Day_Shared
FROM hv_stage --left join hv_shared_stage on hv_stage.ym = hv_shared_stage.ym and hv_stage.License_Class = hv_shared_stage.License_Class 
),
---UNION - CBIND TABLES
final_all as (
SELECT * from hv_prod
UNION
SELECT * FROM fhv_prod
)

------------------------------------------------UPDATE TABLE 
-------Runs insert, update, or delete operations on a target table from the results of a join with a source table

MERGE 
INTO data_reports_monthly_indicators_fhv as target
USING( SELECT * FROM final_all
) AS source
ON (target.Month_Year = source.Month_Year AND target.License_class = source.License_Class)
WHEN MATCHED
	THEN UPDATE
		SET 
			target.License_Class = source.License_Class
			,target.Trips_Per_Day = source.Trips_Per_Day
			,target.Farebox_Per_Day = source.Farebox_Per_Day
			,target.Unique_Drivers = source.Unique_Drivers
			,target.Unique_Vehicles = source.Unique_Vehicles
			,target.Vehicles_Per_Day = source.Vehicles_Per_Day
			,target.Avg_Days_Vehicles_on_Road = source.Avg_Days_Vehicles_on_Road
			,target.Avg_Hours_Per_Day_Per_Vehicle = source.Avg_Hours_Per_Day_Per_Vehicle
			,target.Avg_Days_Drivers_on_Road = source.Avg_Days_Drivers_on_Road
			,target.Avg_Hours_Per_Day_Per_Driver = source.Avg_Hours_Per_Day_Per_Driver
			,target.Avg_Minutes_Per_Trip = source.Avg_Minutes_Per_Trip
			,target.Trips_Per_Day_Shared = source.Trips_Per_Day_Shared
WHEN NOT MATCHED
	THEN INSERT (Month_Year,License_Class,Trips_Per_Day,Farebox_Per_Day,Unique_Drivers,Unique_Vehicles,Vehicles_Per_Day,Avg_Days_Vehicles_on_Road,
				 Avg_Hours_Per_Day_Per_Vehicle,Avg_Days_Drivers_on_Road,Avg_Hours_Per_Day_Per_Driver,Avg_Minutes_Per_Trip,Trips_Per_Day_Shared)
		 VALUES (source.Month_Year,source.License_Class,source.Trips_Per_Day,source.Farebox_Per_Day,source.Unique_Drivers,source.Unique_Vehicles,source.Vehicles_Per_Day,
				 source.Avg_Days_Vehicles_on_Road,source.Avg_Hours_Per_Day_Per_Vehicle,source.Avg_Days_Drivers_on_Road,source.Avg_Hours_Per_Day_Per_Driver,source.Avg_Minutes_Per_Trip,
				 source.Trips_Per_Day_Shared);


END
