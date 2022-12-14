USE [TLC_PLCPRG_PRD]
GO
/****** Object:  StoredProcedure [dbo].[usp_data_reports_monthly_indicators_all]    Script Date: 9/27/2022 8:16:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
------------UPDATE PROCEDURE FOR data_reports_monthly_indicators_all
------------author: Nikita Voevodin
------------dept: data engineering & analytics
------------notes: NO PRIMARY KEY, LOOK BACK IS 3 MONTHS TO CAPTURE DATA CORRECTIONS AND RESUBMISSIONS
-- =============================================
ALTER PROCEDURE [dbo].[usp_data_reports_monthly_indicators_all] 
       
AS
BEGIN

---------------------------------Because this table is small and we have the other three for reference it's easier to just drop and reALTER fresh
----------------other tables are protected with updates

----drop existing table
DROP TABLE data_reports_monthly_indicators_all;

---ALTER a new table on the fly from the union of the other three
SELECT * into data_reports_monthly_indicators_all 
FROM(
SELECT * FROM data_reports_monthly_indicators_fhv UNION ALL
SELECT * FROM data_reports_monthly_indicators_green UNION ALL
SELECT * FROM data_reports_monthly_indicators_yellow 
) as T1

END
