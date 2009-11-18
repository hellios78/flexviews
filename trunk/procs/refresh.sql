DELIMITER ;;
/*  Flexviews for MySQL 
    Copyright 2008 Justin Swanhart

    FlexViews is free software: you can redistribute it and/or modify
    it under the terms of the Lesser GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    FlexViews is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with FlexViews in the file COPYING, and the Lesser extension to
    the GPL (the LGPL) in COPYING.LESSER.
    If not, see <http://www.gnu.org/licenses/>.
*/

DROP PROCEDURE IF EXISTS flexviews.refresh ;;

CREATE DEFINER=flexviews@localhost PROCEDURE flexviews.refresh(
  IN v_mview_id INT,
  IN v_mode TEXT,
  IN v_uow_id BIGINT 
)
BEGIN
DECLARE v_mview_refresh_type TEXT;

DECLARE v_mview_last_refresh DATETIME default NULL;
DECLARE v_mview_refresh_period INT;

DECLARE v_got_lock TINYINT DEFAULT NULL;

DECLARE v_incremental_hwm BIGINT;
DECLARE v_refreshed_to_uow_id BIGINT;
DECLARE v_current_uow_id BIGINT;

DECLARE v_child_mview_id INT DEFAULT NULL;

DECLARE v_sql TEXT DEFAULT '';

DECLARE v_signal_id BIGINT DEFAULT NULL;

DECLARE v_mview_schema TEXT;
DECLARE v_mview_name TEXT;

DECLARE v_pos INT;

SET v_mode = UPPER(v_mode);

SET max_sp_recursion_depth=9999;

IF NOT flexviews.is_enabled(v_mview_id) = 1 THEN
    CALL flexviews.signal('MV_NOT_ENABLED');
END IF;


IF v_mode != 'COMPLETE' AND v_mode != 'FULL' AND v_mode != "BOTH" and v_mode != "COMPUTE" and v_mode != "APPLY" THEN
  call flexviews.signal('INVALID_REFRESH_MODE');
END IF;

IF v_mode = 'FULL' THEN SET v_mode = 'BOTH'; END IF;

-- get the table name and schema of the given mview_id
SELECT mview_refresh_type,
       mview_last_refresh, 
       incremental_hwm,
       refreshed_to_uow_id,
       mview_refresh_period,
       mview_schema, 
       mview_name,
       created_at_signal_id
  INTO v_mview_refresh_type,
       v_mview_last_refresh,
       v_incremental_hwm,
       v_refreshed_to_uow_id,
       v_mview_refresh_period, 
       v_mview_schema, 
       v_mview_name,
       v_signal_id
  FROM flexviews.mview
 WHERE mview_id = v_mview_id;

SET @min_uow_id := NULL;

IF v_signal_id IS NOT NULL AND v_refreshed_to_uow_id IS NULL THEN
  START TRANSACTION;

  SELECT uow_id
    INTO v_refreshed_to_uow_id
    FROM flexviews.mview_signal_mvlog
   WHERE signal_id = v_signal_id;

   
   UPDATE flexviews.mview mv
     JOIN flexviews.mview_uow uow
       ON uow.uow_id = v_refreshed_to_uow_id
      AND mv.mview_id = v_mview_id
      SET refreshed_to_uow_id = uow.uow_id,
          incremental_hwm = uow.uow_id,
          mview_last_refresh = uow.commit_time; 

   COMMIT;

   -- refresh these variables as they may have been changed by our UPDATE statement
   SELECT 
       mview_last_refresh, 
       incremental_hwm,
       refreshed_to_uow_id
  INTO v_mview_last_refresh,
       v_incremental_hwm,
       v_refreshed_to_uow_id
  FROM flexviews.mview
 WHERE mview_id = v_mview_id;

END IF;

-- EXIT the refresh process if the consumer has not caught up to the point
-- where the view is possible to be refreshed

IF v_refreshed_to_uow_id IS NULL THEN
  call flexviews.signal('CONSUMER_IS_BEHIND');
END IF;

SELECT mview_id
  INTO v_child_mview_id
  FROM mview
 WHERE parent_mview_id = v_mview_id;

-- TODO: remove the IF block.  
-- This used to be protected by a GET_LOCK(), but this is not necessary
-- with the external binlog consumer.
IF TRUE THEN
 SET @v_start_time = NOW();

 
 IF v_mview_refresh_type = 'COMPLETE' THEN
   CALL flexviews.mview_refresh_complete(v_mview_id);

   UPDATE flexviews.mview
      SET mview_last_refresh=@v_start_time
    WHERE mview_id = v_mview_id;

 ELSEIF v_mview_refresh_type = 'INCREMENTAL' THEN
 
   SET v_current_uow_id = v_uow_id;

   -- IF v_uow_id is null, then that means refresh to NOW.
   -- You can't refresh backward in time (YET!) so refresh to NOW
   -- if an older/invalid uow_id is given 
   IF v_current_uow_id IS NULL OR v_current_uow_id < v_incremental_hwm THEN 
     -- By default we refresh to the latest available unit of work
     SELECT max(uow_id)
       INTO v_current_uow_id
       FROM flexviews.mview_uow;
   END IF;

   -- this will recursively populate the materialized view delta table
   IF v_mode = 'BOTH' OR v_mode = 'COMPUTE' THEN
     CALL flexviews.rlog(CONCAT('-- START PROPAGATE\nCALL flexviews.execute_refresh(', v_mview_id, ',', v_incremental_hwm, ',', v_current_uow_id, ',1);'));
     IF v_child_mview_id IS NOT NULL THEN
       BEGIN
       DECLARE v_incremental_hwm BIGINT;

         -- The incremental high water mark of the dependent table may be different from 
         -- the parent table, so explicity fetch it to make sure we don't push the wrong
         -- values into the mview
         SELECT incremental_hwm
           INTO v_incremental_hwm
           FROM mview
          WHERE mview_id = v_child_mview_id;

          CALL flexviews.execute_refresh(v_child_mview_id, v_incremental_hwm, v_current_uow_id, 1);
        END;
     END IF;
     CALL flexviews.execute_refresh(v_mview_id, v_incremental_hwm, v_current_uow_id, 1);    
     CALL flexviews.rlog('-- END PROPAGATE');
   END IF;  

   IF v_mode = 'BOTH' OR v_mode = 'APPLY' THEN
     -- this will apply unapplied deltas up to v_current_uow_id
     CALL flexviews.rlog(CONCAT('-- START APPLY\n',
       CONCAT('CALL flexviews.apply_delta(', v_mview_id, ',', v_current_uow_id, ');')
     ));

     BEGIN 
     DECLARE v_child_mview_name TEXT;
     DECLARE v_agg_set TEXT;

       IF v_child_mview_id IS NOT NULL THEN
       	 CALL flexviews.apply_delta(v_child_mview_id, v_current_uow_id);

         UPDATE flexviews.mview
            SET mview_last_refresh = (select commit_time from flexviews.mview_uow where uow_id = v_current_uow_id)
          WHERE mview_id = v_child_mview_id;


	 SELECT CONCAT(mview_schema, '.', mview_name)
           INTO v_child_mview_name
           FROM flexviews.mview
          WHERE mview_id = v_child_mview_id;

         SELECT group_concat(concat('`' , v_mview_name, '`.`',mview_alias,'` = `x_alias`.`',mview_alias, '`'),'\n,')
           INTO v_agg_set
           FROM flexviews.mview_expression 
          WHERE mview_id = v_mview_id
            AND mview_expr_type in('MIN','MAX','COUNT_DISTINCT');
         
         SET v_agg_set = LEFT(v_agg_set, LENGTH(v_agg_set)-1);

         SET v_sql = CONCAT('UPDATE ', v_mview_schema, '.', v_mview_name, '\n',
                            '  JOIN (\n', 
                            'SELECT ', get_child_select(v_mview_id, 'cv'), '\n',
                            '  FROM ', v_child_mview_name, ' as cv\n', 
                            '  JOIN ', v_mview_schema, '.', v_mview_name, '_delta as pv \n ', 
                            ' USING (', get_delta_aliases(v_mview_id, '', true), ')\n',  
                            
                            ' GROUP BY ', get_delta_aliases(v_mview_id, 'cv', true), 
                            ') x_alias \n'
                            'USING (', get_delta_aliases(v_mview_id, '', true), ')\n',
                            '   SET ', v_agg_set , '\n'
                           );
	 SET @J = v_sql;
         SET @v_sql = v_sql;
         PREPARE update_stmt from @v_sql;
         EXECUTE update_stmt;   
         DEALLOCATE PREPARE update_stmt;
      END IF;


      CALL flexviews.apply_delta(v_mview_id, v_current_uow_id);
      UPDATE flexviews.mview
         SET mview_last_refresh = (select commit_time from flexviews.mview_uow where uow_id = v_current_uow_id)
       WHERE mview_id = v_mview_id;
                            
    END;
  END IF;
 ELSE
   CALL flexviews.signal(' XYZ UNSUPPORTED REFRESH METHOD'); 
 END IF;
ELSE
 IF v_got_lock = 1 THEN
  SELECT CONCAT('Refresh period not exceeded.  no refresh performed') as "Message"; 
 ELSE
  SELECT CONCAT('Could not obtain a refresh lock - refresh in progress or locking error') as "Message";
 END IF;
END IF; 

END ;;

DELIMITER ;
