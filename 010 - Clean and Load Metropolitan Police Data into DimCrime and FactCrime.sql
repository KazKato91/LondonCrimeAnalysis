-- check the data first:

select count(*) from stage.met_outcome -- 4,176,131
select count(*) from stage.met_street --5,023,809 (from 2012 - 2016 inclusive)

-- roughly a million crimes are commited in London every year...



-- first, let's count missing crime id and missing LSOA
SELECT COUNT(*) from stage.met_street where [LSOA code] is null
-- crime id null = 1,350,342
-- LSOA null = 52178 -- which is 1%... we can discard these.
SELECT 52178./5023809

--------------------------------------------------------------------------------------------
--						Clean street data first
--------------------------------------------------------------------------------------------
;WITH cte1
AS
(
SELECT 
	 CASE
		WHEN [Crime ID] IS NULL AND [Crime type] = 'Anti-social behaviour' 
			THEN CAST(NEWID() AS VARCHAR(64))
		ELSE [Crime ID]
	 END AS crime_id
	,[Month]
	,[LSOA code]
	,[Crime type]
	,[Last outcome category]
FROM stage.met_street
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
INTO stage.met_street2
FROM cte2
--where crime_id IS NULL -- now no nulls!
WHERE 1=1
	AND rn = 1
	AND [LSOA code] IS NOT NULL -- count = 4,821,478 which means we lost about 200,000 rows! 
								-- this is fine, as they are only double-charges
								-- we also don't care if we can't attribute the crime to a borough
								-- (discard no LSOA)

--------------------------------------------------------------------------------------------
--						Now clean the outcome data
--------------------------------------------------------------------------------------------
-- more simple, since there are no entries without a crime_id and NULLs are allowed.
-- Now we just need to create met_outcome2

;WITH cte
AS
(
SELECT 
	 [Crime ID]
	,[Month]
	,[Outcome type]
	,ROW_NUMBER() OVER (PARTITION BY [crime id] ORDER BY [crime id]) AS rn -- 4176131
FROM stage.met_outcome
)
SELECT
	 *
--INTO stage.met_outcome2
FROM cte
WHERE rn = 1 -- complete, 3,117,187 rows ; this is fine, as they were all multiple charges.

--------------------------------------------------------------------------------------------
--						Create a new mega #temptable
--------------------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#temptable') IS NOT NULL
	BEGIN
		DROP TABLE #temptable
	END

;WITH cte
AS
(
SELECT 
	 ms.[Crime_ID] AS crime_id
	,RIGHT(ms.[Month],2) AS crime_month
	,LEFT(ms.[month],4) AS crime_year
	,ms.[LSOA code] AS LSOA_code
	,ms.[Crime type] AS crime_type
	,ms.[Last outcome category] AS first_outcome
	,mo.[Outcome type] AS final_outcome
	,RIGHT(mo.[Month],2) AS outcome_month
	,LEFT(mo.[month],4) AS outcome_year
FROM stage.met_street2 AS ms
LEFT JOIN stage.met_outcome2 AS mo 
	ON mo.[Crime ID] = ms.[Crime_ID]
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

-- 4.8 million rows, great! 

--------------------------------------------------------------------------------------------
--						Enter Met data into DimCrime
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
-- fine, 4821478 rows!

--------------------------------------------------------------------------------------------
--						Enter Met data into FactCrime
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
-- DONE, 4,816,276 rows!!


-- NB: FactCrime only accepts LSOA codes from the Greater London District 
-- 	   Hence why there are more rows in FactCrime than DimCrime, the latter being independent of geog

-- We can verify this by simply checking some of these LSOA codes:

select	
	 lsoa_code
from #temptable
where lsoa_code not in(
select
	 lsoa_code
from DimGeog)

	-- checking these on a map verify that they are indeed outside of the Greater London boundary