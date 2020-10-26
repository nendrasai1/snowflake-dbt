WITH usage_ping_data AS (

    SELECT {{ hash_sensitive_columns('version_usage_data_source') }}
    FROM {{ ref('version_usage_data_source') }}
    WHERE uuid IS NOT NULL

), licenses AS (

    SELECT *
    FROM {{ ref('dim_licenses') }}
    
    
), version_edition_cleaned AS (

     SELECT
        usage_ping_data.*,
        {{ get_date_id('usage_ping_data.created_at') }}              AS created_date_id,
        REGEXP_REPLACE(NULLIF(version, ''), '\-.*')                  AS cleaned_version,
        SPLIT_PART(cleaned_version, '.', 1)                          AS major_version,
        SPLIT_PART(cleaned_version, '.', 2)                          AS minor_version,
        IFF(
            version LIKE '%-pre%' OR version LIKE '%-rc%', 
            TRUE, FALSE
        )::BOOLEAN                                                   AS is_pre_release,
        IFF(edition = 'CE', 'CE', 'EE')                              AS main_edition,
        CASE 
            WHEN edition = 'CE'                                   THEN 'CE'
            WHEN edition = 'EE Free'                              THEN 'Core'                                                      
            WHEN license_expire_date < usage_ping_data.created_at THEN 'Core'
            WHEN edition = 'EE'                                   THEN 'Starter'
            WHEN edition = 'EES'                                  THEN 'Starter'
            WHEN edition = 'EEP'                                  THEN 'Premium'
            WHEN edition = 'EEU'                                  THEN 'Ultimate'
            ELSE NULL END                                            AS product_tier,
        CASE edition
            WHEN 'CE' THEN product_tier
            WHEN 'EE' THEN main_edition || ' - ' || product_tier  
            ELSE NULL END                                            AS main_edition_product_tier, 
        IFF( uuid = 'ea8bf810-1d6f-4a6a-b4fd-93e8cbd8b57f',
                'SaaS','Self-Managed')                               AS ping_source
    FROM usage_ping_data
    LEFT JOIN licenses
      ON usage_ping_data.license_md5 = licenses.license_md5

), internal_identified AS (

    SELECT 
        *, 
        CASE
            WHEN installation_type = 'gitlab-development-kit' THEN TRUE 
            WHEN hostname = 'gitlab.com' THEN TRUE 
            WHEN hostname ILIKE '%.gitlab.com' THEN TRUE 
            ELSE FALSE END                                           AS is_internal, 
        IFF(hostname ilike '%staging%', TRUE, FALSE)                 AS is_staging
    FROM version_edition_cleaned

), ip_to_geo AS (

    SELECT *
    FROM {{ ref('dim_ip_to_geo') }}

), joined AS (

    SELECT *,
      ip_to_geo.location_id  AS geo_location_id 
    FROM internal_identified
    LEFT JOIN ip_to_geo
      ON internal_identified.source_ip_hash = ip_to_geo.ip_address_hash

), renamed AS (

   SELECT 
    *
   FROM joined

)

SELECT * 
FROM renamed
