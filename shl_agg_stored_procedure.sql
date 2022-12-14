USE [TLC_PLCPRG_PRD]
GO
/****** Object:  StoredProcedure [dbo].[usp_data_reports_monthly_indicators_green]    Script Date: 9/27/2022 8:14:27 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
------------UPDATE PROCEDURE FOR data_reports_monthly_indicators_green
------------author: Nikita Voevodin
------------dept: data engineering & analytics
------------notes: NO PRIMARY KEY, LOOK BACK IS 3 MONTHS TO CAPTURE DATA CORRECTIONS AND RESUBMISSIONS
-- =============================================
ALTER PROCEDURE [dbo].[usp_data_reports_monthly_indicators_green] 
       
AS
BEGIN

----datetimeid is slightly messed up in yellow and green tables so we will use having to filter to make sure we only keep months in the three month lookback
DECLARE @start as int;
DECLARE @end as int;

------assign variables
SET @start = REPLACE(REPLACE(CONVERT(CHAR(13), DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-3, 0) ,121),'-',''),' ', ''); 
SET @end = REPLACE(REPLACE(CONVERT(CHAR(13), DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())+ 1, 0) ,121),'-',''),' ', ''); 


--set @start = 2020030100;
--set @end = 2020080100;


---SET @end = REPLACE(REPLACE(CONVERT(CHAR(13),DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) ,121),'-',''),' ','');

---SELECT @START, @END
----SET @datetimeid_fence_start = '2020-01';

---SELECT 
---SUBSTRING(
---SUBSTRING(CAST(@start AS VARCHAR),1,4) + '-' +  SUBSTRING(CAST(@start AS VARCHAR),5,2) + '-' + SUBSTRING(CAST(@start AS VARCHAR),7,2)
---,1,7)
---as lookback_one,
---CONVERT( CHAR(7),
---DATEADD(MONTH, 1, 
---SUBSTRING(CAST(@start AS VARCHAR),1,4) + '-' +  SUBSTRING(CAST(@start AS VARCHAR),5,2) + '-' + SUBSTRING(CAST(@start AS VARCHAR),7,2)
---)
---,121) as lookback_two,
---CONVERT( CHAR(7),
---DATEADD(MONTH, 2, 
---SUBSTRING(CAST(@start AS VARCHAR),1,4) + '-' +  SUBSTRING(CAST(@start AS VARCHAR),5,2) + '-' + SUBSTRING(CAST(@start AS VARCHAR),7,2)
---),121) as lookback_three



-----UPDATE table on primary key

MERGE 
INTO data_reports_monthly_indicators_green as target
USING(
SELECT
convert(char(7),lpep_pickup_datetime,121) as Month_Year,
'Green' as License_Class,
count(lpep_pickup_datetime)/datediff(day, dateadd(day, 1-day(MIN(lpep_pickup_datetime)), MIN(lpep_pickup_datetime)),
dateadd(month, 1, dateadd(day, 1-day(MIN(lpep_pickup_datetime)), MIN(lpep_pickup_datetime)))) as Trips_Per_Day,
(sum(total_amount) - sum(case
when(payment_type = 1 and tip_amount <> 0)
then tip_amount
else 0
end))/datediff(day, dateadd(day, 1-day(MIN(lpep_pickup_datetime)), MIN(lpep_pickup_datetime)),
dateadd(month, 1, dateadd(day, 1-day(MIN(lpep_pickup_datetime)), MIN(lpep_pickup_datetime)))) as Farebox_Per_Day,
count(DISTINCT hack_number) as Unique_Drivers,
count(DISTINCT shl_number) as Unique_Vehicles,
count(DISTINCT (convert(char(10),lpep_pickup_datetime,121) + convert(char(8), shl_number,121)))/datediff(day, dateadd(day, 1-day(MIN(lpep_pickup_datetime)), MIN(lpep_pickup_datetime)),
dateadd(month, 1, dateadd(day, 1-day(MIN(lpep_pickup_datetime)), MIN(lpep_pickup_datetime)))) Vehicles_Per_Day,
count(DISTINCT (convert(char(10),lpep_pickup_datetime,121) + convert(char(8), shl_number,121))) * 1.0/count(DISTINCT shl_number) as Avg_Days_Vehicles_on_Road,
count(DISTINCT (convert(char(13),lpep_pickup_datetime,121) + convert(char(13),shl_number,121))) * 1.0/count(DISTINCT (convert(char(13),shl_number,121) + convert(char(10),lpep_pickup_datetime,121))) * 1.0  as Avg_Hours_Per_Day_Per_Vehicle,
count(DISTINCT (convert(char(10),lpep_pickup_datetime,121) + convert(char(8), hack_number,121)))*1.0/count(DISTINCT hack_number) as Avg_Days_Drivers_on_Road,
count(DISTINCT (convert(char(13),lpep_pickup_datetime,121) + convert(char(8),hack_number,121))) * 1.0/count(DISTINCT (convert(char(13),hack_number,121) + convert(char(10),lpep_pickup_datetime,121))) * 1.0 as Avg_Hours_Per_Day_Per_Driver,
(sum(trip_time_in_secs*1.0)/60)/count(lpep_pickup_datetime) as Avg_Minutes_Per_Trip,


-----OLD CC ALG
--sum(CASE
--WHEN payment_type = 1
--THEN 1
--ELSE 0
--END)*1.0/count(lpep_pickup_datetime) as Percent_of_Trips_Paid_with_Credit_Card,

-----NEW CC ALG
 sum(CASE WHEN payment_type = 1 THEN 1
		  WHEN payment_type is null AND ehail_id is not null THEN 1
		  ELSE
          0 END)*1.0/count(lpep_pickup_datetime) as Percent_of_Trips_Paid_with_Credit_Card,
'' as Trips_Per_Day_Shared
FROM
[TRIPDW_LINK].[TPEPDW].[dbo].[lpep2_Triprecord]
--[TRIPDW_LINK].[TPEPDW].[dbo].[lpep2_Triprecord]
WHERE
shl_number Like '[a-b][a-z][0-9][0-9][0-9]' and 
datetimeid >= @start and datetimeid < @end----------OLD (lpep_pickup_datetime >=  '",start,"' and lpep_pickup_datetime < '",end,"')
GROUP BY
convert(char(7),lpep_pickup_datetime,121)
HAVING
CAST(convert(char(7),lpep_pickup_datetime,121) + '-01' AS DATE) 
--BETWEEN
--'2020-03-01' AND '2020-07-01'
>= CAST(SUBSTRING(CAST(@start as VARCHAR),1,4) + '-' + SUBSTRING(CAST(@start as VARCHAR),5,2) + '-01' as DATE)
AND  
CAST(convert(char(7),lpep_pickup_datetime,121) + '-01' AS DATE) 
< SUBSTRING(CAST(@end as VARCHAR),1,4)  + '-' +  SUBSTRING(CAST(@end as VARCHAR),5,2) + '-01'
	
) AS source
ON target.Month_Year = source.Month_Year
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
			,target.Percent_of_Trips_Paid_with_Credit_Card = source.Percent_of_Trips_Paid_with_Credit_Card
			,target.Trips_Per_Day_Shared = source.Trips_Per_Day_Shared
WHEN NOT MATCHED
	THEN INSERT (Month_Year,License_Class,Trips_Per_Day,Farebox_Per_Day,Unique_Drivers,Unique_Vehicles,Vehicles_Per_Day,Avg_Days_Vehicles_on_Road,
				 Avg_Hours_Per_Day_Per_Vehicle,Avg_Days_Drivers_on_Road,Avg_Hours_Per_Day_Per_Driver,Avg_Minutes_Per_Trip,Percent_of_Trips_Paid_with_Credit_Card,Trips_Per_Day_Shared)
		 VALUES (source.Month_Year,source.License_Class,source.Trips_Per_Day,source.Farebox_Per_Day,source.Unique_Drivers,source.Unique_Vehicles,source.Vehicles_Per_Day,
				 source.Avg_Days_Vehicles_on_Road,source.Avg_Hours_Per_Day_Per_Vehicle,source.Avg_Days_Drivers_on_Road,source.Avg_Hours_Per_Day_Per_Driver,source.Avg_Minutes_Per_Trip,
				 source.Percent_of_Trips_Paid_with_Credit_Card,source.Trips_Per_Day_Shared);

END



