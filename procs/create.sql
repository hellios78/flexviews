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

DROP PROCEDURE IF EXISTS flexviews.create;;
/****f* flexviews/flexviews.create
 * NAME
 *   flexviews.create - Create a materialized view placeholder "skeleton" for the view
 * SYNOPSIS
 *   flexviews.create(v_schema, v_mview_name, v_refresh_type)
 * FUNCTION
 *   This function creates a placeholder or "skeleton" for a Flexviews materialized view.
 *   The materialized view identifier is stored in LAST_INSERT_ID() and is also accessible
 *   using flexviews.get_id()
 * INPUTS
 *   v_schema       - The schema (aka database) in which to create the view
 *   v_mview_name   - The name of the materialzied view to create
 *   v_refresh_type - ENUM('INCREMENTAL','COMPLETE')
 * RESULT
 *   An error will be generated in the MySQL client if the skeleton can not be created.
 * EXAMPLE
 *   call flexviews.create('test', 'mv_example', 'INCREMENTAL');
******
*/

CREATE DEFINER=`flexviews`@`localhost` PROCEDURE flexviews.`create`(
  IN v_mview_schema TEXT,
  IN v_mview_name TEXT,
  IN v_mview_refresh_type TEXT
)
BEGIN
  INSERT INTO flexviews.mview
  (  mview_name,
     mview_schema, 
     mview_refresh_type
  )
  VALUES
  (  v_mview_name,
     v_mview_schema,
     v_mview_refresh_type
  );

END ;;

DELIMITER ;
