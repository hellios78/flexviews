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
CREATE DATABASE IF NOT EXISTS flexviews;
CREATE USER flexviews@localhost identified by 'CHANGEME';

GRANT/* CREATE, DROP, ALTER, DELETE, INDEX,
      INSERT, SELECT, UPDATE, TRIGGER, CREATE VIEW,
      SHOW VIEW, ALTER ROUTINE, CREATE ROUTINE, EXECUTE,
      CREATE TEMPORARY TABLES, LOCK TABLES
     */ALL
   ON flexviews.*
   TO flexviews@localhost;

-- THIS GIVES THE flexviews USER SELECT ACCESS TO
-- ALL YOUR TABLES.  THIS MAY NOT BE A GOOD
-- IDEA.  YOU WILL HAVE TO DECIDE.  IF YOU DON'T
-- WANT THIS YOU WILL HAVE TO GRANT EXPLICIT SELECT
-- ACCESS TO THE flexviews USER ON BASE TABLES THAT
-- YOU WANT TO SELECT FROM FOR MATERIALIZED VIEWS
GRANT SELECT 
   ON *.*
   TO flexviews@localhost;

USE flexviews;

\. schema/mview_schema.sql

\. ./procs/mview_add_expr.sql
\. ./procs/mview_add_table.sql
\. ./procs/mview_create_mvlog.sql
\. ./procs/mview_create.sql
\. ./procs/mview_commit_funcs.sql
\. ./procs/mview_delta.sql
\. ./procs/mview_disable.sql
\. ./procs/mview_enable.sql
\. ./procs/mview_get_from_clause.sql
\. ./procs/mview_get_grouping_list.sql
\. ./procs/mview_get_id.sql
\. ./procs/mview_get_keys.sql
\. ./procs/mview_get_select_list.sql
\. ./procs/mview_get_trigger_body.sql
\. ./procs/mview_get_where.sql
\. ./procs/mview_is_enabled.sql
\. ./procs/mview_mvlog_autoclean.sql
\. ./procs/mview_refresh_complete.sql
\. ./procs/mview_refresh.sql
\. ./procs/mview_remove_expr.sql
\. ./procs/mview_remove_table.sql
\. ./procs/mview_rename.sql
\. ./procs/mview_set_definition.sql
\. ./procs/mview_signal.sql
\. ./procs/mview_uow.sql

CALL flexviews.uow_start(@uow_id);
CALL flexviews.uow_end(@uow_id);
set @uow_id = NULL;
