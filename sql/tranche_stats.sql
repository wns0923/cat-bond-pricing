SELECT t.name,
       AVG(MIN(1.0, MAX(0.0, (s.max_loss_bn - t.attach_bn) / (t.exhaust_bn - t.attach_bn)))) AS expected_loss,
       AVG(s.max_loss_bn > t.attach_bn)   AS p_attach,
       AVG(s.max_loss_bn >= t.exhaust_bn) AS p_exhaust
FROM sim_years s CROSS JOIN tranches t
WHERE s.run_id = 1
GROUP BY t.tranche_id, t.name;
