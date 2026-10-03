-- CROP
DROP TABLE IF EXISTS fact_crop;
CREATE TABLE fact_crop AS
WITH mapped AS (
    SELECT CASE WHEN UPPER(TRIM(province)) = 'NORTH COTABATO' THEN 'COTABATO'
                ELSE UPPER(TRIM(province)) END AS province,
           CAST(year AS INTEGER) AS year,
           quarter,
           crop,
           crop_group,
           CAST(production AS REAL) AS production
    FROM stg_crop
), dedup AS (
    SELECT DISTINCT province, year, quarter, crop, crop_group, production FROM mapped
)
SELECT province,
       year,
       quarter,
       CAST(SUBSTR(quarter, -1) AS INTEGER)              AS quarter_num,
       year * 4 + CAST(SUBSTR(quarter, -1) AS INTEGER)   AS time_index,
       crop,
       MAX(crop_group)                                   AS crop_group,
       SUM(production)                                   AS production_mt,
       COUNT(*)                                          AS source_rows_merged
FROM dedup
GROUP BY province, year, quarter, crop;

CREATE INDEX IF NOT EXISTS idx_fact_crop ON fact_crop (province, crop, time_index);

DROP TABLE IF EXISTS fact_crop_metrics;
CREATE TABLE fact_crop_metrics AS
WITH m AS (
    SELECT f.*,
           p.production_mt AS production_lag_4_mt,
           CASE WHEN p.production_mt > 0
                THEN (f.production_mt - p.production_mt) / p.production_mt END AS growth_rate_yoy
    FROM fact_crop f
    LEFT JOIN fact_crop p
           ON p.province = f.province AND p.crop = f.crop AND p.time_index = f.time_index - 4
)
SELECT m.*,
       CASE WHEN growth_rate_yoy IS NULL THEN 'No baseline'
            WHEN growth_rate_yoy <= -0.20 THEN 'Sharp decline'
            WHEN growth_rate_yoy <  -0.05 THEN 'Decline'
            WHEN growth_rate_yoy <=  0.05 THEN 'Stable'
            WHEN growth_rate_yoy <   0.20 THEN 'Growth'
            ELSE 'Strong growth' END AS yoy_band
FROM m;

-- WEATHER
DROP TABLE IF EXISTS clean_weather;
CREATE TABLE clean_weather AS
WITH norm AS (
    SELECT CASE WHEN UPPER(TRIM(province)) = 'NORTH COTABATO' THEN 'COTABATO'
                ELSE UPPER(TRIM(province)) END AS province,
           CAST(year AS INTEGER) AS year,
           CAST(SUBSTR(quarter, -1) AS INTEGER) AS quarter_num,
           CAST(temperature_2m_mean AS REAL) AS temperature_2m_mean,
           CAST(temperature_2m_max AS REAL)  AS temperature_2m_max,
           CAST(temperature_2m_min AS REAL)  AS temperature_2m_min,
           CAST(precipitation_sum AS REAL)   AS precipitation_sum,
           CAST(rain_sum AS REAL)            AS rain_sum,
           CAST(precipitation_hours AS REAL) AS precipitation_hours,
           CAST(sunshine_duration AS REAL)   AS sunshine_duration,
           CAST(shortwave_radiation_sum AS REAL) AS shortwave_radiation_sum,
           CAST(et0_fao_evapotranspiration AS REAL) AS et0_fao_evapotranspiration,
           CAST(wind_speed_10m_max AS REAL)  AS wind_speed_10m_max,
           CAST(wind_gusts_10m_max AS REAL)  AS wind_gusts_10m_max,
           CAST(rain_normal AS REAL)         AS rain_normal,
           CAST(temp_normal AS REAL)         AS temp_normal,
           CAST(rainfall_deviation_pct AS REAL) AS rainfall_deviation_pct,
           CAST(temperature_anomaly_c AS REAL)  AS temperature_anomaly_c,
           CAST(oni_index AS REAL)           AS oni_index,
           TRIM(enso_phase)                  AS enso_phase
    FROM stg_weather
)
SELECT province, year, quarter_num,
       'Q' || quarter_num                       AS quarter,
       year * 4 + quarter_num                   AS time_index,
       AVG(temperature_2m_mean)  AS temperature_2m_mean,
       AVG(temperature_2m_max)   AS temperature_2m_max,
       AVG(temperature_2m_min)   AS temperature_2m_min,
       AVG(precipitation_sum)    AS precipitation_mm,
       AVG(rain_sum)             AS rain_mm,
       AVG(precipitation_hours)  AS precipitation_hours,
       AVG(sunshine_duration) / 3600.0  AS sunshine_hours,
       AVG(shortwave_radiation_sum)     AS shortwave_radiation_mj_m2,
       AVG(et0_fao_evapotranspiration)  AS et0_mm,
       AVG(wind_speed_10m_max)   AS wind_speed_max_kmh,
       AVG(wind_gusts_10m_max)   AS wind_gust_max_kmh,
       AVG(rain_normal)          AS rain_normal_mm,
       AVG(temp_normal)          AS temp_normal_c,
       AVG(rainfall_deviation_pct) AS rainfall_deviation_pct,
       AVG(temperature_anomaly_c)  AS temperature_anomaly_c,
       MAX(oni_index)            AS oni_index,
       MAX(enso_phase)           AS enso_phase
FROM norm
GROUP BY province, year, quarter_num;

DROP TABLE IF EXISTS fact_weather;
CREATE TABLE fact_weather AS
WITH r AS (
    SELECT w.*,
           AVG(temperature_anomaly_c) OVER (PARTITION BY province ORDER BY time_index
               ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS temp_anomaly_rolling,
           AVG(rainfall_deviation_pct) OVER (PARTITION BY province ORDER BY time_index
               ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS rain_anomaly_rolling
    FROM clean_weather w
)
SELECT r.*,
       ABS(rain_anomaly_rolling) + ABS(temp_anomaly_rolling) AS climate_stress
FROM r
WHERE province IN (SELECT DISTINCT province FROM fact_crop);




DROP TABLE IF EXISTS ref_province_region;
CREATE TABLE ref_province_region (province TEXT PRIMARY KEY, region TEXT);
INSERT INTO ref_province_region VALUES
('ILOCOS NORTE','Ilocos Region'),('ILOCOS SUR','Ilocos Region'),('LA UNION','Ilocos Region'),('PANGASINAN','Ilocos Region'),
('ISABELA','Cagayan Valley'),
('BATAAN','Central Luzon'),('BULACAN','Central Luzon'),('NUEVA ECIJA','Central Luzon'),('PAMPANGA','Central Luzon'),('ZAMBALES','Central Luzon'),
('BATANGAS','CALABARZON'),('CAVITE','CALABARZON'),('LAGUNA','CALABARZON'),('QUEZON','CALABARZON'),('RIZAL','CALABARZON'),
('ORIENTAL MINDORO','MIMAROPA'),('PALAWAN','MIMAROPA'),
('ALBAY','Bicol Region'),('CAMARINES NORTE','Bicol Region'),('CAMARINES SUR','Bicol Region'),('MASBATE','Bicol Region'),
('CAPIZ','Western Visayas'),('ILOILO','Western Visayas'),('NEGROS OCCIDENTAL','Western Visayas'),
('CEBU','Central Visayas'),
('EASTERN SAMAR','Eastern Visayas'),('LEYTE','Eastern Visayas'),('SAMAR','Eastern Visayas'),('SOUTHERN LEYTE','Eastern Visayas'),
('ZAMBOANGA DEL NORTE','Zamboanga Peninsula'),('ZAMBOANGA DEL SUR','Zamboanga Peninsula'),('ZAMBOANGA SIBUGAY','Zamboanga Peninsula'),
('BUKIDNON','Northern Mindanao'),('LANAO DEL NORTE','Northern Mindanao'),('MISAMIS OCCIDENTAL','Northern Mindanao'),('MISAMIS ORIENTAL','Northern Mindanao'),
('DAVAO','Davao Region'),('DAVAO DE ORO','Davao Region'),('DAVAO DEL NORTE','Davao Region'),('DAVAO DEL SUR','Davao Region'),
('DAVAO OCCIDENTAL','Davao Region'),('DAVAO ORIENTAL','Davao Region'),
('COTABATO','SOCCSKSARGEN'),('SOUTH COTABATO','SOCCSKSARGEN'),
('AGUSAN DEL NORTE','Caraga'),('AGUSAN DEL SUR','Caraga'),('SURIGAO DEL SUR','Caraga'),
('BENGUET','Cordillera Administrative Region'),
('BASILAN','BARMM'),('LANAO DEL SUR','BARMM'),('MAGUINDANAO DEL NORTE','BARMM'),('MAGUINDANAO DEL SUR','BARMM');

DROP TABLE IF EXISTS dim_province;
CREATE TABLE dim_province AS
WITH span AS (
    SELECT province, MIN(year) AS first_year, MAX(year) AS last_year FROM fact_crop GROUP BY province
)
SELECT s.province, r.region, 'Philippines' AS country,
       s.first_year, s.last_year,
       CASE WHEN s.last_year < 2025 THEN 1 ELSE 0 END AS is_historical,
       CASE WHEN s.first_year >= 2025 THEN 1 ELSE 0 END AS is_new_in_2025
FROM span s LEFT JOIN ref_province_region r ON r.province = s.province;

DROP TABLE IF EXISTS dim_crop;
CREATE TABLE dim_crop AS
SELECT crop, MAX(crop_group) AS crop_group,
       MIN(year) AS first_year, MAX(year) AS last_year,
       COUNT(DISTINCT province) AS provinces_producing
FROM fact_crop GROUP BY crop;

DROP TABLE IF EXISTS dim_date;
CREATE TABLE dim_date AS
SELECT time_index, year, quarter_num, quarter,
       year || ' ' || quarter AS period_label,
       printf('%04d-%02d-01', year, (quarter_num - 1) * 3 + 1) AS quarter_start_date,
       CASE WHEN year BETWEEN 2011 AND 2025 THEN 1 ELSE 0 END AS is_complete_year,
       MAX(oni_index) AS oni_index,
       MAX(enso_phase) AS enso_phase
FROM fact_weather
GROUP BY time_index, year, quarter_num, quarter;


SELECT 'duplicate keys in fact_crop' AS check_name, COUNT(*) AS failing_rows
FROM (SELECT 1 FROM fact_crop GROUP BY province, time_index, crop HAVING COUNT(*) > 1)
UNION ALL
SELECT 'duplicate keys in fact_weather', COUNT(*)
FROM (SELECT 1 FROM fact_weather GROUP BY province, time_index HAVING COUNT(*) > 1)
UNION ALL
SELECT 'crop rows with no weather match', COUNT(*)
FROM fact_crop f LEFT JOIN fact_weather w ON w.province = f.province AND w.time_index = f.time_index
WHERE w.province IS NULL
UNION ALL
SELECT 'crop rows with no province in dim', COUNT(*)
FROM fact_crop f LEFT JOIN dim_province p ON p.province = f.province WHERE p.province IS NULL
UNION ALL
SELECT 'provinces with no region', COUNT(*) FROM dim_province WHERE region IS NULL
UNION ALL
SELECT 'non positive production', COUNT(*) FROM fact_crop WHERE production_mt <= 0
UNION ALL
SELECT 'null ENSO phase', COUNT(*) FROM fact_weather WHERE enso_phase IS NULL OR enso_phase = ''
UNION ALL
SELECT 'production total differs from source (mt, rounded)',
       CAST(ABS(ROUND((SELECT SUM(production_mt) FROM fact_crop), 0)
              - ROUND((SELECT SUM(production) FROM (SELECT DISTINCT
                    CASE WHEN UPPER(TRIM(province)) = 'NORTH COTABATO' THEN 'COTABATO' ELSE UPPER(TRIM(province)) END AS p,
                    year, quarter, crop, CAST(production AS REAL) AS production
                    FROM stg_crop)), 0)) AS INTEGER);