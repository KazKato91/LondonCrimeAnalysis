--------------- CREATE DICTIONARIES ---------------

CREATE TABLE DictCrimeType
	(
	 crime_type_id INT IDENTITY PRIMARY KEY
	,crime_type VARCHAR(50)
	)
GO

INSERT INTO dictcrimetype
	(
	 crime_type
	)
SELECT DISTINCT
	 crime_type
FROM #temptable

SELECT * FROM DictCrimeType
----------------------------------------------
-- next; first_outcome

CREATE TABLE DictFirstOutcome
	(
	 first_outcome_id INT IDENTITY PRIMARY KEY
	,first_outcome VARCHAR(256)
	)
GO

INSERT INTO DictFirstOutcome
	(
	 first_outcome
	)
SELECT DISTINCT
	 first_outcome
FROM #temptable

---****************** force zero insert
SET IDENTITY_INSERT DictFirstOutcome ON
GO
INSERT INTO DictFirstOutcome
	(
	 first_outcome_id
	,first_outcome
	)
VALUES
	(0, 'None')
SET IDENTITY_INSERT DictFirstOutcome OFF
GO

----------------------------------------------
-- finally; final_outcome

CREATE TABLE DictFinalOutcome
	(
	 final_outcome_id INT IDENTITY PRIMARY KEY
	,final_outcome VARCHAR(256)
	)
GO

INSERT INTO DictFinalOutcome
	(
	 final_outcome
	)
SELECT DISTINCT
	 final_outcome
FROM #temptable

-------------*********
SET IDENTITY_INSERT DictFinalOutcome ON
GO
INSERT INTO DictFinalOutcome
	(
	 final_outcome_id
	,final_outcome
	)
VALUES
	(0, 'None')
SET IDENTITY_INSERT DictFinalOutcome OFF
GO
