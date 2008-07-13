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

DROP PROCEDURE IF EXISTS flexviews.`remove_table` ;;

CREATE DEFINER=`flexviews`@`localhost` PROCEDURE `remove_table`(
  IN v_mview_id INT,
  IN v_mview_table_schema TEXT,
  IN v_mview_table_name TEXT
)
BEGIN
  IF flexviews.is_enabled(v_mview_id) = 1 THEN
    CALL flexviews.signal('MAY_NOT_MODIFY_ENABLED_MVIEW');
  END IF;

  DELETE FROM flexviews.mview_table
  WHERE mview_id = v_mview_id
    AND mview_table_name = v_mview_table_name
    AND mview_table_schema = v_mview_table_schema;

END ;;

DELIMITER ;
