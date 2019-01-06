
-- import as task, then process:
SELECT
	 CAST(borough_id ASa TINYINT) AS borough_id
	,CAST(borough_name AS VARCHAR (22)) AS borough_name
	,grid_id
INTO dbo.DimBorough
FROM stage.borough


				
				-- this gives us the required VARCHAR length
				SELECT 
					MAX(LEN(borough_name))
				FROM stage.borough


--------------------------------------------------------------------------------------------
-- create keys.

ALTER TABLE dbo.DimBorough
ALTER COLUMN borough_id TINYINT NOT NULL
GO

ALTER TABLE dbo.dimborough
ADD CONSTRAINT pk_borough PRIMARY KEY CLUSTERED (borough_id)
GO

ALTER TABLE dbo.dimborough
ALTER COLUMN grid_id BIGINT NOT NULL
GO