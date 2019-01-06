-- So now we can create DimCrime:


				CREATE TABLE dbo.DimCrime
					(
					 crime_id VARCHAR(64) PRIMARY KEY
					,crime_type_id INT
					,first_outcome_id INT
					,final_outcome_id INT
					)
				GO

				ALTER TABLE dbo.DimCrime
				ADD CONSTRAINT fk_typ_id 
					FOREIGN KEY (crime_type_id)
					REFERENCES dbo.DictCrimeType (crime_type_id)
				GO

				ALTER TABLE dbo.DimCrime
				ADD CONSTRAINT fk_first_id 
					FOREIGN KEY (first_outcome_id)
					REFERENCES dbo.DictFirstOutcome (first_outcome_id)
				GO

				ALTER TABLE dbo.DimCrime
				ADD CONSTRAINT fk_final_id 
					FOREIGN KEY (final_outcome_id)
					REFERENCES dbo.DictFinalOutcome (final_outcome_id)
				GO




--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
-- Now create FactCrime

CREATE TABLE FactCrime
	(
	 crime_id VARCHAR(64) PRIMARY KEY
	,crime_date INT -- FK DimDate\date_key
	,LSOA_code VARCHAR(10)
	,weather_id BIGINT
	,pop_id INT
	)
GO


			-- make sure keys are set properly

			ALTER TABLE FactCrime
			ADD CONSTRAINT fk_crime_id
				FOREIGN KEY (crime_id)
				REFERENCES DimCrime (crime_id) -- OK, Done

			ALTER TABLE FactCrime
			ADD CONSTRAINT fk_crime_date
				FOREIGN KEY (crime_date)
				REFERENCES DimDate (date_key) -- OK, Done

			ALTER TABLE FactCrime
			ADD CONSTRAINT fk_LSOA_code
				FOREIGN KEY (LSOA_code)
				REFERENCES DimGeog (LSOA_code) -- OK, Done

			ALTER TABLE FactCrime
			ADD CONSTRAINT fk_weather_id
				FOREIGN KEY (weather_id)
				REFERENCES DimWeather (weather_id) -- OK, Done


			ALTER TABLE FactCrime
			ADD CONSTRAINT fk_pop_id
				FOREIGN KEY (pop_id)
				REFERENCES DimPop (pop_id) -- OK, Done
