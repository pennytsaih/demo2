--step 1
--Rebuild a table of roles and schema access in data_analytics data mart 

CREATE OR REPLACE TABLE DATA_ANALYTICS.DA_STG.GRC_GRANTS_TO_ROLES AS
SELECT DISTINCT GRANTEE_NAME, TABLE_SCHEMA
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE TABLE_SCHEMA IN ('TFC', 'HCP_DATA_MART', 'HCP_BILLING', 'HCP_CENSUS', 'TFC_PVT_REGISTRY')
AND GRANTED_TO = 'ROLE'
AND DELETED_ON IS NULL;

--step 2
--join with other tables to get username and email

CREATE OR REPLACE TABLE DATA_ANALYTICS.DA_INT.GRC_BI_AUDIT AS
SELECT DISTINCT U.LOGIN_NAME, U.EMAIL, GU.ROLE, G.TABLE_SCHEMA, current_date()as LAST_UPDATE
FROM DATA_ANALYTICS.DA_STG.GRC_GRANTS_TO_ROLES G
LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS GU ON GU.ROLE = G.GRANTEE_NAME
LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS U ON GU.GRANTEE_NAME = U.LOGIN_NAME
WHERE U.DISABLED = 'false' AND U.EMAIL IS NOT NULL AND U.DELETED_ON IS NULL AND GU.DELETED_ON IS NULL;


--step 3
--Granting permission to IT_DVLPR role

grant select on table DATA_ANALYTICS.DA_INT.GRC_BI_AUDIT to role IT_DVLPR;
grant select on table DATA_ANALYTICS.DA_STG.GRC_GRANTS_TO_ROLES to role IT_DVLPR;



--step 4
--Create procedure 



CREATE OR REPLACE PROCEDURE DATA_ANALYTICS.DA_STG.GRC_AUDIT_PROCEDURE()
    RETURNS STRING
	LANGUAGE SQL
AS

$$

BEGIN

TRUNCATE TABLE IF EXISTS DATA_ANALYTICS.DA_STG.GRC_GRANTS_TO_ROLES;
TRUNCATE TABLE IF EXISTS DATA_ANALYTICS.DA_INT.GRC_BI_AUDIT;

INSERT INTO DATA_ANALYTICS.DA_STG.GRC_GRANTS_TO_ROLES
SELECT DISTINCT GRANTEE_NAME, TABLE_SCHEMA
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE TABLE_SCHEMA IN ('TFC', 'HCP_DATA_MART', 'HCP_BILLING', 'HCP_CENSUS', 'TFC_PVT_REGISTRY')
AND GRANTED_TO = 'ROLE'
AND DELETED_ON IS NULL;

INSERT INTO DATA_ANALYTICS.DA_INT.GRC_BI_AUDIT
SELECT DISTINCT U.LOGIN_NAME, U.EMAIL, GU.ROLE, G.TABLE_SCHEMA,current_date()as LAST_UPDATE
FROM DATA_ANALYTICS.DA_STG.GRC_GRANTS_TO_ROLES G
LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS GU ON GU.ROLE = G.GRANTEE_NAME
LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS U ON GU.GRANTEE_NAME = U.LOGIN_NAME
WHERE U.DISABLED = 'false' AND U.EMAIL IS NOT NULL AND U.DELETED_ON IS NULL AND GU.DELETED_ON IS NULL;

RETURN 'GRC BI Audit Table Updated';
    
END;

$$
;

--step 5
--scheduling for calling stored procedure 

CREATE OR REPLACE TASK DATA_ANALYTICS.DA_STG.GRC_UPDATE_TASK
WAREHOUSE = IT_WH 
SCHEDULE = 'USING CRON 0 0 1 * * UTC' -- Run on the 1st day of every month
COMMENT = 'Task to run GRC audit procedure every first day of the month'
AS
CALL DATA_ANALYTICS.DA_STG.GRC_AUDIT_PROCEDURE();


select * from DATA_ANALYTICS.DA_INT.GRC_BI_AUDIT limit 2






