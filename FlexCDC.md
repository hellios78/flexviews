# FlexCDC is a change data capture utility for MySQL 5.1 #
# FAQ #
<h3>Q: What is a change data capture (CDC) utility?</h3><p>A change data capture utility detects row changes in the database, and takes some action on them such as writing them to a log file or log table.<br>
<h3>Q: Why does Flexviews need a CDC utility?</h3><p>In order to incrementally update views, Flexviews needs to know the specific details of each row change made in the database.  FlexCDC reads MySQL binary logs, which record those row changes.<br>
<h3>Q: Does FlexCDC replace MySQL replication?</h3><p>No.  There is, however, an experimental class called FlexSBR which includes support for replication of statement based replication binary logs.  It does not work with RBR.  It is mainly a proof-of-concept.  You can find it in the consumer/ subdirectory.<br>
<br>
<br>
<br>
<hr><br>
<br>
<br>
<br>
<h1>How it works</h1>
<img src='http://flexviews.sourceforge.net/images/FlexCDC.png'><p>
<ul>
<ol>
<li>FlexCDC invokes mysqlbinlog in an external process with the commandline options '--base64-output=decode-rows -v'.  This instructs the utility to present RBR base64 entries as an easily readable SBR notation.</li>
<li>mysqlbinlog connects to MySQL and asks for binary logs.  The output from mysqlbinlog is captured by FlexCDC and processed further.</li>
<li>Instead of applying the actual changes, FlexCDC records the changes into log tables.  FlexCDC assigns a unique monotonically increasing transaction id to each set of changes. FlexCDC inserts each set  changes into one or more table changelogs (one per changed table) in a single transaction.  </li>
</ol>