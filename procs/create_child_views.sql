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

DROP FUNCTION IF EXISTS flexviews.`create_child_views` ;;

CREATE DEFINER=`flexviews`@`localhost` FUNCTION flexviews.`create_child_views`(v_mview_id INT) RETURNS TEXT CHARSET latin1
READS SQL DATA
BEGIN
  DECLARE v_done boolean DEFAULT FALSE;
  DECLARE v_mview_expr_type VARCHAR(50);
  DECLARE v_mview_expression TEXT default NULL;
  DECLARE v_mview_alias TEXT;
  DECLARE v_key_list TEXT default '';
  DECLARE v_mview_refresh_type TEXT;
  DECLARE v_mview_expression_id INT;
  DECLARE v_new_mview_id INT;

  DECLARE cur_expr CURSOR FOR
  SELECT mview_expression, 
         mview_alias,
	 mview_expression_id,
         mview_expression_type
    FROM flexviews.mview_expression 
   WHERE mview_expr_type in ('MIN','MAX','COUNT_DISTINCT')
     AND mview_id = v_mview_id
   ORDER BY mview_expr_order;
  
  DECLARE CONTINUE HANDLER FOR
  SQLSTATE '02000'
    SET v_done = TRUE;

  OPEN cur_expr;
  exprLoop: LOOP
    FETCH cur_expr INTO 
      v_mview_expression,
      v_mview_alias,
      v_mview_expression_id,
      v_mview_expression_type;

      CALL flexviews.create(flexviews.get_setting('mvlog_db'), concat('mv$',v_mview_id,'$',v_mview_expression_id));
      SET v_new_mview_id := LAST_INSERT_ID();

      -- Copy the tables into the new child mview
      INSERT INTO flexviews.mview_table
      SELECT NULL,
             v_new_mview_id,
             mview_table_name,
             mview_table_schema,
             mview_table_alias,
             mview_join_condition,
             mview_join_order
        FROM flexviews.mview_table
       WHERE mview_id = v_mview_id;

      -- Copy the GROUP BY expressions into the child mview
      INSERT INTO flexviews.mview_expression
      SELECT NULL,
	     v_new_mview_id,
             mview_expr_type,
             mview_expression,
             mview_alias,         
             mview_expr_order
        FROM flexviews.mview_expression
       WHERE mview_id = v_mview_id;

       CALL flexviews.add_expr(v_new_mview_id, v_mview_expr_type, v_mview_expression, v_mview_alias);
       CALL flexviews.add_expr(v_new_mview_id, 'COUNT', '*', 'CNT');

       CALL flexviews.enable(v_new_mview_id);
	
    IF v_done THEN
      CLOSE cur_expr;
      LEAVE exprLoop;
    END IF;

  END LOOP exprLoop;

  IF v_mview_expression IS NOT NULL THEN
    SET v_key_list = CONCAT('PRIMARY KEY ', v_mview_alias, '(', v_mview_expression, ')');
  ELSE
    -- NO PRIMARY KEY DEFINED, WE NEED TO SELECT ONE FOR THE USER
    SELECT mview_refresh_type 
      INTO v_mview_refresh_type
      FROM flexviews.mview
     WHERE mview_id = v_mview_id;

    SET v_done=FALSE; 
    -- a mview can't have both COLUMN expressions and GROUP BY expressions....
    -- so figure out which one this one uses.
    SELECT MIN(mview_expr_type)
      INTO v_mview_expr_type
      FROM flexviews.mview_expression
     WHERE mview_expr_type = 'GROUP';

    IF v_mview_expr_type IS NULL THEN
      SELECT DISTINCT mview_expr_type
        INTO v_mview_expr_type
        FROM flexviews.mview_expression
       WHERE mview_expr_type = 'COLUMN';
    END IF;
    OPEN cur_expr;

    exprLoop: LOOP
      FETCH cur_expr INTO
        v_mview_expression,
        v_mview_alias;

      IF v_done THEN 
         CLOSE cur_expr;
         LEAVE exprLoop;
      END IF;

      IF v_key_list != '' THEN
        SET v_key_list = CONCAT(v_key_list, ','); 
      END IF;
      SET v_key_list = CONCAT(v_key_list, v_mview_alias);
    END LOOP;

    IF v_key_list != '' THEN
      IF v_mview_expr_type = 'GROUP' THEN
        SET v_key_list = CONCAT('PRIMARY KEY (', v_key_list, ')');
      ELSE
        SET v_key_list = CONCAT('KEY (', v_key_list, ')');
      END IF;
    END IF;
  END IF;

  SET v_mview_expr_type = 'KEY';
  SET v_done=FALSE;
  OPEN cur_expr;

  exprLoop: LOOP
    FETCH cur_expr INTO
      v_mview_expression,
      v_mview_alias;
    
    IF v_done THEN
       CLOSE cur_expr;
       LEAVE exprLoop;
    END IF;

    IF v_key_list != '' THEN
      SET v_key_list = CONCAT(v_key_list, ',');
    END IF;
    SET v_key_list = CONCAT(v_key_list, 'KEY ', v_mview_alias, '(', v_mview_expression, ')');
  END LOOP;

  RETURN v_key_list;
END ;;

DELIMITER ;
