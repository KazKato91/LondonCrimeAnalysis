--------------------------------------------------------------------------------------------
--								Creat Police Efficiency Table
--------------------------------------------------------------------------------------------
-- we will use some #temptables in order to create temporary dictionaries for the category of outcome

IF OBJECT_ID('tempdb..#tempfirst') IS NOT NULL
	BEGIN
		DROP TABLE #tempfirst
		DROP TABLE #tempfinal
	END


-- Frst Outcome:
;WITH ctefirst
AS
(
SELECT
	 *
	,CASE 
		WHEN first_outcome_id IN (0, 1, 4, 8, 11, 15, 16, 18, 20, 22, 23, 24, 25, 26) THEN 1
		WHEN first_outcome_id IN (12, 17, 19) THEN 3
		ELSE 2
	 END AS first_cat_id 
FROM DictFirstOutcome
)
SELECT
	 *
	,CASE 
		WHEN first_cat_id = 1 THEN 'No Consequence'
		WHEN first_cat_id = 2 THEN 'Penalty Issued'
		ELSE 'Warning'
	 END AS first_cat
INTO #tempfirst
FROM ctefirst

-- Final Outcome:
;WITH ctefinal
AS
(
SELECT
	 *
	,CASE 
		WHEN final_outcome_id IN (0, 1, 9, 13, 15, 17, 20, 21, 22, 23) THEN 1
		WHEN final_outcome_id IN (10, 14, 16) THEN 3
		ELSE 2
	 END AS final_cat_id 
FROM DictFinalOutcome
)
SELECT
	 *
	,CASE 
		WHEN final_cat_id = 1 THEN 'No Consequence'
		WHEN final_cat_id = 2 THEN 'Penalty Issued'
		ELSE 'Warning'
	 END AS final_cat
INTO #tempfinal
FROM ctefinal


--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
-- Now evaluate the warning and penalty ratios and throw it into tableau.police_efficiency
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------

;WITH ctecount
AS
(
SELECT DISTINCT
	 b.borough_name
	,d.[year]
	,d.[month]
	,f.weather_id
	,p.[population]

	,COUNT(CASE WHEN t1.first_cat_id = 3 THEN 1 ELSE NULL END) 
		OVER(PARTITION BY b.borough_id, d.[year], d.[month] ORDER BY d.[year]) AS warning_count1
	,COUNT(CASE WHEN t1.first_cat_id = 1 AND t2.final_cat_id = 3 THEN 1 ELSE NULL END) 
		OVER(PARTITION BY b.borough_id, d.[year], d.[month] ORDER BY d.[year]) AS warning_count2
	
	,COUNT(f.crime_id) 
		OVER(PARTITION BY b.borough_id, d.[year], d.[month] ORDER BY d.[year]) AS crime_count
	
	,COUNT(CASE WHEN t1.first_cat_id = 2 THEN 1 ELSE NULL END) 
		OVER(PARTITION BY b.borough_id, d.[year], d.[month] ORDER BY d.[year]) AS penalty_count1
	,COUNT(CASE WHEN t1.first_cat_id = 1 AND t2.final_cat_id = 2 THEN 1 ELSE NULL END) 
		OVER(PARTITION BY b.borough_id, d.[year], d.[month] ORDER BY d.[year]) AS penalty_count2

FROM FactCrime AS f
INNER JOIN DimCrime AS c
	ON c.crime_id = f.crime_id
INNER JOIN DimDate AS d
	ON d.date_key = f.crime_date
INNER JOIN DimGeog AS g
	ON g.LSOA_code = f.LSOA_code
INNER JOIN DimBorough AS b
	ON b.borough_id = g.borough_id
INNER JOIN DimPop AS p
	ON p.pop_id = f.pop_id
INNER JOIN #tempfirst AS t1
	ON t1.first_outcome_id = c.first_outcome_id
INNER JOIN #tempfinal AS t2
	ON t2.final_outcome_id = c.final_outcome_id
),
cteratio AS
(
SELECT
	 c.borough_name
	,c.[year]
	,c.[month]
	,warning_count1 + warning_count2 AS warning_count
	,crime_count
	,[population]
	,penalty_count1 + penalty_count2 AS penalty_count
	,w.temp
	,w.rainfall
	,w.sun_hours
FROM ctecount AS c
INNER JOIN DimWeather AS w
	ON w.weather_id = c.weather_id
)
SELECT 
	 borough_name AS Borough
	,[Year]
	,[Month]
	,CAST(warning_count AS FLOAT) / CAST(crime_count AS FLOAT) AS [Warning Ratio]
	,CAST(penalty_count AS FLOAT) / CAST(crime_count AS FLOAT) AS [Penalty Ratio]
	,(CAST(crime_count AS FLOAT) / CAST([population] AS FLOAT))*1000 AS [Crime Count per 1000pop]
	,temp AS [Temp (C)]
	,rainfall AS [Rainfall (mm)]
	,sun_hours AS [Sunlight Hours]
INTO tableau.police_efficiency
FROM cteratio
GO

-- sense check rowcount returns the correct 1980 rows for 33 boroughs, 12 months, 5 years!