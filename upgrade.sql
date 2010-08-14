create database if not exists flexviews;
use flexviews;

create table if not exists upgrades (
  version int,
  proc_name varchar(20) not null, 
  primary key (version)
) engine = innodb;

create table if not exists version (
  version int,
  primary key (version)
) engine = innodb;

-- register the availability of the upgrade package
replace into upgrades values ('160','upgrade_160');

 

