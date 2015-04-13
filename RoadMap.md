# Performance Optimization #
> <ul>
<blockquote><li>Add gearman worker support for parallel work<br>
<li>Improve propagation algorithm performance using rolling propagation.</li>
<li>Add support to run the propagation queries for each base table in parallel</li></blockquote>

<h1>Operational / Usability</h1>

<h2>purge operation</h2>
<blockquote><ol>
<li>Add SP to identify oldest uow_id that any view requires for refresh<br>
<li>Add stored procedure to remove rows from a changelog on a given table before a given uow.<br>
<li>Add another SP to call that SP either serially or in parallel, via gearman workers<br>
<li>After the SP in step 4 completes, delete uow_id rows that are no longer needed