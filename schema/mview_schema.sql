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

DROP TABLE IF EXISTS `mview`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `mview` (
  `mview_id` int(11) NOT NULL auto_increment,
  `mview_name` varchar(50) default NULL,
  `mview_schema` varchar(50) default NULL,
  `mview_enabled` tinyint(1) default NULL,
  `mview_last_refresh` datetime default NULL,
  `mview_refresh_period` int(11) default '86400',
  `mview_refresh_type` enum('INCREMENTAL','COMPLETE') default NULL,
  `mview_engine` enum('MyISAM','InnoDB') default 'InnoDB',
  `mview_definition` varchar(32000),
  `incremental_hwm` bigint(20) default NULL,
  `refreshed_to_uow_id` bigint(20) default NULL,
  PRIMARY KEY  (`mview_id`),
  UNIQUE KEY `mview_name` (`mview_name`,`mview_schema`)
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;


DROP TABLE IF EXISTS `mview_expression`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `mview_expression` (
  `mview_expression_id` int(11) NOT NULL auto_increment,
  `mview_id` int(11) default NULL,
  `mview_expr_type` enum('GROUP','SUM','AVG','COUNT','MIN','MAX','WHERE','PRIMARY','KEY','COLUMN') default NULL,
  `mview_expression` varchar(1000),
  `mview_alias` varchar(100) default NULL,
  `mview_expr_order` int(11) default '999',
  PRIMARY KEY  (`mview_expression_id`),
  UNIQUE KEY `mview_id` (`mview_id`,`mview_alias`),
  KEY `mview_id_2` (`mview_id`,`mview_expr_order`)
) ENGINE=InnoDB AUTO_INCREMENT=49 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;


DROP TABLE IF EXISTS `mview_refresh_status`;
/*!50001 DROP VIEW IF EXISTS `mview_refresh_status`*/;
/*!50001 CREATE TABLE `mview_refresh_status` (
  `mview_id` int(11),
  `mview_schema` varchar(50),
  `mview_name` varchar(50),
  `mview_last_refresh` datetime,
  `mview_refresh_type` enum('INCREMENTAL','COMPLETE')
) */;


DROP TABLE IF EXISTS `mview_table`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `mview_table` (
  `mview_table_id` int(11) NOT NULL auto_increment,
  `mview_id` int(11) NOT NULL,
  `mview_table_name` varchar(100) default NULL,
  `mview_table_schema` varchar(100) default NULL,
  `mview_table_alias` varchar(100) default NULL,
  `mview_join_condition` varchar(1000),
  `mview_join_order` int(11) default '999',
  PRIMARY KEY  (`mview_table_id`)
) ENGINE=InnoDB AUTO_INCREMENT=17 DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;


DROP TABLE IF EXISTS `mview_uow`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `mview_uow` (
  `uow_id` SERIAL default NULL,
  `commit_time` datetime default NULL,
  KEY `commit_time` (`commit_time`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

/*
DROP TABLE IF EXISTS `mview_uow_sequence`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `mview_uow_sequence` (
  `uow_id` SERIAL default NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;
*/
