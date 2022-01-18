{{ config(
    tags=["people", "edcast"]
) }}


WITH source AS (

  SELECT *
  FROM {{ source('edcast', 'datasets') }}

), renamed AS (

  SELECT
    id::VARCHAR                AS id,
    name::varchar              AS name,
    columns::NUMBER            AS number_of_columns,
    created_at::TIMESTAMP      AS created_at,
    data_current_at::TIMESTAMP AS data_current_at,
    pdp_enabled::BOOLEAN       AS pdp_enabled,
    "rows"::NUMBER             AS number_of_rows,
    owner__id::NUMBER          AS owner_id,
    owner__name::VARCHAR       AS owner_name,
    updated_at::TIMESTAMP      AS updated_at,
    __loaded_at::TIMESTAMP     AS __loaded_at
  FROM source

)

SELECT *
FROM renamed
