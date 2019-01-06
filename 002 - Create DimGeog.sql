
-- First, let's start by importing (3) DimGeography into the stage schema

-- csv imported,  change col: lsoa code to width = 10


-- clean up 
;WITH cte
AS
(
SELECT 
	 Codes As LSOA_code
	,REPLACE(names,RIGHT(names,5),'') AS borough_name
FROM stage.geog
)

SELECT
	 CAST(LSOA_code AS VARCHAR(10)) AS LSOA_code
	,CAST(b.borough_id AS TINYINT) AS borough_id
INTO dbo.DimGeog
FROM cte AS c
INNER JOIN stage.borough AS b
	ON b.borough_name = c.borough_name

-- create PK!!!
ALTER TABLE DimGeog
ALTER COLUMN LSOA_code VARCHAR(10)NOT NULL
GO

ALTER TABLE DimGeog
ADD CONSTRAINT pk_lsoa_code PRIMARY KEY (LSOA_code)
GOcan be

-- we can add this AFTER DimBorough is created...
ALTER TABLE dbo.dimgeog
ADD CONSTRAINT fk_geog_borough_id FOREIGN KEY (borough_id)
	REFERENCES dimborough (borough_id)
GO
