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

/*!50003 DROP PROCEDURE IF EXISTS mview_add_expr */;;
/*!50003 DROP PROCEDURE IF EXISTS flexviews.`add_expr` */;;

/*!50003 CREATE*/ /*!50020 DEFINER=`flexviews`@`localhost`*/ /*!50003 PROCEDURE flexviews.`add_expr`(
  IN v_mview_id INT,
  IN v_mview_expr_type varchar(50),
  IN v_mview_expression TEXT,
  IN v_mview_alias TEXT
)
BEGIN
  DECLARE v_mview_expr_order INT;
  IF flexviews.is_enabled(v_mview_id) = 1 THEN
    CALL flexviews.signal('MAY_NOT_MODIFY_ENABLED_MVIEW');
  END IF;

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

END */;;

DELIMITER ;
