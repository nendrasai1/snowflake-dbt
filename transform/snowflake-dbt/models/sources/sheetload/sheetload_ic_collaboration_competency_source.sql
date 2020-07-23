{{
    config({
      "schema": "sensitive"
    })
}}

WITH source AS (

    SELECT *
    FROM {{ source('sheetload', 'ic_collaboration_competency') }}

), renamed as (

    SELECT
      "Timestamp"::TIMESTAMP::DATE                                                                 AS date_completed,
      "Score"                                                                                      AS score,
      "First_name" ||' ' || "Last_Name"                                                            AS submitter_name,
      "Email_address_(GitLab_team_members,_please_use_your_GitLab_email_address)"::STRING          AS submitter_email,
      "_UPDATED_AT"                                                                                AS last_updated_at
    FROM source

)

SELECT *
FROM renamed

