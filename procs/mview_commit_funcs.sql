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

DROP FUNCTION IF EXISTS flexviews.get_commits;;
CREATE DEFINER=`flexviews`@`localhost` FUNCTION flexviews.get_commits()
RETURNS INT
READS SQL DATA
BEGIN
   DECLARE v_count INT;
   SELECT VARIABLE_VALUE
     INTO v_count
     FROM INFORMATION_SCHEMA.SESSION_STATUS
    WHERE VARIABLE_NAME='COM_COMMIT';
   RETURN v_count;
END;
;;

DROP FUNCTION IF EXISTS flexviews.get_rollbacks;;
CREATE DEFINER=`flexviews`@`localhost` FUNCTION flexviews.get_rollbacks()
RETURNS INT
READS SQL DATA
BEGIN
   DECLARE v_count INT;
   SELECT VARIABLE_VALUE
     INTO v_count
     FROM INFORMATION_SCHEMA.SESSION_STATUS
    WHERE VARIABLE_NAME='COM_ROLLBACK';
    RETURN v_count;
END;;

DELIMITER ;
