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

/*!50003 DROP FUNCTION IF EXISTS `mview_get_keys` */;;

/*!50003 CREATE*/ /*!50020 DEFINER=`flexviews`@`localhost`*/ /*!50003 FUNCTION `mview_get_keys`(v_mview_id INT) RETURNS TEXT CHARSET latin1
READS SQL DATA
BEGIN
  DECLARE v_done boolean DEFAULT FALSE;
  DECLARE v_mview_expr_type VARCHAR(50);
  DECLARE v_mview_expression TEXT default NULL;
  DECLARE v_mview_alias TEXT;
  DECLARE v_key_list TEXT default '';
  DECLARE v_mview_refresh_type TEXT;

  DECLARE cur_expr CURSOR FOR
  SELECT mview_expression, 
         mview_alias
    FROM flexviews.mview_expression 
   WHERE mview_expr_type = v_mview_expr_type 
     AND mview_id = v_mview_id
   ORDER BY mview_expr_order;
  
  DECLARE CONTINUE HANDLER FOR
  SQLSTATE '02000'
    SET v_done = TRUE;

  -- Is an explicit PRIMARY key defined?
  SET v_mview_expr_type='PRIMARY';
  OPEN cur_expr;
  exprLoop: LOOP
    FETCH cur_expr INTO 
      v_mview_expression,
      v_mview_alias;

    IF v_done THEN
      CLOSE cur_expr;
      LEAVE exprLoop;
    END IF;
  END LOOP;

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
END */;;

DELIMITER ;
