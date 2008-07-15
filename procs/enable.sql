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

DROP PROCEDURE IF EXISTS enable;;

CREATE DEFINER=flexviews@localhost PROCEDURE  `enable`(
  IN v_mview_id INT
)
BEGIN
  DECLARE v_mview_enabled tinyint(1);
  DECLARE v_mview_refresh_type TEXT;
  DECLARE v_mview_engine TEXT;
  DECLARE v_mview_name TEXT;
  DECLARE v_mview_schema TEXT;
  DECLARE v_mview_definition TEXT;
  DECLARE v_keys TEXT;

  DECLARE v_sql TEXT;

  SELECT mview_name, 
         mview_schema, 
	 mview_enabled, 
         mview_refresh_type,
         mview_engine,
         mview_definition
    INTO v_mview_name, 
         v_mview_schema, 
         v_mview_enabled, 
         v_mview_refresh_type, 
         v_mview_engine,
         v_mview_definition
    FROM flexviews.mview
   WHERE mview_id = v_mview_id;
    IF v_mview_id IS NULL THEN
     CALL flexviews.signal('The specified materialized view does not exist');
    END IF;

   IF v_mview_enabled = TRUE THEN
     CALL flexviews.signal('This materialized view is already enabled');
   END IF;


   SET v_sql = CONCAT('DROP TABLE IF EXISTS ', v_mview_schema, '.', v_mview_name);
   SET @v_sql = v_sql;
   PREPARE drop_stmt FROM @v_sql; 
   EXECUTE drop_stmt;
   DEALLOCATE PREPARE drop_stmt;
   SET v_sql = '';
   SET @v_sql = v_sql;

   SET v_sql = CONCAT('CREATE TABLE ', v_mview_schema, '.', v_mview_name );
   -- Add any definied keys on the table.  This function will automatically provide a suitable primary 
   -- key for the table if no primary key has been manually specified.  This key will be in the column
   -- order of GROUP expressions in the table which may not be ideal for selecting, so care should be 
   -- taken if a PRIMARY KEY is not provided to present the GROUP expressions in a suitable order..
   
   -- note: special refresh REQUIRES a PRIMARY KEY definition and an error will be raised if one has
   -- not been provided

   SET v_keys = mview_get_keys(v_mview_id);

   IF v_keys != "" THEN
     SET v_sql = CONCAT(v_sql, '(', v_keys,')\n');
   END IF;

   IF v_mview_refresh_type != 'INCREMENTAL' THEN
     SET v_sql = CONCAT(v_sql, ' AS ', v_mview_definition);
     SET @v_sql = v_sql;
   ELSE
     CALL flexviews.ensure_validity(v_mview_id);
     SET @HERE=1;
   -- SET v_sql = CONCAT('CREATE TABLE ', v_mview_schema, '.', v_mview_name, '(', char(10));


   -- SET v_sql = CONCAT(v_sql, mview_get_keys(v_mview_id) ,')', char(10));

   SET v_sql = CONCAT(v_sql, 'ENGINE=INNODB ');
   SET v_sql = CONCAT(v_sql, 'AS (', char(10));
   SET v_sql = CONCAT(v_sql, mview_get_select_list(v_mview_id, 'CREATE',''), char(10));
   SET v_sql = CONCAT(v_sql, mview_get_from_clause(v_mview_id, 'JOIN', ''));

   -- TODO: add mview_get_where_clause and use it here
   -- IF v_mview_filter IS NOT NULL THEN
   --  SET v_sql = CONCAT(v_sql, v_mview_get_where_clause(v_mview_id), char(10));
   -- END IF;

   SET v_sql = CONCAT(v_sql, IF(flexviews.has_aggregates(v_mview_id) = true, ' GROUP BY ', ''), flexviews.get_delta_groupby(v_mview_id), char(10)); 
   SET v_sql = CONCAT(v_sql, ');');
   -- SET @v_sql = mview_tokenizer(v_mview_id, v_sql);
   SET @v_sql = v_sql;
END IF;
   PREPARE create_stmt FROM @v_sql;
   SET @tstamp = NOW(); 
   EXECUTE create_stmt;
   DEALLOCATE PREPARE create_stmt;

  
    -- INCREMENTALLY REFRESHED MATERIALIZED VIEWS HAVE A DELTA TABLE
    -- WHERE PROPAGATE CHANGES ARE APPLIED, THEN THE REFRESH PROCESS
    -- APPLIES THE DELTAS TO THE MV 
    IF v_mview_refresh_type = 'INCREMENTAL' THEN
      UPDATE flexviews.mview
         SET mview_last_refresh = @tstamp,
             incremental_hwm = flexviews.uow_from_dtime(@tstamp),
             refreshed_to_uow_id = incremental_hwm,
             mview_enabled = 1
       WHERE mview_id = v_mview_id;

      SET v_sql = CONCAT('DROP TABLE IF EXISTS ', v_mview_schema, '.', v_mview_name, '_delta');
      SET @v_sql = v_sql;  
      PREPARE drop_stmt FROM @v_sql;
      EXECUTE drop_stmt;
      DEALLOCATE PREPARE drop_stmt;

      SET @v_sql = v_sql;  
      PREPARE replace_stmt FROM @v_sql;
      EXECUTE replace_stmt;
      DEALLOCATE PREPARE replace_stmt;

      SET v_sql = CONCAT('CREATE TABLE ', v_mview_schema, '.', v_mview_name, '_delta( dml_type INT, uow_id BIGINT,KEY(uow_id))', char(10));
      SET v_sql = CONCAT(v_sql, 'ENGINE=INNODB ');
      SET v_sql = CONCAT(v_sql, 'AS ( SELECT * FROM ', v_mview_schema, '.', v_mview_name, ' WHERE 0=1 LIMIT 1)');
      SET @v_sql = v_sql;
      PREPARE create_stmt FROM @v_sql;
      EXECUTE create_stmt;
      DEALLOCATE PREPARE create_stmt;
    END IF;
END ;;

DELIMITER ;
