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
/****f* flexviews/flexviews.add_expr
 * NAME
 *   flexviews.add_expr - Add an expression or indexes to a materialized view.
 * SYNOPSIS
 *   flexviews.add_expr(v_mview_id, v_expr_type, v_expression, v_alias) 
 * FUNCTION
 *   This function adds an expression or indexes to the materialized view 
 *   definition.  This function may only be called on disabled materialized views,
 *   though in the future adding indexes will be possible on enabled views.
 *   Each column referenced in the expression must be prefixed with a table
 *   alias provided in flexviews.add_table.
 * INPUTS
 *   v_mview_id -- The materialized view id (see flexviews.get_id)
 *   v_expr_type:
 *   * GROUP -- GROUP BY this expression.  If any aggregate functions are used, then the non
 *     aggregate expressions MUST be GROUP expressions.
 *   * COLUMN -- Views with aggregation are more expensive to maintain.  If a view contains NO
 *     aggregate expressions then you can use COLUMN expressions to avoid
 *     GROUPing when it isn't required.
 *   * COUNT -- When star '*' is provided as the expression, counts all rows.
 *             When any other expression is used, counts NOT-NULL values of the expresion.
 *   * SUM -- Use the SUM aggregate function
 *   * MIN -- Experimental MIN support  (uses auxilliary view)
 *   * MAX -- Experimental MAX support  (uses auxilliary view)
 *   * AVG -- Experimental AVG support  (adds SUM and COUNT expressions automatically)
 *   * COUNT_DISTINCT -- Experimental COUNT(DISTINCT) support (uses auxilliary view)
 *   * PRIMARY -- Adds a primary key to the view.  Specify column aliases in v_expr.  
 *   * KEY -- Adds an index to the view.  Specify column aliases in v_expr.
 *
 *   v_expr - The expression to add.  Any columns in the expression must be prefixed with
 *   a table alias created with flexviews.add_table.  When the PRIMARY or KEY expression types
 *   are used, the user must specify one more more COLUMN aliases (which may include the alias
 *   currently being added) to index.  
 *
 *   v_alias - Every expression must be given a unique alias in the view, which becomes the
 *   name of the column in the materialized view. For PRIMARY and KEY indexes, this will be
 *   the name of the index in the view.  You must NOT use any reserved words in this name. 
 * 
 * SEE ALSO
 *   flexviews.enable, flexviews.add_table, flexviews.disable
 * EXAMPLE
 *   set @mv_id = flexviews.get_id('test', 'mv_example');
 *   call flexviews.add_table(@mv_id, 'schema', 'table', 'an_alias', NULL);
 *
 *   call flexviews.add_expr(@mv_id, 'GROUP', 'an_alias.c1', 'c1');
 *   call flexviews.add_expr(@mv_id, 'SUM', 'an_alias.c2', 'sum_c2');
 *   call flexviews.add_expr(@mv_id, 'PRIMARY', 'c1', 'pk');
******
*/

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
  SELECT IFNULL(mview_enabled,false),
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
     end if;
  END IF;

END ;;

DELIMITER ;
