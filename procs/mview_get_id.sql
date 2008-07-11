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

DROP FUNCTION IF EXISTS mview_get_id;;
DROP FUNCTION IF EXISTS get_id;;

CREATE DEFINER=flexviews@localhost FUNCTION get_id (
  v_mview_name TEXT,
  v_mview_schema TEXT
)
RETURNS INT
READS SQL DATA
BEGIN
DECLARE v_mview_id INT;
 SELECT mview_id 
   INTO v_mview_id
   FROM flexviews.mview
  WHERE mview_name = v_mview_name
    AND mview_schema = v_mview_schema;

 RETURN v_mview_id;
END;
;;

DELIMITER ;
