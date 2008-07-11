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

DROP PROCEDURE IF EXISTS `set_definition`;;

CREATE DEFINER=`flexviews`@`localhost` PROCEDURE `set_definition`(
  IN v_mview_id INT,
  IN v_definition_sql TEXT
)
BEGIN

 UPDATE flexviews.mview
    SET mview_definition = v_definition_sql
  WHERE mview_id = v_mview_id;   
     
END ;;

DELIMITER ;
