# MySQL Requirements #

## Required MySQL settings ##

---

  * MySQL 5.1+
  * Row Level Binary logging (binlog\_format = ROW in my.cnf)
  * server\_id set to unique value (server\_id = 999 in my.cnf)
  * SUPER privileges

## Suggested MySQL 5.1 settings ##

---

  * transaction-isolation = READ-COMMITTED
  * sync\_binlog=1
  * sync\_frm=1
  * innodb\_support\_xa=1
## Transaction isolation level: READ-COMMITTED ##

---

> This transaction isolation level, when combined with row-based binary logging, will prevent locks from being held during INSERT .. SELECT statements which Flexviews uses.

# PHP Requirements #
  * PHP 5.2+ required, 5.3+ is recommended
  * pcntl extension
  * MySQL extension

> PHP is required for FlexCDC, the binary log reading change data capture tool included in Flexviews.
