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
  IN v_mode TEXT
)
BEGIN
DECLARE v_mview_refresh_type TEXT;

DECLARE v_mview_last_refresh DATETIME default NULL;
DECLARE v_mview_refresh_period INT;

DECLARE v_got_lock TINYINT DEFAULT NULL;

DECLARE v_incremental_hwm BIGINT;
DECLARE v_refreshed_to_uow_id BIGINT;
DECLARE v_current_uow_id BIGINT;
SET v_mode = UPPER(v_mode);

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
       mview_refresh_period
  INTO v_mview_refresh_type,
       v_mview_last_refresh,
       v_incremental_hwm,
       v_refreshed_to_uow_id,
       v_mview_refresh_period
  FROM flexviews.mview
 WHERE mview_id = v_mview_id;

SELECT max(uow_id)
  INTO v_current_uow_id
  FROM flexviews.mview_uow;

SELECT GET_LOCK(CONCAT('mvlock::', v_mview_id),1)
  INTO v_got_lock;

IF v_got_lock = 1 THEN
 SET @v_start_time = NOW();

 IF v_mview_refresh_type = 'COMPLETE' THEN
   CALL flexviews.mview_refresh_complete(v_mview_id);

   UPDATE flexviews.mview
      SET mview_last_refresh=@v_start_time
    WHERE mview_id = v_mview_id;

 ELSEIF v_mview_refresh_type = 'INCREMENTAL' THEN
   DROP TEMPORARY TABLE IF EXISTS refresh_log;
   CREATE TEMPORARY TABLE refresh_log(tstamp timestamp, usec int,  message TEXT);

   -- this will recursively populate the materialized view delta table
   IF v_mode = 'BOTH' OR v_mode = 'COMPUTE' THEN
     CALL flexviews.rlog(CONCAT('-- START PROPAGATE\nCALL flexviews.execute_refresh(', v_mview_id, ',', v_incremental_hwm, ',', v_current_uow_id, ',1);'));
     CALL flexviews.execute_refresh(v_mview_id, v_incremental_hwm, v_current_uow_id, 1);    
     CALL flexviews.rlog('-- END PROPAGATE');
   END IF;  

   IF v_mode = 'BOTH' OR v_mode = 'APPLY' THEN
     -- this will apply unapplied deltas up to v_current_uow_id
     CALL flexviews.rlog(CONCAT('-- START APPLY\n',
       CONCAT('CALL flexviews.apply_delta(', v_mview_id, ',', v_current_uow_id, ');')
     ));

     CALL flexviews.apply_delta(v_mview_id, v_current_uow_id);

     UPDATE flexviews.mview
        SET refreshed_to_uow_id = v_current_uow_id, 
            mview_last_refresh = (select commit_time from flexviews.mview_uow where uow_id = v_current_uow_id)
      WHERE mview_id = v_mview_id;
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
