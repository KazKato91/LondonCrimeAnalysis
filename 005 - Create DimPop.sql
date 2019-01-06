-- create DimPop with proper key structure!

CREATE TABLE dbo.DimPop
	(
	 pop_id INT PRIMARY KEY
	,[year] SMALLINT NOT NULL
	,borough_id TINYINT NOT NULL -- FK in DimBorough
	,[population] INT NOT NULL
	)
GO

ALTER TABLE DimPop
ADD CONSTRAINT fk_borough_id FOREIGN KEY (borough_id)
	REFERENCES DimBorough (borough_id)
GO

--------------------------------------------------------------------------------------------
-- set up the data in the correct format

IF OBJECT_ID('tempdb..#temppop') IS NOT NULL
	BEGIN
		DROP TABLE #temppop
	END

SELECT
	 LTRIM(RTRIM(bor_name)) AS bor_name
	,[year]
	,[population]
INTO #temppop
FROM
(
SELECT
	 bor_name
	,pop_2012
	,pop_2013
	,pop_2014
	,pop_2015
	,pop_2016
FROM stage.pop
) AS unp
UNPIVOT
(
	[population] 
	FOR [year] 
		IN	(
			 [pop_2012]
			,[pop_2013]
			,[pop_2014]
			,[pop_2015]
			,[pop_2016]
		    )

) AS upp

--------------------------------------------------------------------------------
-- now just throw it into the DimPop with correct key

INSERT INTO DimPop
	(
	 pop_id
	,[year]
	,borough_id
	,[population]
	)
SELECT
	 CAST(CONCAT(RIGHT([year],4), borough_id) AS INT) AS pop_id
	,CAST(RIGHT([year],4) AS SMALLINT) AS [year]
	,borough_id
	,[population]
FROM #temppop AS t
INNER JOIN DimBorough AS b
	ON b.borough_name = t.bor_name