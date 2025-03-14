-- Databricks notebook source
SET spark.databricks.cloudFiles.schemaInference.sampleSize.numFiles = 2

-- COMMAND ----------

CREATE OR REFRESH STREAMING TABLE jhu_covid19_raw
COMMENT "The raw Johns Hopkins COVID-19 dataset, ingested from /databricks-datasets."
TBLPROPERTIES ("quality" = "bronze")
AS
SELECT *, _metadata.file_name AS source_file_name 
  FROM STREAM read_files(
        "/databricks-datasets/COVID/CSSEGISandData/json/", 
        format => "json", 
        inferColumnTypes => "true", 
        schemaEvolutionMode => "rescue"
);

-- COMMAND ----------

CREATE OR REFRESH MATERIALIZED VIEW jhu_covid19_cleansed(
  CONSTRAINT valid_confirmed EXPECT (confirmed IS NOT NULL) ON VIOLATION DROP ROW
)
COMMENT "The cleansed Johns Hopkins COVID-19 dataset."
TBLPROPERTIES ("quality" = "silver")
AS
SELECT get_json_object(_rescued_data, "$.FIPS") AS fips,
       get_json_object(_rescued_data, "$.Admin2") AS admin2,
       COALESCE(`Country/Region`, get_json_object(_rescued_data, "$.Country_Region")) AS country_region,
       COALESCE(`Province/State`, get_json_object(_rescued_data, "$.Province_State")) AS province_state,
       get_json_object(_rescued_data, "$.Combined_Key") AS combined_key,       
       COALESCE(get_json_object(_rescued_data, "$.Latitude"), get_json_object(_rescued_data, "$.Lat")) AS lat,
       COALESCE(get_json_object(_rescued_data, "$.Longitude"), get_json_object(_rescued_data, "$.Long_")) AS lon,
       get_json_object(_rescued_data, "$.Active") AS active,
       confirmed, 
       deaths, 
       recovered, 
       get_json_object(_rescued_data, "$.Case_Fatality_Ratio") AS case_fatality_ratio,
       get_json_object(_rescued_data, "$.Incident_Rate") AS incident_rate,
       last_update,
       TO_DATE(REPLACE(REPLACE(source_file_name, "/databricks-datasets/COVID/CSSEGISandData/json/", ""), ".json")) AS curr_date
  FROM jhu_covid19_raw;

-- COMMAND ----------

CREATE OR REFRESH MATERIALIZED VIEW jhu_covid19_wa
COMMENT "The cleansed Johns Hopkins COVID-19 dataset for Washington State."
TBLPROPERTIES ("quality" = "gold")
AS
SELECT fips,
       admin2,
       country_region,
       province_state,
       combined_key,       
       lat,
       lon,
       active,
       confirmed, 
       deaths, 
       recovered, 
       case_fatality_ratio,
       incident_rate,
       last_update,
       curr_date
  FROM jhu_covid19_cleansed
 WHERE province_state = 'Washington';
