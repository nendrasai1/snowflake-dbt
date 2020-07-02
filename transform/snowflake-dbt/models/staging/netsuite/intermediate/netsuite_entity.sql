{{ config({
    "materialized": "ephemeral"
    })
}}

WITH source AS (

    SELECT *
    FROM {{ ref('netsuite_entity_source') }}

)

SELECT *
FROM source
WHERE is_fivetran_deleted = FALSE