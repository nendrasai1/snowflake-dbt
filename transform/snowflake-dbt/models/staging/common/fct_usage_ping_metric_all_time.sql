WITH usage_data AS (

    SELECT *
    FROM {{ ref('version_usage_data_source') }}
    WHERE uuid IS NOT NULL

), unpacked_stages AS (
    
    SELECT
      usage_data.*,
      f.key                                                              AS stage_name,
      f.value                                                            AS stage_activity_count_json

    FROM usage_data,
      lateral flatten(input => usage_data.usage_activity_by_stage) f

), unpacked_metric_names AS (

    SELECT 
      unpacked_stages.*,
      data.key                 AS metric_name,
      data.value               AS metric_value
    FROM unpacked_stages,
      lateral flatten(input => unpacked_stages.stage_activity_count_json) data

), renamed_activity_by_stage AS (

    SELECT
      id          AS usage_ping_id,
      recorded_at AS recorded_at,
      stage_name,
      metric_name,
      metric_value
    FROM unpacked_metric_names

), stats_used_mappings AS (
    
    SELECT
      full_metrics_path,
      stage
    FROM ref('test_metrics_renaming')

), stats_used AS (

    SELECT
      usage_data.*,
      f.key                     AS metric_name,
      f.value                   AS metric_value
    FROM usage_data,
      lateral flatten(input => usage_data.stats_used) f

), joined_stats_info AS (

    SELECT
      id            AS usage_ping_id,
      recorded_at   AS recorded_at,
      stage_name,
      metric_name,
      metric_value
    FROM stats_used
    INNER JOIN 

)

SELECT *
FROM renamed

