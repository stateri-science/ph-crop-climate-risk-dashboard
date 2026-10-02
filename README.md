# Philippine Crop and Climate Risk Dashboard

SQL data pipeline and Power BI dashboard on Philippine crop production, weather and ENSO conditions, 2010 to 2025.

## Overview

This project turns two raw, messy files into a clean star schema and a dashboard that shows how crop production changes across provinces, crops and time, and how it relates to rainfall, temperature and El Niño and La Niña conditions.

SQL does the processing work (joining, deduplicating, window functions, validation). Power BI is the presentation layer.

## Questions the dashboard will answer

- How has production changed by crop group and province since 2011?
- Which provinces and crops show the sharpest year over year declines?
- Do El Niño and La Niña quarters differ from neutral quarters in production growth?
- Where is climate stress highest?

## Data

**Philippine Crop Trend Risk Data, 2010 to 2025** (Kaggle). Province quarter crop production in metric tons, with weather covariates and ENSO context.

| File | Description |
|---|---|
| `crop_trend_master_2025q4.csv` | Main table: 167,699 rows, 53 provinces, 89 crops |
| `province_quarterly_weather_ready_for_merge_2010_2025.csv` | Weather and ENSO by province and quarter |
| `data_dictionary.csv` | Column definitions and units |

The raw files are not stored in this repository. See [`https://www.kaggle.com/datasets/josiahdanielcatabay/cropforecast-ph-crop-trend-risk-2010-2025`) for the download link.

**Attribution:** Weather fields are modeled data, not station readings. The dataset's `risk_label` is a heuristic from its author's pipeline and not an official classification.

## Data quality issues found and how they are handled

| Issue | Handling |
|---|---|
| Province case and period formats differ between files | Uppercase and trim; extract the quarter number |
| Two weather series for South Cotabato in the weather file, which duplicated crop rows in the master | Average to one series per province quarter; deduplicate before aggregating |
| Pepper bell has two production values per key | Sum production |
| NORTH COTABATO and COTABATO are the same province under two labels | Merge into COTABATO |
| Rolling anomalies and climate stress in the master were computed across crop rows | Recompute over province quarters using the data dictionary formulas |
| Lag and year over year growth inherited the duplicates | Recompute from the cleaned fact table |
| 2010 is almost empty | Keep but flag; dashboard covers 2011 to 2025 |
| Uneven province history (Davao ends 2022; two provinces appear only in 2025) | Flag columns in `dim_province` |

The original risk label is replaced by a transparent year over year growth band.

## Data model

Star schema:

- Facts: `fact_crop_metrics`, `fact_weather`
- Dimensions: `dim_province`, `dim_crop`, `dim_date`

## Tech stack

SQLite, Power BI, Git and GitHub.

## Repository structure

```
sql/        numbered scripts: staging, cleaning, model, validation, export
powerbi/    dashboard file and exported images
docs/       screenshots and data notes
data/raw/   download instructions only
```

## Limitations

- Weather data is modeled and aggregated to the province.
- Province boundaries changed during the period.
- Production is in metric tons for every crop, but sums across crops are dominated by palay, so compare within a crop group.

## Roadmap

- [x] Audit raw data and design the cleaning rules
- [ ] SQLite scripts
- [ ] Data model and validation
- [ ] Power BI dashboard
- [ ] Dashboard screenshots and findings

## Author

Erica Jean Fortu, BS Statistics, Polytechnic University of the Philippines, Manila.
