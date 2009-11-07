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

DROP PROCEDURE IF EXISTS flexviews.`create_mvlog` ;;
CREATE DEFINER=`flexviews`@`localhost` PROCEDURE flexviews.`create_mvlog`(
   IN v_schema_name VARCHAR(100),
   IN v_table_name VARCHAR(50) 
)
BEGIN
  DECLARE v_done BOOLEAN DEFAULT FALSE;
  
  DECLARE v_column_name VARCHAR(100);
  DECLARE v_data_type VARCHAR(1024);
  DECLARE v_delim CHAR(5);
  DECLARE v_mview_type TINYINT(4) DEFAULT -1;
  DECLARE v_trig_extension CHAR(3);
  DECLARE v_sql TEXT;
  DECLARE cur_columns CURSOR
  FOR SELECT COLUMN_NAME, 
             IF(COLUMN_TYPE='TIMESTAMP', 'DATETIME', COLUMN_TYPE) COLUMN_TYPE
        FROM INFORMATION_SCHEMA.COLUMNS 
       WHERE TABLE_NAME=v_table_name 
         AND TABLE_SCHEMA = v_schema_name;
  
  DECLARE CONTINUE HANDLER FOR 
  SQLSTATE '02000'
    SET v_done = TRUE;

  
  SET v_sql = CONCAT('DROP TABLE IF EXISTS ', flexviews.get_setting('mvlog_db'), '.', v_table_name, '_mvlog;');
  SET @v_sql = v_sql;
  PREPARE drop_stmt from @v_sql;
  EXECUTE drop_stmt;
  DEALLOCATE PREPARE drop_stmt;

  
  OPEN cur_columns;
  
  SET v_sql = '';
  columnLoop: LOOP
    IF v_sql != '' THEN
      SET v_sql = CONCAT(v_sql, ', ');
    END IF;
    FETCH cur_columns INTO 
      v_column_name,
      v_data_type;
  
    IF v_done THEN
      CLOSE cur_columns;
      LEAVE columnLoop;
    END IF;
    SET v_sql = CONCAT(v_sql, v_column_name, ' ', v_data_type);
  END LOOP; 
  
  SET v_sql = CONCAT('CREATE TABLE ', flexviews.get_setting('mvlog_db'), '.', v_table_name, '_mvlog', 
                 '( dml_type INT DEFAULT 0, uow_id BIGINT, ', v_sql, 'KEY(uow_id) ) ENGINE=INNODB');
   
  SET @v_sql = v_sql;
  PREPARE create_stmt from @v_sql;
  EXECUTE create_stmt;
  DEALLOCATE PREPARE create_stmt; 

  INSERT INTO flexviews.mvlogs (table_schema, table_name, mvlog_name) values (v_schema_name, v_table_name, CONCAT(v_table_name, '_mvlog'));

END ;;

DELIMITER ;
