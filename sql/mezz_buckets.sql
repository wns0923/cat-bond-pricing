SELECT CASE WHEN l = 0 THEN '0%' WHEN l < 0.25 THEN '0-25%' WHEN l < 0.5 THEN '25-50%'
            WHEN l < 1 THEN '50-100%' ELSE '100%' END AS bucket,
       COUNT(*) AS years
FROM (SELECT MIN(1.0, MAX(0.0, (s.max_loss_bn - t.attach_bn) / (t.exhaust_bn - t.attach_bn))) AS l
      FROM sim_years s JOIN tranches t ON t.name = 'Mezzanine'
      WHERE s.run_id = 1)
GROUP BY bucket;
