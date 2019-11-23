WITH source AS (

  SELECT *
  FROM {{ source('gitlab_dotcom', 'members') }}

), source_distinct AS (

  SELECT
    {{ dbt_utils.star(from=source('gitlab_dotcom', 'members'), except=["_UPLOADED_AT", "_TASK_INSTANCE"]) }},
    MIN(DATEADD('sec', _uploaded_at, '1970-01-01')) AS valid_from,
    MAX(_task_instance) AS max_task_instance
  FROM source
  GROUP BY {{ dbt_utils.star(from=source('gitlab_dotcom', 'members'),  except=["_UPLOADED_AT", "_TASK_INSTANCE"]) }}

), renamed AS (

    SELECT DISTINCT

      id::INTEGER                                    AS member_id,
      access_level::INTEGER                          AS access_level,
      source_id::INTEGER                             AS source_id,
      source_type                                    AS member_source_type,
      user_id::INTEGER                               AS user_id,
      notification_level::INTEGER                    AS notification_level,
      type                                           AS member_type,
      created_at::TIMESTAMP                          AS invite_created_at,
      created_by_id::INTEGER                         AS created_by_id,
      invite_accepted_at::TIMESTAMP                  AS invite_accepted_at,
      requested_at::TIMESTAMP                        AS requested_at,
      expires_at::TIMESTAMP                          AS expires_at,
      ldap::BOOLEAN                                  AS has_ldap,
      override::BOOLEAN                              AS has_override,
      valid_from

    FROM source_distinct

)

{{ scd_type_6(
    primary_key='member_id',
    primary_key_raw='id',
    source_cte='source_distinct',
    source_timestamp='valid_from',
    casted_cte='renamed'
) }}
