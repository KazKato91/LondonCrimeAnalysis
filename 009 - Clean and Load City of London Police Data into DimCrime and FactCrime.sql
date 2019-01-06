-- First, prep the stage into a stage2 version, deduped:

-- CITY_STREET
;WITH cte1
AS
(
SELECT
	 CASE
		WHEN [Crime ID] IS NULL AND [Crime type] = 'Anti-social behaviour' 
			THEN CAST(NEWID() AS VARCHAR (64))
		ELSE [Crime ID]
	 END AS crime_id		
	,[Month]
	,[LSOA code]
	,[Crime type]
	,[Last outcome category]
FROM stage.city_street
), cte2
AS
(
SELECT 
	 *
	,ROW_NUMBER() OVER (PARTITION BY crime_id ORDER BY crime_id) AS rn
FROM cte1
)
SELECT
	 *
INTO stage.city_street2
FROM cte2
WHERE 1=1
	AND rn = 1
	AND [LSOA code] IS NOT NULL -- WE DON'T CARE IF THERE IS NO LOCATION 

----------------------**********************----------------------
-- same for CITY_OUTCOME
-- outcome data doesn't have LSOA code.
;WITH cte
AS
(
SELECT 
	 *
	,ROW_NUMBER() OVER (PARTITION BY [crime id] ORDER BY [crime id]) AS rn
FROM stage.city_outcome
)
SELECT
	 *
INTO stage.city_outcome2
FROM cte
WHERE rn = 1


--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------

--						Create a mega #temptable and insert (city -> Dim & Fact)

--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------

-- take care to assign a UNIQUE IDENTIFIER for any unknown crime_id. 		
-- we must ensure that we use the same #temptable to use the same NEWID()	

IF OBJECT_ID('tempdb..#temptable') IS NOT NULL
	BEGIN
		DROP TABLE #temptable
	END

;WITH cte
AS
(
SELECT 
	 cs.[Crime_ID] AS crime_id
	,RIGHT(cs.[Month],2) AS crime_month
	,LEFT(cs.[month],4) AS crime_year
	,cs.[LSOA code] AS LSOA_code
	,cs.[Crime type] AS crime_type
	,ISNULL(cs.[Last outcome category], 'None') AS first_outcome
	,ISNULL(co.[Outcome type], 'None') AS final_outcome
	,RIGHT(co.[Month],2) AS outcome_month
	,LEFT(co.[month],4) AS outcome_year
FROM stage.city_street2 AS cs
-- we need to clean up the city_outcome table before we use it here!
LEFT JOIN stage.city_outcome2 AS co -- LEFT JOIN GIVES US 38972 ROWS; INNER GIVES 31992
	ON co.[Crime ID] = cs.[Crime_ID]
--ORDER BY crime_year, crime_month -- NEW VERSION 23812 ROWS W/WO DISTCINT
)
,cte2 AS
(
SELECT 
	 crime_id
	,TRY_CAST(CONCAT(crime_year,'-',crime_month,'-','01') AS DATE) AS crime_date
	,TRY_CAST(CONCAT(outcome_year,'-',outcome_month,'-','01') AS DATE) AS outcome_date
	,LSOA_code
	,crime_type
	,first_outcome
	,final_outcome
FROM cte
)
SELECT
	 crime_id
	,CAST(CONCAT(SUBSTRING(CAST(crime_date AS VARCHAR(4)),1,4)
				,SUBSTRING(CAST(crime_date AS VARCHAR(7)),6,2)) AS INT) AS crime_date
	,CAST(CONCAT(SUBSTRING(CAST(outcome_date AS VARCHAR(4)),1,4)
				,SUBSTRING(CAST(outcome_date AS VARCHAR(7)),6,2)) AS INT) AS outcome_date
	,CAST(DATEDIFF(mm, crime_date, outcome_date) AS INT) AS months_between
	,LSOA_code
	,crime_type
	,first_outcome
	,final_outcome
INTO #temptable
FROM cte2

--------------------------------------------------------------------------------------------
--						Use #temptable to insert into DimCrime
--------------------------------------------------------------------------------------------

INSERT INTO dbo.DimCrime
	(
	 crime_id
	,crime_type_id
	,first_outcome_id
	,final_outcome_id
	)
SELECT
	 t.crime_id
	,crime_type_id
	,ISNULL(first_outcome_id, 0) AS first_outcome_id
	,ISNULL(final_outcome_id, 0) AS final_outcome_id
FROM #temptable AS t
INNER JOIN DictCrimeType AS ct
	ON ct.crime_type = t.crime_type 
LEFT JOIN DictFirstOutcome AS fr
	ON fr.first_outcome = t.first_outcome
LEFT JOIN DictFinalOutcome AS fn
	ON fn.final_outcome = t.final_outcome

--------------------------------------------------------------------------------------------
--						Use #temptable to insert into FactCrime
--------------------------------------------------------------------------------------------

INSERT INTO FactCrime
	(
	 crime_id
	,crime_date
	,LSOA_code
	,weather_id
	,pop_id
	)
SELECT
	 t.crime_id
	,t.crime_date
	,t.LSOA_code
	,CAST(CONCAT(t.crime_date,b.grid_id) AS BIGINT) AS weather_id
	,CAST(CONCAT(d.[year],g.borough_id) AS INT) AS pop_id
FROM #temptable AS t
INNER JOIN DimGeog AS g
	ON g.LSOA_code = t.LSOA_code
INNER JOIN DimBorough AS b
	ON b.borough_id = g.borough_id
INNER JOIN DimDate As d
	ON d.date_key = t.crime_date


-- sense check to make sure that this has executed properly - yes, 32139 rows returned
SELECT
	 f.crime_id
FROM FactCrime AS f
INNER JOIN DimCrime AS d
	ON d.crime_id = f.crime_id

