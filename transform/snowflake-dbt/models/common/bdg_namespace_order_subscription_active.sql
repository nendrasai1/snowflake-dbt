{{ config(
    tags=["product"]
) }}

WITH namespace AS (

    SELECT *
    FROM {{ ref('prep_namespace') }}

), product_tier AS (

    SELECT *
    FROM {{ ref('prep_product_tier') }}

), subscription AS (

    SELECT *
    FROM {{ ref('prep_subscription') }}

), recurring_charge AS (

    SELECT *
    FROM {{ ref('prep_recurring_charge') }}

), product_detail AS (

    SELECT *
    FROM {{ ref('dim_product_detail') }}

), orders AS (

    SELECT *
    FROM {{ ref('customers_db_orders_source') }}

), trial_histories AS (

    SELECT *
    FROM {{ ref('customers_db_trial_histories_source') }}

), active_namespace_list AS (
  
    --contains non-free namespaces + prior trial namespaces.
    SELECT
      namespace.namespace_id,
      namespace.namespace_type, 
      product_tier.dim_product_tier_id                              AS dim_product_tier_id_namespace,
      product_tier.product_tier_name                                AS product_tier_name_namespace, 
      trial_histories.start_date                                    AS saas_trial_start_date,
      trial_histories.expired_on                                    AS saas_trial_expired_on,
      COALESCE(trial_histories.gl_namespace_id IS NOT NULL,
               FALSE)                                               AS namespace_was_trial
    FROM namespace
    JOIN product_tier
      ON namespace.dim_product_tier_id = product_tier.dim_product_tier_id
    LEFT JOIN trial_histories
      ON namespace.namespace_id = trial_histories.gl_namespace_id
    WHERE namespace.namespace_is_ultimate_parent = TRUE
      AND (product_tier.product_tier_name != 'Free'
           OR namespace_was_trial)


), active_subscription_list AS (
  
    --Active SaaS Subscriptions, waiting on prep_recurring_revenue
    SELECT
      subscription.dim_subscription_id,  
      saas_subscriptions.product_tier_name                          AS product_tier_name_subscription,
      saas_subscriptions.dim_product_tier_id                        AS dim_product_tier_id_subscription,
      saas_subscriptions.product_rate_plan_id                       AS product_rate_plan_id_subscription,
      subscription.dim_subscription_id_original,
      subscription.dim_subscription_id_previous,
      subscription.subscription_name,
      subscription.dim_billing_account_id,
      subscription.dim_crm_account_id,
      COUNT(*) OVER (PARTITION BY subscription.dim_subscription_id) AS count_of_tiers_per_subscription
    FROM subscription
    JOIN (
          --find only SaaS recurring charge subscriptions. Need to include OSS, EDU = Zero Rev. Add flag.
          SELECT DISTINCT
            subscription_id,
            product_detail.product_tier_name,
            product_detail.dim_product_tier_id,
            product_rate_plan_id
          FROM recurring_charge
          --new prep table will be required AND new key in prep_recurring_charge
          JOIN product_detail
            ON recurring_charge.product_details_id = product_detail.dim_product_detail_id  
          WHERE recurring_charge.date_id = TO_NUMBER(REPLACE(TO_CHAR(DATE_TRUNC('month', CURRENT_DATE)), '-', '')) --first day of current month --get Date ID
            AND product_detail.product_delivery_type IN ('SaaS', 'Self-Managed')
            AND LOWER(product_detail.product_name) NOT LIKE '%true%'
         ) saas_subscriptions
      ON subscription.dim_subscription_id = saas_subscriptions.subscription_id
    WHERE subscription.subscription_status = 'Active'
  
), product_rate_plan AS (
  
    SELECT DISTINCT
      product_rate_plan_id,
      dim_product_tier_id,
      product_tier_name,
      product_delivery_type
    FROM product_detail
    WHERE product_delivery_type IN ('SaaS', 'Self-Managed')
  
), trial_tier AS ( 
  
    SELECT
      dim_product_tier_id,
      product_tier_name,
      product_delivery_type
    FROM product_tier
    WHERE product_tier_historical IN ('SaaS - Trial: Gold', 'Self-Managed - Trial: Ultimate')

), active_orders_list AS (

    SELECT
      orders.order_id,
      orders.customer_id, 
      COALESCE(trial_tier.dim_product_tier_id,
               product_rate_plan.dim_product_tier_id)               AS dim_product_tier_id_with_trial,
      COALESCE(trial_tier.product_delivery_type,
               product_rate_plan.product_delivery_type)             AS product_delivery_type_with_trial, 
      COALESCE(trial_tier.product_tier_name,
               product_rate_plan.product_tier_name)                 AS product_tier_name_with_trial, 
      product_rate_plan.dim_product_tier_id                         AS dim_product_tier_id_order,
      product_rate_plan.product_rate_plan_id                        AS product_rate_plan_id_order,
      product_rate_plan.product_delivery_type                       AS product_delivery_type_order, 
      product_rate_plan.product_tier_name                           AS product_tier_name_order, 
      orders.subscription_id                                        AS dim_subscription_id, 
      orders.subscription_name,
      orders.order_start_date, 
      orders.order_end_date, 
      orders.gitlab_namespace_id                                    AS namespace_id,
      namespace.ultimate_parent_namespace_id,
      orders.order_is_trial
    FROM orders
    JOIN product_rate_plan
      ON orders.product_rate_plan_id = product_rate_plan.product_rate_plan_id
    LEFT JOIN namespace
      ON orders.gitlab_namespace_id = namespace.dim_namespace_id
    LEFT JOIN trial_tier 
      ON orders.order_is_trial = TRUE 
        AND (
              (product_rate_plan.product_delivery_type = 'SaaS'
               AND trial_tier.product_tier_name = 'SaaS - Trial: Gold')
             OR
              (product_rate_plan.product_delivery_type = 'Self-Managed'
               AND trial_tier.product_tier_name = 'Self-Managed - Trial: Ultimate')
             )
    WHERE orders.order_end_date >= CURRENT_DATE
      OR orders.order_end_date IS NULL
        
), final AS (

    SELECT
      active_namespace_list.namespace_id                            AS dim_namespace_id,
      active_subscription_list.dim_subscription_id, 
      active_orders_list.order_id, 
      active_orders_list.namespace_id                               AS namespace_id_order,
      active_orders_list.dim_subscription_id                        AS subscription_id_order, 
      active_namespace_list.namespace_type,
      active_namespace_list.dim_product_tier_id_namespace,
      active_namespace_list.product_tier_name_namespace, 
      active_namespace_list.saas_trial_start_date,
      active_namespace_list.saas_trial_expired_on,
      active_namespace_list.namespace_was_trial,
      active_orders_list.customer_id, 
      active_orders_list.dim_product_tier_id_with_trial,
      active_orders_list.product_delivery_type_with_trial, 
      active_orders_list.product_tier_name_with_trial, 
      active_orders_list.dim_product_tier_id_order,
      active_orders_list.product_delivery_type_order, 
      active_orders_list.product_tier_name_order, 
      active_orders_list.order_start_date, 
      active_orders_list.order_end_date, 
      active_orders_list.order_is_trial,
      active_orders_list.product_rate_plan_id_order,
      active_subscription_list.product_tier_name_subscription,
      active_subscription_list.dim_product_tier_id_subscription,
      active_subscription_list.dim_subscription_id_original,
      active_subscription_list.dim_subscription_id_previous,
      active_subscription_list.dim_billing_account_id,
      active_subscription_list.dim_crm_account_id,
      active_subscription_list.count_of_tiers_per_subscription,
      active_subscription_list.product_rate_plan_id_subscription,
      CASE
        WHEN active_namespace_list.product_tier_name_namespace = 'Free'
          THEN 'N/A Free'
        WHEN LOWER(active_namespace_list.product_tier_name_namespace) LIKE '%trial%'
          AND active_orders_list.order_id IS NULL
          THEN 'Trial Namespace Missing Active Order' 
        WHEN active_namespace_list.product_tier_name_namespace IN ('Bronze', 'Silver', 'Gold')
          AND active_orders_list.order_id IS NULL
          THEN 'Paid Namespace Missing Active Order' 
        WHEN active_namespace_list.product_tier_name_namespace IN ('Bronze', 'Silver', 'Gold')
          AND active_orders_list.dim_subscription_id IS NULL
          THEN 'Paid Namespace Missing Order Subscription' 
        WHEN active_namespace_list.product_tier_name_namespace IN ('Bronze', 'Silver', 'Gold')
          AND active_subscription_list.dim_subscription_id IS NULL
          THEN 'Paid Namespace Missing Zuora Subscription' 
        WHEN active_orders_list.dim_subscription_id IS NOT NULL
          AND active_namespace_list.namespace_id IS NULL
          THEN 'Paid Order Missing Namespace ID Assignment'
        WHEN active_orders_list.order_id IS NOT NULL
          AND active_orders_list.namespace_id IS NULL
          THEN 'Free Order Missing Namespace ID Assignment' 
        WHEN active_subscription_list.dim_subscription_id IS NOT NULL
          AND active_orders_list.order_id IS NULL
          THEN 'Paid Subscription Missing Order'
        WHEN active_orders_list.ultimate_parent_namespace_id != active_orders_list.namespace_id
          THEN 'Order Linked to Non-Ultimate Parent Namespace'
        WHEN active_namespace_list.namespace_id IS NOT NULL
          AND active_orders_list.dim_subscription_id IS NOT NULL
          AND active_subscription_list.dim_subscription_id IS NOT NULL
          THEN 'Paid All Matching'
        WHEN LOWER(active_namespace_list.product_tier_name_namespace) LIKE '%trial%'
          AND active_orders_list.order_id IS NOT NULL
          THEN 'Trial All Matching'
        WHEN active_orders_list.order_id IS NOT NULL
          AND active_namespace_list.namespace_id IS NULL
          THEN 'Order Namespace Not Found'
      END                                                           AS namespace_order_subscription_match_status
    FROM active_namespace_list
    FULL OUTER JOIN active_orders_list
      ON active_namespace_list.namespace_id = active_orders_list.namespace_id
      OR active_namespace_list.namespace_id = active_orders_list.ultimate_parent_namespace_id
    FULL OUTER JOIN active_subscription_list
      ON active_orders_list.dim_subscription_id = active_subscription_list.dim_subscription_id
      OR active_orders_list.dim_subscription_id = active_subscription_list.dim_subscription_id_original
      OR active_orders_list.dim_subscription_id = active_subscription_list.dim_subscription_id_previous     
      OR active_orders_list.subscription_name = active_subscription_list.subscription_name --using name JOIN until slug or other field is available in all tables.   
        
)

{{ dbt_audit(
    cte_ref="final",
    created_by="@ischweickartDD",
    updated_by="@ischweickartDD",
    created_date="2021-01-14",
    updated_date="2021-01-14"
) }}