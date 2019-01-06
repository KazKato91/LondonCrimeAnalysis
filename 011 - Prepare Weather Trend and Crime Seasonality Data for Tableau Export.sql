--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
-- We can now make the tableau.weather_trend table 
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------

-- again, use a #temptable to set up a temporary dictionary to make things easier.

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

--------------------------------------------------------------------------------------------
-------------------   		The table can now be constructed         -----------------------
--------------------------------------------------------------------------------------------
-- First set up the table
;WITH ctecrime
AS
(
SELECT DISTINCT
	 borough_name
	,d.[year]
	,[month]
	,f.weather_id
	,p.[population]

	,COUNT(CASE WHEN t.crime_cat_id = 1 THEN 1 ELSE NULL END)
		OVER(PARTITION BY b.borough_id, d.[year], d.[month]) AS theft_count 
	,COUNT(CASE WHEN t.crime_cat_id = 2 THEN 1 ELSE NULL END)
		OVER(PARTITION BY b.borough_id, d.[year], d.[month]) AS violent_count 
	,COUNT(CASE WHEN t.crime_cat_id = 3 THEN 1 ELSE NULL END)
		OVER(PARTITION BY b.borough_id, d.[year], d.[month]) AS antisocial_count 
	,COUNT(CASE WHEN t.crime_cat_id = 4 THEN 1 ELSE NULL END)
		OVER(PARTITION BY b.borough_id, d.[year], d.[month]) AS other_count 

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
INNER JOIN #temptype AS t
	ON t.crime_type_id = c.crime_type_id
)
SELECT
	 borough_name
	,[year]
	,[month]
	,(CAST(theft_count AS FLOAT) / CAST([population] AS FLOAT))*1000 AS [Theft Count per 1000pop]
	,(CAST(violent_count AS FLOAT) / CAST([population] AS FLOAT))*1000 AS [Violent Count per 1000pop]
	,(CAST(antisocial_count AS FLOAT) / CAST([population] AS FLOAT))*1000 AS [Anti-social Count per 1000pop]
	,(CAST(other_count AS FLOAT) / CAST([population] AS FLOAT))*1000 AS [Other Count per 1000pop]
	,temp
	,rainfall
	,sun_hours
INTO tableau.weather_trend
FROM ctecrime As c
INNER JOIN DimWeather AS w
	ON w.weather_id = c.weather_id

-- complete, 1980 rows as it should be.
--------------------------------------------------------------------------------------------
-- create the unpivoted view so that we can aggregate by crime type.
-- OLD ONE ---*****--- only gives a general idea of the correlation

CREATE VIEW weather_trend
AS

SELECT
	 borough_name
	,[year]
	,[month]
	,[count]
	,cat
	,temp
	,rainfall
	,sun_hours
FROM 
(
SELECT
	 borough_name
	,[year]
	,[month]
	,[theft count per 1000pop]
	,[violent count per 1000pop]
	,[anti-social count per 1000pop]
	,[other count per 1000pop]
	,temp
	,rainfall
	,sun_hours
FROM tableau.weather_trend
) AS unp
UNPIVOT
(
	[count]
	FOR [cat] 
		IN  (
			 [theft count per 1000pop]
			,[violent count per 1000pop]
			,[anti-social count per 1000pop]
			,[other count per 1000pop]
			)
) AS upp

--------------------------------------------------------------------------------------------
-- CODE FOR PROPER VIEWS:

-- INVESTIGATE SEASONAL VARIANCE BY CRIME CATEGORY

---------------------------------------------------------------------------
--							ASB (Anti-social behaviour)
---------------------------------------------------------------------------

-- First look at Anti-Social Behaviour Crimes

ALTER VIEW seaonal_var_ASB
As

WITH cte
AS
(
SELECT DISTINCT
	 borough_name
	,[month]
	,AVG([Anti-social Count per 1000pop]) OVER (PARTITION BY [month]) AS ASB
	,AVG(rainfall) OVER (PARTITION BY [month]) AS rain
	,AVG(temp) OVER (PARTITION BY [month]) AS temp
	,AVG(sun_hours) OVER (PARTITION BY [month]) AS sun
FROM tableau.weather_trend
),
cte2
AS
(
SELECT 
	 borough_name
	,[month]
	,ASB
	,LAG(ASB,1,0) OVER (PARTITION BY borough_name ORDER BY [month]) AS prev_ASB
	,rain
	,LAG(rain,1,0) OVER (PARTITION BY borough_name ORDER BY [month]) AS prev_rain
	,temp
	,LAG(temp,1,0) OVER (PARTITION BY borough_name ORDER BY [month]) AS prev_temp
	,sun
	,LAG(sun,1,0) OVER (PARTITION BY borough_name ORDER BY [month]) AS prev_sun
FROM cte
)
,
cte3
AS
(
SELECT 
	 [month]
	,ASB
	,CASE
		WHEN prev_ASB = 0 THEN (3.19514114905938)
		ELSE prev_ASB
	 END AS prev_ASB
	,rain
	,CASE
		WHEN prev_rain = 0 THEN (62.4495757575758)
		ELSE prev_rain
	 END AS prev_rain
	,temp
	,CASE
		WHEN prev_temp = 0 THEN (10.3188484848485)
		ELSE prev_temp
	 END AS prev_temp
	,sun
	,CASE
		WHEN prev_sun= 0 THEN (52.8869090909091)
		ELSE prev_sun
	 END AS prev_sun
FROM cte2
)
SELECT DISTINCT
	 [month]
	,(ASB - prev_ASB) / prev_ASB AS [ASB % Diff]
	,(rain - prev_rain) / prev_rain AS [rain % Diff]
	,(temp - prev_temp) / prev_temp AS [temp % Diff]
	,(sun - prev_sun) / prev_sun AS [sun % Diff]
FROM cte3
GO

---------------------------------------------------------------------------
--							THEFT
---------------------------------------------------------------------------

ALTER VIEW seaonal_var_theft
As

WITH cte
AS
(
SELECT DISTINCT
	 borough_name
	,[month]
	,AVG([Theft Count per 1000pop]) OVER (PARTITION BY [month]) AS theft
	,AVG(rainfall) OVER (PARTITION BY [month]) AS rain
	,AVG(temp) OVER (PARTITION BY [month]) AS temp
	,AVG(sun_hours) OVER (PARTITION BY [month]) AS sun
FROM tableau.weather_trend
),
cte2
AS
(
SELECT 
	 borough_name
	,[month]
	,theft
	,LAG(theft,1,0) OVER (PARTITION BY borough_name ORDER BY [month]) AS prev_theft
	,rain
	,LAG(rain,1,0) OVER (PARTITION BY borough_name ORDER BY [month]) AS prev_rain
	,temp
	,LAG(temp,1,0) OVER (PARTITION BY borough_name ORDER BY [month]) AS prev_temp
	,sun
	,LAG(sun,1,0) OVER (PARTITION BY borough_name ORDER BY [month]) AS prev_sun
FROM cte
)
,
cte3
AS
(
SELECT 
	 --borough_name
	 [month]
	,theft
	,CASE
		WHEN prev_theft = 0 THEN (5.11786381094887)
		ELSE prev_theft
	 END AS prev_theft
	,rain
	,CASE
		WHEN prev_rain = 0 THEN (62.4495757575758)
		ELSE prev_rain
	 END AS prev_rain
	,temp
	,CASE
		WHEN prev_temp = 0 THEN (10.3188484848485)
		ELSE prev_temp
	 END AS prev_temp
	,sun
	,CASE
		WHEN prev_sun= 0 THEN (52.8869090909091)
		ELSE prev_sun
	 END AS prev_sun
FROM cte2
)
SELECT DISTINCT
	 [month]
	,(theft - prev_theft) / prev_theft AS [theft % Diff]
	,(rain - prev_rain) / prev_rain AS [rain % Diff]
	,(temp - prev_temp) / prev_temp AS [temp % Diff]
	,(sun - prev_sun) / prev_sun AS [sun % Diff]
FROM cte3
GO

---------------------------------------------------------------------------
--							VIOLENT
---------------------------------------------------------------------------

ALTER VIEW seaonal_var_violent
As

WITH cte
AS
(
SELECT DISTINCT
	 borough_name
	,[month]
	,AVG([Violent Count per 1000pop]) OVER (PARTITION BY [month]) AS violent
	,AVG(rainfall) OVER (PARTITION BY [month]) AS rain
	,AVG(temp) OVER (PARTITION BY [month]) AS temp
	,AVG(sun_hours) OVER (PARTITION BY [month]) AS sun
FROM tableau.weather_trend
),
cte2
AS
(
SELECT 
	 borough_name
	,[month]
	,violent
	,LAG(violent,1,0) OVER (PARTITION BY borough_name ORDER BY [month]) AS prev_violent
	,rain
	,LAG(rain,1,0) OVER (PARTITION BY borough_name ORDER BY [month]) AS prev_rain
	,temp
	,LAG(temp,1,0) OVER (PARTITION BY borough_name ORDER BY [month]) AS prev_temp
	,sun
	,LAG(sun,1,0) OVER (PARTITION BY borough_name ORDER BY [month]) AS prev_sun
FROM cte
)
,
cte3
AS
(
SELECT 
	 --borough_name
	 [month]
	,violent
	,CASE
		WHEN prev_violent = 0 THEN (2.50336676817331)
		ELSE prev_violent
	 END AS prev_violent
	,rain
	,CASE
		WHEN prev_rain = 0 THEN (62.4495757575758)
		ELSE prev_rain
	 END AS prev_rain
	,temp
	,CASE
		WHEN prev_temp = 0 THEN (10.3188484848485)
		ELSE prev_temp
	 END AS prev_temp
	,sun
	,CASE
		WHEN prev_sun= 0 THEN (52.8869090909091)
		ELSE prev_sun
	 END AS prev_sun
FROM cte2
)
SELECT DISTINCT
	 [month]
	,(violent - prev_violent) / prev_violent AS [violent % Diff]
	,(rain - prev_rain) / prev_rain AS [rain % Diff]
	,(temp - prev_temp) / prev_temp AS [temp % Diff]
	,(sun - prev_sun) / prev_sun AS [sun % Diff]
FROM cte3
GO

---------------------------------------------------------------------------
--							OTHER
---------------------------------------------------------------------------


ALTER VIEW seaonal_var_other
As

WITH cte
AS
(
SELECT DISTINCT
	 borough_name
	,[month]
	,AVG([Other Count per 1000pop]) OVER (PARTITION BY [month]) AS other
	,AVG(rainfall) OVER (PARTITION BY [month]) AS rain
	,AVG(temp) OVER (PARTITION BY [month]) AS temp
	,AVG(sun_hours) OVER (PARTITION BY [month]) AS sun
FROM tableau.weather_trend
),
cte2
AS
(
SELECT 
	 borough_name
	,[month]
	,other
	,LAG(other,1,0) OVER (PARTITION BY borough_name ORDER BY [month]) AS prev_other
	,rain
	,LAG(rain,1,0) OVER (PARTITION BY borough_name ORDER BY [month]) AS prev_rain
	,temp
	,LAG(temp,1,0) OVER (PARTITION BY borough_name ORDER BY [month]) AS prev_temp
	,sun
	,LAG(sun,1,0) OVER (PARTITION BY borough_name ORDER BY [month]) AS prev_sun
FROM cte
)
,
cte3
AS
(
SELECT 
	 --borough_name
	 [month]
	,other
	,CASE
		WHEN prev_other = 0 THEN (0.199491466424345)
		ELSE prev_other
	 END AS prev_other
	,rain
	,CASE
		WHEN prev_rain = 0 THEN (62.4495757575758)
		ELSE prev_rain
	 END AS prev_rain
	,temp
	,CASE
		WHEN prev_temp = 0 THEN (10.3188484848485)
		ELSE prev_temp
	 END AS prev_temp
	,sun
	,CASE
		WHEN prev_sun= 0 THEN (52.8869090909091)
		ELSE prev_sun
	 END AS prev_sun
FROM cte2
)
SELECT DISTINCT
	 [month]
	,(other - prev_other) / prev_other AS [other % Diff]
	,(rain - prev_rain) / prev_rain AS [rain % Diff]
	,(temp - prev_temp) / prev_temp AS [temp % Diff]
	,(sun - prev_sun) / prev_sun AS [sun % Diff]
FROM cte3
GO