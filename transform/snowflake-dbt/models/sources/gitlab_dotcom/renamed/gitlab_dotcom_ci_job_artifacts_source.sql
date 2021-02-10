{{ config({
        "materialized": "view"
        })
    }}

WITH source AS (

  SELECT *
  FROM {{ ref('gitlab_dotcom_ci_job_artifacts_dedupe_source') }}

  {% if is_incremental() %}

  WHERE updated_at >= (SELECT MAX(updated_at) FROM {{this}})

  {% endif %}
  
), renamed AS (

  SELECT 
    id::NUMBER           AS ci_job_artifact_id, 
    project_id::NUMBER   AS project_id, 
    job_id::NUMBER       AS ci_job_id, 
    file_type             AS file_type, 
    size                  AS size, 
    created_at::TIMESTAMP AS created_at, 
    updated_at::TIMESTAMP AS updated_at, 
    expire_at::TIMESTAMP  AS expire_at, 
    file                  AS file, 
    file_store            AS file_store, 
    file_format           AS file_format, 
    file_location         AS file_location 

  FROM source

)


SELECT *
FROM renamed
ORDER BY updated_at
