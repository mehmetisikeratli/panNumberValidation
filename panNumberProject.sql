

-- This project is based on the video from techTFQ youtube channel
-- Link to the youtube video: https://www.youtube.com/watch?v=J1vlhH5LFY8


--- PAN Number Validation Project using SQL ---

-- Create the stage table to store original given dataset

CREATE DATABASE pan_project;
USE pan_project;

drop table if exists stg_pan_numbers_dataset;

create table stg_pan_numbers_dataset
(
	pan_number VARCHAR(20) COLLATE utf8mb4_bin
);

select pan_number from stg_pan_numbers_dataset limit 200; 


-- 1. Identify and handle missing data:
select pan_number from stg_pan_numbers_dataset where pan_number = ''; 


-- 2. Check for duplicates
select pan_number
	, count(1) AS cnt 
from stg_pan_numbers_dataset 
group by pan_number
having cnt > 1
order by 2 desc
; 


-- 3. Handle leading/trailing spaces
select pan_number
from stg_pan_numbers_dataset 
where pan_number <> trim(pan_number)
;


-- 4. Correct letter case
select pan_number
from stg_pan_numbers_dataset 
where pan_number <> upper(pan_number)
;


-- New cleaned table:
create table pan_numbers_dataset_cleaned
as
select distinct upper(trim(pan_number)) as pan_number
from stg_pan_numbers_dataset 
where pan_number is not null
and TRIM(pan_number) <> ''
;


-- validation part for the correct PAN number format:

-- Function to check if adjacent characters are repetative. 
-- Returns true if adjacent characters are adjacent else returns false

CREATE FUNCTION fn_check_adjacent_repetition(p_str VARCHAR(50)) -- there should a string parameter that we need to input
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE str_len INT;

    SET str_len = CHAR_LENGTH(p_str);

    WHILE i < str_len DO
        IF SUBSTRING(p_str, i, 1) = SUBSTRING(p_str, i + 1, 1) THEN
            RETURN TRUE; -- adjacent characters are the same
        END IF;
        SET i = i + 1;
    END WHILE;

    RETURN FALSE; -- no adjacent repetition found
END
;

-- testing the function:
SELECT fn_check_adjacent_repetition('AABB1234Z'); -- Returns TRUE
SELECT fn_check_adjacent_repetition('ABCD1234Z'); -- Returns FALSE



-- Function to check if characters are sequencial such as ABCDE, LMNOP, XYZ etc. 
-- Returns true if characters are sequencial else returns false
CREATE FUNCTION fn_check_sequence(p_str VARCHAR(50))
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE str_len INT;	

    SET str_len = CHAR_LENGTH(p_str);
    
    WHILE i < str_len DO
        IF ascii(substring(p_str, i+1, 1)) - ascii(substring(p_str, i, 1)) <> 1 THEN 
            RETURN FALSE; -- string does not form a sequence
        END IF;
        SET i = i + 1;
    END WHILE;

    RETURN TRUE; -- string forms a sequence
END
;

SELECT ascii('A');
SELECT ascii('B');

SELECT fn_check_sequence('ABCDE'); -- returns 1, because there is a sequence
SELECT fn_check_sequence('AXDGE'); -- returns 0, because there is NOT a sequence



-- Regular expression to validate the pattern or the structure of PAN Numbers -- AAAAA1234A
-- meaning that 5 characters followed by 4 numbers and then 1 character
SELECT *
FROM stg_pan_numbers_dataset
WHERE pan_number REGEXP '^[A-Z]{5}[0-9]{4}[A-Z]$'
; 



-- Valid Invalid PAN categorization
CREATE OR REPLACE VIEW vw_valid_invalid_pans AS  
WITH cleanedPan AS (
	SELECT DISTINCT UPPER(TRIM(pan_number)) AS pan_number
	FROM stg_pan_numbers_dataset
	WHERE pan_number != ''
		AND TRIM(pan_number) <> ''
) -- select * from cleanedPan;
, validPan AS ( -- applying validation rules
	SELECT *
	FROM cleanedPan
	WHERE fn_check_adjacent_repetition(pan_number) = FALSE
		AND fn_check_sequence(substring(pan_number,1,5)) = FALSE
		AND fn_check_sequence(substring(pan_number,6,4)) = FALSE
		AND pan_number REGEXP '^[A-Z]{5}[0-9]{4}[A-Z]$'
) -- select * from validPan;
SELECT pan_number
	, 'Invalid Pan Number' AS status
FROM cleanedPan
WHERE pan_number NOT IN (SELECT pan_number FROM validPan)
UNION ALL
SELECT pan_number
	, 'Valid Pan Number' AS status
FROM validPan
;

SELECT * FROM vw_valid_invalid_pans LIMIT 200;

-- calculating the overall numbers for answering the questions:
WITH cte AS (
SELECT (SELECT COUNT(*) FROM stg_pan_numbers_dataset) AS total_processed_records
	, COUNT(DISTINCT CASE WHEN status='Valid Pan Number' THEN pan_number END) AS valid_pan_count
	, COUNT(DISTINCT CASE WHEN status='Invalid Pan Number' THEN pan_number END) AS invalid_pan_count
FROM vw_valid_invalid_pans 
)
SELECT *
	, total_processed_records - (valid_pan_count+invalid_pan_count) AS missing_incomplete_pan_count
FROM cte
;








