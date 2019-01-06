

CREATE DATABASE CrimeData
GO

-------------------------------------------------------------------------------------------

CREATE SCHEMA stage
GO

CREATE SCHEMA tableau
GO

CREATE SCHEMA trash
GO

-------------------------------------------------------------------------------------------
-- 'First Round Investigation'

-- check to see what the data looks like
;WITH cte
AS
(.\.\\
SELECT 
	 cs.[Crime ID]
	,COUNT(cs.[crime id]) AS countcrime
FROM stage.city_street AS cs -- COUNT = 21957
LEFT JOIN stage.city_outcome AS co -- COUNT = 14862
	ON cs.[Crime ID] = co.[Crime ID]
GROUP BY cs.[Crime ID]
)
SELECT
	 *
FROM cte
WHERE countcrime != 1 -- this is DIFFERENT from > 1 ASDFASDFASFD


-- RESULTANT COUNT = 23391

-- SELECT 23391 - 21957 - 1472 -- = 21919 --> 40 defecit

----------------------------------------------------------------------------------------------------------------------------------------

---- this is a problem because we can't find out where the deficit is?!?!?!!?

SELECT
	 * -- returns 1 row
FROM stage.city_street
WHERE [Crime ID] = '006724129e38b131479ac24be625428afd0d6897dbf5f165f12c1a9b01840aa2'



SELECT
	 * -- returns 3 rows
FROM stage.city_outcome
WHERE [Crime ID] = '006724129e38b131479ac24be625428afd0d6897dbf5f165f12c1a9b01840aa2'



-- we can see from this that the outcome table has:
--			duplicate for "suspect charged"
--			extra line for "offender given community sentence"
--		where the only difference can be found in the [Outcome Type]


-- but what about the remaining 38 rows which are not [Crime ID] repetitions?!
-- We must be duplicating on NULLS!

--				but how can we account for these properly? 
--							-> we need to come up with a way to find the rows where there are unique combos to identify the crime without an actual [Crime ID]

-- the multiples are most likely due to multiple offenders being charged out of a singular report - i.e. burglary committed by 3 people.

-- Furthermore, the NULL aspect of this is so small that we can just cut it out and not get any NET negative impact from this.
-- In conclusion, we will have to further investigate the aspects of the NULL combinatronics when we look at the larger MET police data!!!!   