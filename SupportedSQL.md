# Supported SQL operations #
## This list applies to incrementally refreshable materialized views ##
<table border='1'>
<tr>
<th align='left'> Operation<br>
<th align='left'> Supported<br>
<th align='left'> Notes<br>
<tr>
<td>GROUP BY<br>
<td>Yes<br>
<td>
<tr>
<td>COUNT<br>
<td>Yes<br>
<td>
<tr>
<td>COUNT_DISTINCT<br>
<td>Yes<br>
<td>
<tr>
<td>SUM<br>
<td>Yes<br>
<td>
<tr>
<td>SUM_DISTINCT<br>
<td>No<br>
<td>
<tr>
<td>AVG<br>
<td>Yes<br>
<td>
<tr>
<td>AVG_DISTINCT<br>
<td>No<br>
<td>
<tr>
<td>MIN<br>
<td>Yes<br>
<td>
<tr>
<td>MIN_DISTINCT<br>
<td>No<br>
<td>
<tr>
<td>MAX<br>
<td>Yes<br>
<td>
<tr>
<td>MAX_DISTINCT<br>
<td>No<br>
<td>
<tr>
<td>JOIN<br>
<td>Yes<br>
<td>INNER JOIN only.  No CROSS JOIN, OUTER JOIN or cartesian products.<br>
<tr>
<td>WHERE<br>
<td>Yes<br>
<td>
<tr>
<td>HAVING<br>
<td>No<br>
<td>(use a where clause when you select from the view)<br>
<tr>
<td>ORDER BY<br>
<td>No<br>
<td>(use an order by clause when you select from the view)