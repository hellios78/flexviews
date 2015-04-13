# FLEXVIEWS IS NOW AT GITHUB #
https://github.com/greenlion/swanhart-tools

# What is Flexviews? #
Flexviews is a unique open source project. Flexviews is a materialized views implementation for MySQL. It includes a simple API that is used to create **materialized views** and to refresh them.  The advantage of using Flexviews is that the materialized views are _incrementally refreshed_, that is, the views are updated efficiently by using special logs which record the changes to database tables.  Flexviews includes tools which create and maintain these logs.  The views created by Flexviews include support for JOINs and for all major aggregation functions.

Here is the list of basic system requirements:

http://code.google.com/p/flexviews/wiki/Requirements

You can find the complete manual here:

http://flexviews.googlecode.com/svn/trunk/manual.html

You can find additional information in the wiki:

http://code.google.com/p/flexviews/w/list

# What is a materialized view? #

A "regular" view is a virtual table representing the result of a database query.  Each time the view is accessed, the RDBMS must run the query to produce the result set for the view.

A materialized view is similar to regular view, except that the results are stored into an actual database table, not a virtual one. The result set is effectively cached for a period of time.   When the underlying data changes the view becomes stale.  Because of this, materialized views must be frequently "refreshed" to bring them up-to-date.

By caching result set data into a real table, the data can be accessed much more quickly, but at the cost of some data being potentially out-of-date. It is most useful in data warehousing scenarios, where frequent queries of the actual base tables can be extremely expensive.  Since the materialized view is stored as a real table, you can build indexes on any combination of columns of the view, enabling drastic speedups in response time for queries that access the view.

**Here are some blog posts I wrote that might make this clearer:**
> <ul>
<blockquote><li><a href='http://www.mysqlperformanceblog.com/2011/03/23/using-flexviews-part-one-introduction-to-materialized-views/'>http://www.mysqlperformanceblog.com/2011/03/23/using-flexviews-part-one-introduction-to-materialized-views/</a>
<li><a href='http://www.mysqlperformanceblog.com/2011/03/25/using-flexviews-part-two-change-data-capture/'>http://www.mysqlperformanceblog.com/2011/03/25/using-flexviews-part-two-change-data-capture/</a>
<li><a href='http://www.mysqlperformanceblog.com/2011/04/04/flexviews-part-3-improving-query-performance-using-materialized-views/'>http://www.mysqlperformanceblog.com/2011/04/04/flexviews-part-3-improving-query-performance-using-materialized-views/</a></blockquote>

<h1>Refresh Methods</h1>
Materialized views may be refreshed one of two ways: incrementally or completely. Incremental refresh is preferable because incrementally refreshing the view requires examining only the rows which changed since the view was last refreshed. A complete refresh is more expensive, because all rows are examined to rebuild the view.<br>
In order to support incrementally refreshing a materialized view, each table involved in the view must have a 'change log' to record the changes made to it.<br>
<br>
<h1>Change Logging</h1>
Flexviews includes FlexCDC - a change data capture utility which makes captures table changes to table change logs, making incremental refreshing of views possible.