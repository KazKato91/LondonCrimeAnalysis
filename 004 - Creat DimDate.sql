-- we need to generate the date_key column! Let's do the recursive cte loop -> dump
-- it into a #temptable and then substring out the datekey, making sure it is a INT

-- first, make sure the #temptable is clear

IF OBJECT_ID('tempdb..#temptable') IS NOT NULL
	BEGIN
		DROP TABLE #temptable
	END


;WITH cte
AS
(
SELECT
	 CAST('2012-01-01' AS DATE) AS dt
	,DATEPART(yy, CAST('2012-01-01' AS DATE)) AS Yr
	,DATEPART(mm, CAST('2012-01-01' AS DATE)) AS Mnth
UNION ALL
SELECT
	 DATEADD(mm,1,dt) AS dt
	,DATEPART(yy, DATEADD(mm,1,dt)) AS Yr
	,DATEPART(mm, DATEADD(mm,1,dt)) AS Qtr
FROM cte
WHERE DATEADD(mm,1,dt) < GETDATE()
)
SELECT
	 * 
INTO #temptable
FROM cte
OPTION (MAXRECURSION 0)

--------------------------------------------------------------------------------------------
-- great! Now we need to generate the date_key from this

;WITH ctemp
AS
(
SELECT 
	 dt
	,yr
	,mnth
	,CAST(CONCAT(SUBSTRING(CAST(dt AS VARCHAR(4)),1,4)
				,SUBSTRING(CAST(dt AS VARCHAR(7)),6,2)) AS INT) AS date_key
FROM #temptable
)
SELECT
	 date_key
	,yr AS [year]
	,mnth AS [month]
	,CASE 
		WHEN mnth IN (3,4,5) THEN 'spr'
		WHEN mnth IN (6,7,8) THEN 'sum'
		WHEN mnth IN (9,10,11) THEN 'aut'
		ELSE 'win'
	 END AS season
INTO dbo.DimDate
FROM ctemp

--------------------------------------------------------------------------------------------
-- MAKE SURE KEY IS SET

ALTER TABLE dbo.DimDate
ALTER COLUMN date_key INT NOT NULL
GO

ALTER TABLE dbo.DimDate
ADD CONSTRAINT pk_date PRIMARY KEY CLUSTERED (date_key)
GO
