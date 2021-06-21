{%- set event_ctes = [
  {
    "event_name": "usage_activity_by_stage_monthly.manage.events",
    "source_cte_name": "dim_event",
    "user_column_name": "dim_user_id",
    "namespace_column_name": "ultimate_parent_namespace_id",
    "project_column_name": "dim_project_id",
    "primary_key": "dim_event_id",
    "lowest_grain_available": "project"
  }
]

-%}

{{ simple_cte([
    ('dim_event', 'dim_event'),
    ('dim_project', 'dim_project'),
    ('dim_namespace', 'dim_namespace'),
    ('prep_user', 'prep_user')
]) }}

, data AS (

{% for event_cte in event_ctes %}

    SELECT
      MD5({{ event_cte.source_cte_name}}.{{ event_cte.primary_key }} || '-' || '{{ event_cte.event_name }}')   AS event_primary_key,
      '{{ event_cte.event_name }}'                                                                             AS event_name,
      {% if event_cte.project_column_name != 'NULL' %}
      {{ event_cte.source_cte_name}}.{{ event_cte.project_column_name }},
      {% endif %}
      {{ event_cte.source_cte_name}}.ultimate_parent_namespace_id,
      {{ event_cte.source_cte_name}}.dim_plan_id,
      {{ event_cte.source_cte_name}}.created_at,
      {{ event_cte.source_cte_name}}.created_date_id,
      {{ event_cte.source_cte_name}}.{{ event_cte.user_column_name }} AS dim_user_id,
      prep_user.created_at AS user_created_at,
      FLOOR(
      DATEDIFF('hour',
              dim_namespace.created_at,
              {{ event_cte.source_cte_name}}.created_at)/24)                       AS days_since_namespace_creation,
      FLOOR(
      DATEDIFF('hour',
              prep_user.created_at,
              {{ event_cte.source_cte_name}}.created_at)/24)                       AS days_since_user_creation,
      {% if event_cte.project_column_name != 'NULL' %}
      FLOOR(
      DATEDIFF('hour',
              dim_project.created_at,
              {{ event_cte.source_cte_name}}.created_at)/24)                       AS days_since_user_creation,
      {% endif %} 

      dim_project.is_imported AS project_is_imported
    FROM {{ event_cte.source_cte_name }}
    {% if event_cte.project_column_name != 'NULL' %}
    LEFT JOIN dim_project 
      ON {{event_cte.source_cte_name}}.{{event_cte.project_column_name}} = dim_project.dim_project_id
    {% endif %}
    {% if event_cte.namespace_column_name != 'NULL' %}
    LEFT JOIN dim_namespace 
      ON {{event_cte.source_cte_name}}.{{event_cte.namespace_column_name}} = dim_namespace.dim_namespace_id
    {% endif %}
    {% if event_cte.user_column_name != 'NULL' %}
    LEFT JOIN prep_user 
      ON {{event_cte.source_cte_name}}.{{event_cte.user_column_name}} = prep_user.dim_user_id
    {% endif %}
    {% if not loop.last %}
    UNION
    {% endif %}
    {% endfor -%}

)

SELECT *
FROM data
