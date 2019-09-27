WITH source AS (

    SELECT *
    FROM {{ source('netsuite', 'subsidiaries') }}

), renamed AS (

    SELECT subsidiary_id::float               AS subsidiary_id,
           full_name::varchar                 AS subsidiary_full_name,
           name::varchar                      AS subsidiary_name,
           base_currency_id::float            AS base_currency_id,
           isinactive::boolean                AS is_subsidiary_inactive,
           is_elimination::boolean            AS is_elimination_subsidiary

    FROM source

)

SELECT *
FROM renamed
