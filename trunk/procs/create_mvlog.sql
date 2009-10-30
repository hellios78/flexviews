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
  DECLARE v_sql VARCHAR(32000) default NULL;
  DECLARE v_mview_type TINYINT(4) DEFAULT -1;
  DECLARE v_trig_extension CHAR(3);
  DECLARE cur_columns CURSOR
  FOR SELECT COLUMN_NAME, 
             IF(COLUMN_TYPE='TIMESTAMP', 'DATETIME', COLUMN_TYPE) COLUMN_TYPE
        FROM INFORMATION_SCHEMA.COLUMNS 
       WHERE TABLE_NAME=v_table_name 
         AND TABLE_SCHEMA = v_schema_name;
  
  DECLARE CONTINUE HANDLER FOR 
  SQLSTATE '02000'
    SET v_done = TRUE;

  
  set @OUTPUT = CONCAT('DELIMITER ;;\n');
  SET @OUTPUT = CONCAT(@OUTPUT,'\nDROP TABLE IF EXISTS ', flexviews.get_setting('mvlog_db'), '.', v_table_name, '_mvlog;;\n');
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
   
  set @OUTPUT = CONCAT(@OUTPUT, v_sql, ';;\n\n');

  SET v_sql = CONCAT('DROP TRIGGER IF EXISTS ', v_schema_name, '.trig_', v_table_name, '_ins ');
  
  set @OUTPUT = CONCAT(@OUTPUT, v_sql, ';;\n\n');
  SET v_sql = CONCAT('CREATE TRIGGER ', v_schema_name, '.trig_', v_table_name, '_ins ');
  SET v_sql = CONCAT(v_sql, '\nAFTER INSERT ON ', v_schema_name, '.', v_table_name);
  SET v_sql = CONCAT(v_sql, '\nFOR EACH ROW\nBEGIN\n',
                            ' CALL flexviews.uow_state_change();\n');
  CALL flexviews.get_trigger_body(v_table_name, v_schema_name, 1, v_sql); 
  SET v_sql = CONCAT(v_sql, 'END;\n');
   
  set @OUTPUT = CONCAT(@OUTPUT, v_sql, ';;\n\n');
  SET v_sql = CONCAT('DROP TRIGGER IF EXISTS ', v_schema_name, '.trig_', v_table_name, '_upd ');
  
  set @OUTPUT = CONCAT(@OUTPUT, v_sql, ';;\n\n');
  SET v_sql = CONCAT('CREATE TRIGGER ', v_schema_name, '.trig_', v_table_name, '_upd ');
  SET v_sql = CONCAT(v_sql, '\nAFTER UPDATE ON ', v_schema_name, '.', v_table_name);
  SET v_sql = CONCAT(v_sql, '\nFOR EACH ROW\nBEGIN\n',
                            ' CALL flexviews.uow_state_change();\n');
  CALL flexviews.get_trigger_body(v_table_name, v_schema_name, -1, v_sql);  
  CALL flexviews.get_trigger_body(v_table_name, v_schema_name, 1, v_sql);   
  SET v_sql  = CONCAT(v_sql , ' END;\n');
   
  set @OUTPUT = CONCAT(@OUTPUT, v_sql, ';;\n\n');
  SET v_sql  = CONCAT('DROP TRIGGER IF EXISTS ', v_schema_name, '.trig_', v_table_name, '_del ');
  
  set @OUTPUT = CONCAT(@OUTPUT, v_sql, ';;\n\n');
  SET v_sql  = CONCAT('CREATE TRIGGER ', v_schema_name, '.trig_', v_table_name, '_del ');
  SET v_sql  = CONCAT(v_sql, '\nAFTER DELETE ON ', v_schema_name, '.', v_table_name);
  SET v_sql = CONCAT(v_sql, '\nFOR EACH ROW\nBEGIN\n',
                            ' CALL flexviews.uow_state_change();\n');
  CALL flexviews.get_trigger_body(v_table_name, v_schema_name, -1, v_sql);  
  SET v_sql = CONCAT(v_sql, '\nEND;\n');
   
  set @OUTPUT = CONCAT(@OUTPUT, v_sql,';;\n\nDELIMITER ;\n');

  set @OUTPUT = CONCAT('\n -- MySQL doesn\'t allow prepared CREATE TRIGGER statements so you will have to \n',
                ' -- execute the following statements to create a materialized view log.\n',
                ' /*** BE VERY CAREFUL *** \n THE FOLLOWING STATEMENTS WILL FAIL IF YOU HAVE\n EXISTING *AFTER UPDATE|DELETE|INSERT* TRIGGERS\n ON THE SPECIFIED TABLE\n',
                '\n You may either change the triggers to *BEFORE* triggers\n or you can merge your trigger bodies with these trigger bodies.\n',
                '\n Copy everything between (and including) DELIMITER ;; to DELIMITER ; and modify as necessary.\n ***/\n', @OUTPUT);
  SELECT @OUTPUT;
END ;;

DELIMITER ;
