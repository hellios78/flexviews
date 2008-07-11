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

CREATE DEFINER=`flexviews`@`localhost` PROCEDURE flexviews.`create`(
  IN v_mview_name TEXT,
  IN v_mview_schema TEXT,
  IN v_mview_refresh_type TEXT,
  IN v_mview_refresh_period INT
)
BEGIN
  INSERT INTO flexviews.mview
  (  mview_name,
     mview_schema, 
     mview_refresh_type,
     mview_refresh_period )
  VALUES
  (  v_mview_name,
     v_mview_schema,
     v_mview_refresh_type,
     v_mview_refresh_period );

END ;;

DELIMITER ;
