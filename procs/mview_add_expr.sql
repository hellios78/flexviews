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

DROP PROCEDURE IF EXISTS flexviews.`add_expr` ;;

CREATE DEFINER=`flexviews`@`localhost` PROCEDURE flexviews.`add_expr`(
  IN v_mview_id INT,
  IN v_mview_expr_type varchar(50),
  IN v_mview_expression TEXT,
  IN v_mview_alias TEXT
)
BEGIN
  DECLARE v_error BOOLEAN default false;
  DECLARE v_mview_enabled BOOLEAN default NULL;
  DECLARE v_mview_refresh_type TEXT;

  DECLARE v_mview_expr_order INT;
  DECLARE CONTINUE HANDLER FOR SQLSTATE '01000' SET v_error = true;
  SELECT mview_enabled,
         mview_refresh_type
    INTO v_mview_enabled,
         v_mview_refresh_type
    FROM flexviews.mview
   WHERE mview_id = v_mview_id;

  IF v_mview_enabled IS NULL THEN
    SELECT 'FAILURE: The specified materialized view does not exist.' as message;
  ELSEIF v_mview_enabled = 1 AND v_mview_refresh_type = 'INCREMENTAL'  THEN
    SELECT 'FAILURE: The specified materialized view is enabled.  INCREMENTAL refresh materialized views may not be modified after they have been enabled.' as message;
  ELSE
    SELECT IFNULL(max(mview_expr_order), 0)+1
      INTO v_mview_expr_order
      FROM flexviews.mview_expression
     WHERE mview_id=v_mview_id;

      REPLACE INTO flexviews.mview_expression
      (  mview_id,
         mview_expr_type,
         mview_expression,
         mview_alias,
         mview_expr_order )
      VALUES
      (  v_mview_id,
         v_mview_expr_type,
         v_mview_expression,
         v_mview_alias,
         v_mview_expr_order );
     if (v_error != false) then
       select concat('Invalid expression type: ', v_mview_expr_type,'  Available expression types: ', column_type) as 'error'
         from information_schema.columns 
        where table_name='mview_expression'
          and table_schema='flexviews'
          and column_name='mview_expr_type';
     else
       select 'SUCCESS: expression added' as message;
     end if;
  END IF;

END ;;

DELIMITER ;
