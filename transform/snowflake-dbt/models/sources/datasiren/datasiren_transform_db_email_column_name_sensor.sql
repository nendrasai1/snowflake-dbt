{{ config({
        "materialized": "incremental"
    })
}}

{{ datasiren.email_column_name_sensor(env_var('SNOWFLAKE_PROD_DATABASE')) }}
