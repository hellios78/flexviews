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

DROP PROCEDURE IF EXISTS flexviews.disable;;

CREATE DEFINER=`flexviews`@`localhost` PROCEDURE flexviews.`disable`(
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

   IF v_mview_enabled = FALSE THEN
     CALL flexviews.signal('This materialized view is already disabled');
   END IF;

   SET v_sql = CONCAT('DROP TABLE IF EXISTS ', v_mview_schema, '.', v_mview_name);
   SET @v_sql = v_sql;
   PREPARE drop_stmt FROM @v_sql; 
   EXECUTE drop_stmt;
   DEALLOCATE PREPARE drop_stmt;

   SET v_sql = CONCAT('DROP TABLE IF EXISTS ', v_mview_schema, '.', v_mview_name, '_delta');
   SET @v_sql = v_sql;
   PREPARE drop_stmt FROM @v_sql; 
   EXECUTE drop_stmt;
   DEALLOCATE PREPARE drop_stmt;

   UPDATE flexviews.mview
      SET mview_last_refresh = NULL,
          mview_enabled = FALSE
    WHERE mview_id = v_mview_id;
END ;;

DELIMITER ;
