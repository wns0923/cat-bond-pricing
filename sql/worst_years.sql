SELECT sim_year, max_loss_bn,
       RANK() OVER (ORDER BY max_loss_bn DESC) AS loss_rank
FROM sim_years WHERE run_id = 1
ORDER BY loss_rank LIMIT 10;
