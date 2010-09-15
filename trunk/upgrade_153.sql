# This script only works if you are running 1.5.3b3.  If you are running an older verions, uninstall and reinstall
use flexviews;


select 'Adding new aggregate function types to the flexviews metadata' as '';
#add new aggregate function types.  note that, stddev is deprecated - stddev_pop is now used instead
ALTER TABLE mview_expression 
            MODIFY `mview_expr_type` enum('GROUP','SUM','AVG','COUNT','MIN','MAX','WHERE','PRIMARY','KEY','COLUMN','COUNT_DISTINCT','STDDEV','STDDEV_POP','VAR_POP','STDDEV_SAMP','VAR_SAMP','BIT_AND','BIT_OR','BIT_XOR', 'PERCENTILE','UNIQUE') DEFAULT 'GROUP', 
            ADD percentile tinyint default null;

select 'Update any STDDEV expressions to be STDDEV_POP expression (same result, different name)' as '';
#fix any STDDEV to be STDDEV_POP
UPDATE mview_expression set mview_expr_type = 'STDDEV_POP' WHERE mview_expr_type='STDDEV';

select 'Removing ability to add new STDDEV expressions (use STDDEV_POP)' as '';
#remove STDDEV as an available option
ALTER TABLE mview_expression 
            MODIFY `mview_expr_type` enum('GROUP','SUM','AVG','COUNT','MIN','MAX','WHERE','PRIMARY','KEY','COLUMN','COUNT_DISTINCT','STDDEV_POP','VAR_POP','STDDEV_SAMP','VAR_SAMP','BIT_AND','BIT_OR','BIT_XOR', 'PERCENTILE','UNIQUE') DEFAULT 'GROUP'; 

select 'Installing stored procedures' as '';
\. install_procs.inc
select 'upgrade done.' as '';





