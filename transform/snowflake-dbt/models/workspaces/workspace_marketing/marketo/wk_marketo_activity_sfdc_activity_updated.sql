WITH source AS (

    SELECT *
    FROM {{ ref('marketo_activity_sfdc_activity_updated_source') }}

)

SELECT *
FROM source