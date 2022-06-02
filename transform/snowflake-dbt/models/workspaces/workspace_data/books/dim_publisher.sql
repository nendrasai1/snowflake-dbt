WITH source AS (

  SELECT 
    --Primary Key
      {{ dbt_utils.surrogate_key([publisher]) }} AS dim_publisher_key, 
      publisher
  FROM {{ ref('sheetload_books') }}

)

{{ dbt_audit(
    cte_ref="source",
    created_by="@lisvinueza",
    updated_by="@lisvinueza",
    created_date="2022-06-02",
    updated_date="2022-06-02"
) }}