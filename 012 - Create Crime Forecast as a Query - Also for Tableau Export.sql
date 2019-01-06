--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--					           CRIME FORECAST DASHBOARD
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
-- First create an export table with the appropriate information.
-- This example uses 2016 June Data to forecast July Data
;WITH cte
AS
(
SELECT
	 [borough_name]
	,[year]
	,[month]
	,[Theft Count per 1000pop] AS last_theft
	,[Violent Count per 1000pop] AS last_violent
	,[Anti-social Count per 1000pop] AS last_ASB
	,[Other Count per 1000pop] AS last_other
	,[temp] AS last_temp
    ,[rainfall] As last_rain
    ,[sun_hours] AS last_sun
FROM tableau.weather_trend 
WHERE 1=1
	AND [year] = 2016
	AND [month] = 6
),
cte2
AS
(
SELECT
	 c.*
	,[temp] AS forecast_temp
    ,[rainfall] As forecast_rain
    ,[sun_hours] AS forecast_sun
FROM cte AS c
INNER JOIN tableau.weather_trend AS w
	ON w.borough_name = c.borough_name
	AND w.[year] = 2016
	AND w.[month] = 7
),
cte3
AS
(
SELECT
	 borough_name
	,[year]
	,[month]
	,last_theft
	,last_violent
	,last_ASB
	,last_other
	,(forecast_temp - last_temp) / last_temp AS [temp%]
	,(forecast_rain - last_rain) / last_rain AS [rain%]
	,(forecast_sun - last_sun) / last_sun AS [sun%]
FROM cte2
),
cte4
As
(
SELECT --* from cte3
	 borough_name
	,[year]
	,[month]
	,last_theft
	,last_violent
	,last_ASB
	,last_other
	,1 + 0.7530688*([temp%]+[rain%]+[sun%])/3 AS [crime change coeff] -- MODIFY % COEFFICIENT HERE
FROM cte3
)
SELECT 
	 borough_name
	,[year]
	,[month]
	,last_theft
	,last_violent
	,last_ASB
	,last_other
	,last_theft * [crime change coeff] AS new_theft
	,last_violent * [crime change coeff] AS new_violent
	,last_ASB * [crime change coeff] AS new_ASB
	,last_other * [crime change coeff] As new_other
INTO tableau.weather_forecast2
FROM cte4
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
-- Make a 'Count Version' (with absolute numbers, not %)
;WITH cte
AS
(
SELECT
	 w.borough_name
	,p.[population]
    ,[last_theft]
    ,[last_violent]
    ,[last_ASB]
    ,[last_other]
    ,[new_theft]
    ,[new_violent]
    ,[new_ASB]
    ,[new_other]
FROM tableau.weather_forecast2 AS w
INNER JOIN DimBorough AS b
	ON b.borough_name = w.borough_name
INNER JOIN DimPop As p
	ON p.borough_id = b.borough_id
	AND p.[year] = w.[year]
),
cte2
AS
(
SELECT
	 borough_name
	,[last_theft]*[population]/1000  AS last_theft_count
    ,[last_violent]*[population]/1000  AS last_violent_count
    ,[last_ASB]*[population]/1000  AS last_ASB_count
    ,[last_other]*[population]/1000  AS last_other_count
    ,[new_theft]*[population]/1000  AS new_theft_count
    ,[new_violent]*[population]/1000  AS new_violent_count
    ,[new_ASB]*[population]/1000  AS new_ASB_count
    ,[new_other]*[population]/1000  AS new_other_count

FROM cte
)
SELECT
	 borough_name
	,new_theft_count - last_theft_count AS theft_change
	,new_violent_count - last_violent_count AS violent_change
	,new_ASB_count - last_ASB_count AS ASB_change
	,new_other_count - last_other_count As last_change
INTO tableau.crime_count_forecast3
FROM cte2
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
-- Finally, export as view:
CREATE VIEW crime_change_forecast
AS

WITH CTE
AS
(
SELECT
	 borough_name
	,[change count]
	,[change type]
FROM
(
SELECT [borough_name]
      ,[theft_change]
      ,[violent_change]
      ,[ASB_change]
      ,[last_change]
FROM [tableau].[crime_count_forecast3]
) AS unp
UNPIVOT
(
	[change count]
	FOR [change type] IN
		(
		 [theft_change]
		,[violent_change]
		,[ASB_change]
		,[last_change]
		)
) AS upp
)
SELECT 
	 MAX([change count])
	,MIN([change count])
FROM CTE

--------------------------------------------------------------------------------------------
-------------------   		The table can now be constructed         -----------------------
--------------------------------------------------------------------------------------------

-- Dictionary first, makes it easier for us.
IF OBJECT_ID('tempdb..#tempttype') IS NOT NULL
	BEGIN
		DROP TABLE #temptable
		DROP TABLE #tempjuly
		DROP TABLE #temppivotjuly
		DROP TABLE #tempjune
		DROP TABLE #temppivotjune
		DROP TABLE #tempforecast
		DROP TABLE #temptemp
	END

;WITH ctetype
AS
(
SELECT 
	 *
	,CASE
		WHEN crime_type_id IN (1, 2, 11) THEN 3
		WHEN crime_type_id IN (3, 4, 6, 13, 14) THEN 2
		WHEN crime_type_id = 16 THEN 4
		ELSE 1
	END AS crime_cat_id
FROM DictCrimeType
)
SELECT
	 *
	,CASE
		WHEN crime_cat_id = 1 THEN 'Theft'
		WHEN crime_cat_id = 2 THEN 'Violent'
		WHEN crime_cat_id = 3 THEN 'Antisocial'
		ELSE 'Other'
	 END AS crime_cat
INTO #temptype
FROM ctetype

-- test forecast model = 2016-07
SELECT DISTINCT
	 b.borough_name
	,tt.crime_cat
	,COUNT(f.crime_id) OVER (PARTITION BY b.borough_id, tt.crime_cat  ) AS july_count
INTO #tempjuly
FROM FactCrime AS f
INNER JOIN DimGeog AS g
	ON g.LSOA_code = f.LSOA_code
INNER JOIN DimBorough AS b
	ON b.borough_id = g.borough_id
INNER JOIN DimCrime AS c
	ON c.crime_id = f.crime_id
INNER JOIN #temptype AS tt
	ON tt.crime_type_id = c.crime_type_id
WHERE f.crime_date = 201607
GO

-- great, now we have to pivot this data...
SELECT
	 borough_name
	,theft
	,antisocial
	,violent
	,other
INTO #temppivotjuly
FROM
(
SELECT
	 borough_name
	,crime_cat
	,july_count
FROM #tempjuly
) AS sourcetable
PIVOT
(
	AVG(july_count)
	FOR crime_cat IN
		(
		 theft
		,antisocial
		,violent
		,other
		)
) AS pvv


-- now we want to know what we forecasted for july, and compare them.
SELECT DISTINCT
	 b.borough_name
	,tt.crime_cat
	,COUNT(f.crime_id) OVER (PARTITION BY b.borough_id, tt.crime_cat  ) AS june_count
INTO  #tempjune
FROM FactCrime AS f
INNER JOIN DimGeog AS g
	ON g.LSOA_code = f.LSOA_code
INNER JOIN DimBorough AS b
	ON b.borough_id = g.borough_id
INNER JOIN DimCrime AS c
	ON c.crime_id = f.crime_id
INNER JOIN #temptype AS tt
	ON tt.crime_type_id = c.crime_type_id
WHERE f.crime_date = 201606

-- and unpivot
SELECT
	 borough_name
	,theft
	,antisocial
	,violent
	,other
INTO #temppivotjune
FROM
(
SELECT
	 borough_name
	,crime_cat
	,june_count
FROM #tempjune
) AS sourcetable
PIVOT
(
	AVG(june_count)
	FOR crime_cat IN
		(
		 theft
		,antisocial
		,violent
		,other
		)
) AS pvv



-- Now get the forecast values for july
;WITH ctejune
AS
(
SELECT
	 j.borough_name
	,theft
	,antisocial
	,violent
	,other
	,theft_change
	,violent_change
	,ASB_change
	,last_change
FROM #temppivotjune As j
INNER JOIN tableau.crime_count_forecast3 AS fc
	ON fc.borough_name = j.borough_name
)
SELECT
	 borough_name
	,theft + theft_change AS theft_july_forecast
	,antisocial + ASB_change AS antisocial_july_forecast
	,violent + violent_change AS violent_july_forecast
	,other + last_change AS other_july_forecast
INTO #tempforecast
FROM ctejune
GO

-- Penultimately, get the percentage difference between
-- predicted and actual..
;WITH ctepercent
AS
(
SELECT
	 t.borough_name
	,theft
	,antisocial
	,violent
	,other
	,antisocial_july_forecast
	,theft_july_forecast
	,violent_july_forecast
	,other_july_forecast
FROM #temppivotjuly AS t
INNER JOIN #tempforecast As f
	ON f.borough_name = t.borough_name
)
SELECT
	 borough_name
	,100*(theft_july_forecast - theft) / theft AS theft_p_diff
	,100*(antisocial_july_forecast - antisocial) / antisocial AS antisocial_p_diff
	,100*(violent_july_forecast - violent) / violent AS violent_p_diff
	,100*(other_july_forecast - other) / other AS other_p_diff
INTO #temptemp
FROM ctepercent


-- Finally, the overall inaccuracy for each borough:
SELECT
	 borough_name
	,(theft_p_diff + antisocial_p_diff + violent_p_diff + theft_p_diff) / 4 AS [% Inaccuracy]
FROM #temptemp

-- AVG of this = -5.52%
-- The forecast model underestimates the data by 5.52%
-- TEST THE FORECAST MODEL



--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--								      END OF CODE 									  --
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------