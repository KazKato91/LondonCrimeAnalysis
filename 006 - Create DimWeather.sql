-- Set up the table which we want to insert into:
CREATE TABLE DimWeather
	(
	 weather_id BIGINT PRIMARY KEY
	,date_key INT
	,grid_id BIGINT
	,temp FLOAT
	,rainfall FLOAT
	,sun_hours FLOAT
	)
GO

ALTER TABLE DimWeather
ADD CONSTRAINT fk_weather_date_key FOREIGN KEY (date_key)
	REFERENCES DiMDate (date_key)
GO

--------------------------------------------------------------------------------------------
-- Nowe we will set up 3 temptables - for {temp, rainfall, sun_hours}

IF OBJECT_ID('tempdb..#temptemp') IS NOT NULL
	BEGIN
		DROP TABLE #temptemp -- (temporary table for temperature)
		DROP TABLE #temprain
		DROP TABLE #tempsun
		DROP TABLE #temptotal
	END -- we can do this all at once, since we will never have only an isolated instance!


-- create the temptables in the same order as above, then mash them into the DimWeather

--------------------- *********** make #temptemp ***********------------------------
;WITH ctetemp
AS
(
SELECT 
	 CAST(CONCAT(SUBSTRING(CAST([year] AS VARCHAR(4)),1,4)
				,SUBSTRING(CAST([year] AS VARCHAR(7)),6,2)) AS INT) AS date_key
	,Name AS grid_id
	,CAST(Value AS FLOAT) as value
FROM stage.temp
)
SELECT
	 CAST(CONCAT(date_key, grid_id) AS BIGINT) AS weather_id
	,value AS temp
INTO #temptemp
FROM ctetemp

--------------------- *********** make #temprain ***********------------------------
;WITH cterain
AS
(
SELECT 
	 CAST(CONCAT(SUBSTRING(CAST([year] AS VARCHAR(4)),1,4)
				,SUBSTRING(CAST([year] AS VARCHAR(7)),6,2)) AS INT) AS date_key
	,Name AS grid_id
	,CAST(Value AS FLOAT) as value
FROM stage.rain
)
SELECT
	 CAST(CONCAT(date_key, grid_id) AS BIGINT) AS weather_id
	,value AS rainfall
INTO #temprain
FROM cterain

--------------------- *********** make #tempsun ***********------------------------
;WITH ctesun
AS
(
SELECT 
	 CAST(CONCAT(SUBSTRING(CAST([year] AS VARCHAR(4)),1,4)
				,SUBSTRING(CAST([year] AS VARCHAR(7)),6,2)) AS INT) AS date_key
	,Name AS grid_id
	,CAST(Value AS FLOAT) as value
FROM stage.sun
)
SELECT
	 CAST(CONCAT(date_key, grid_id) AS BIGINT) AS weather_id
	,value AS sun_hours
INTO #tempsun
FROM ctesun


---------- *********** bring it together with #temptotal ***********---------------
;WITH ctebig
AS
(
SELECT DISTINCT
	 CAST(CONCAT(d.date_key,b.grid_id) AS BIGINT) AS wid
	,date_key
	,grid_id
FROM DimDate AS d
CROSS JOIN DimBorough AS b -- THIS RETURNS 2436 ROWS! (Because it goes up to 2018)
)
SELECT DISTINCT
	 wid AS weather_id
	,date_key
	,grid_id
	,temp
	,rainfall
	,sun_hours
INTO #temptotal -- so we can just throw this into the DimWeather table easily
FROM ctebig AS c
INNER JOIN #temptemp AS t
	ON t.weather_id = c.wid
INNER JOIN #temprain AS r
	ON r.weather_id = c.wid
INNER JOIN #tempsun AS s
	ON s.weather_id = c.wid

							-- already something wrong here because
							-- it returns 1740 rows, instead of 11700 in #temptemp
							-- this is okay, because it only gives the grid_id's which
							-- we already have in DimBorough
							-- 696 difference = 29 grid_id's for 24 months
							-- PERFECT!!!



--------------------------------------------------------------------------------------------
-- We use #temptotal just to ensure a smooth entry into the DimWeather table. (we are using cte)

INSERT INTO DimWeather
	(
	 weather_id
	,date_key
	,grid_id
	,temp
	,rainfall
	,sun_hours
	)
SELECT
	 *
FROM #temptotal