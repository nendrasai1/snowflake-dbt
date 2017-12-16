SELECT c.id,
           q.opportunity_id__c AS opportunity_id,
           c.zqu__rateplanname__c AS product,
           c.zqu__period__c AS period,
           c.zqu__quantity__c AS qty,
           CASE WHEN  sum(COALESCE(c.zqu__billingsubtotal__c, c.zqu__total__c)) OVER (PARTITION BY q.id) = 0 THEN 0 ELSE 
           round(o.incremental_acv_2__c * (COALESCE(c.zqu__billingsubtotal__c, c.zqu__total__c) / sum(COALESCE(c.zqu__billingsubtotal__c, c.zqu__total__c)) OVER (PARTITION BY q.id)), 4) END AS iacv,
           c.zqu__mrr__c AS mrr
    FROM sfdc.z_quote q
    JOIN sfdc.z_quoterateplan r ON r.zqu__quote__c = q.id
    JOIN sfdc.z_quoterateplancharge c ON c.zqu__quoterateplan__c = r.id
    JOIN sfdc.z_productrateplan pr ON r.zqu__productrateplan__c = pr.id
    JOIN sfdc.z_zproduct p ON pr.zqu__zproduct__c = p.id
    JOIN sfdc.opportunity o ON q.opportunity_id__c = o.id::text
    WHERE q.isdeleted = FALSE
      AND r.isdeleted = FALSE
      AND c.isdeleted = FALSE
      AND o.isdeleted = FALSE
      AND q.zqu__primary__c = TRUE