
 -- MySQL doesn't allow prepared CREATE TRIGGER statements so you will have to 
 -- execute the following statements to create a materialized view log.
 /*** BE VERY CAREFUL *** 
 THE FOLLOWING STATEMENTS WILL FAIL IF YOU HAVE
 EXISTING *AFTER UPDATE|DELETE|INSERT* TRIGGERS
 ON THE SPECIFIED TABLE

 You may either change the triggers to *BEFORE* triggers
 or you can merge your trigger bodies with these trigger bodies.

 Copy everything between (and including) ; to DELIMITER ; and modify as necessary.
 ***/
DELIMITER ;;

DROP TABLE IF EXISTS demo.categories_mvlog;;
CREATE TABLE demo.categories_mvlog( dml_type INT DEFAULT 0, uow_id BIGINT, CategoryID int(11), CategoryName varchar(15), Description text, Picture varchar(40), KEY(uow_id) ) ENGINE=INNODB;;

DROP TRIGGER IF EXISTS demo.trig_categories_ins ;;

CREATE TRIGGER demo.trig_categories_ins 
AFTER INSERT ON demo.categories
FOR EACH ROW
BEGIN
 CALL flexviews.uow_state_change();
 INSERT INTO demo.categories_mvlog VALUES (1, @__uow_id,NEW.CategoryID,NEW.CategoryName,NEW.Description,NEW.Picture);
END;
;;

DROP TRIGGER IF EXISTS demo.trig_categories_upd ;;

CREATE TRIGGER demo.trig_categories_upd 
AFTER UPDATE ON demo.categories
FOR EACH ROW
BEGIN
 CALL flexviews.uow_state_change();
 INSERT INTO demo.categories_mvlog VALUES (-1, @__uow_id,OLD.CategoryID,OLD.CategoryName,OLD.Description,OLD.Picture);
 INSERT INTO demo.categories_mvlog VALUES (1, @__uow_id,NEW.CategoryID,NEW.CategoryName,NEW.Description,NEW.Picture);
 END;
;;

DROP TRIGGER IF EXISTS demo.trig_categories_del ;;

CREATE TRIGGER demo.trig_categories_del 
AFTER DELETE ON demo.categories
FOR EACH ROW
BEGIN
 CALL flexviews.uow_state_change();
 INSERT INTO demo.categories_mvlog VALUES (-1, @__uow_id,OLD.CategoryID,OLD.CategoryName,OLD.Description,OLD.Picture);

END;
;;




 -- MySQL doesn't allow prepared CREATE TRIGGER statements so you will have to 
 -- execute the following statements to create a materialized view log.
 /*** BE VERY CAREFUL *** 
 THE FOLLOWING STATEMENTS WILL FAIL IF YOU HAVE
 EXISTING *AFTER UPDATE|DELETE|INSERT* TRIGGERS
 ON THE SPECIFIED TABLE

 You may either change the triggers to *BEFORE* triggers
 or you can merge your trigger bodies with these trigger bodies.

 Copy everything between (and including) ; to DELIMITER ; and modify as necessary.
 ***/

DROP TABLE IF EXISTS demo.customers_mvlog;;
CREATE TABLE demo.customers_mvlog( dml_type INT DEFAULT 0, uow_id BIGINT, CustomerID varchar(5), CompanyName varchar(40), ContactName varchar(30), ContactTitle varchar(30), Address varchar(60), City varchar(15), Region varchar(15), PostalCode varchar(10), Country varchar(15), Phone varchar(24), Fax varchar(24), KEY(uow_id) ) ENGINE=INNODB;;

DROP TRIGGER IF EXISTS demo.trig_customers_ins ;;

CREATE TRIGGER demo.trig_customers_ins 
AFTER INSERT ON demo.customers
FOR EACH ROW
BEGIN
 CALL flexviews.uow_state_change();
 INSERT INTO demo.customers_mvlog VALUES (1, @__uow_id,NEW.CustomerID,NEW.CompanyName,NEW.ContactName,NEW.ContactTitle,NEW.Address,NEW.City,NEW.Region,NEW.PostalCode,NEW.Country,NEW.Phone,NEW.Fax);
END;
;;

DROP TRIGGER IF EXISTS demo.trig_customers_upd ;;

CREATE TRIGGER demo.trig_customers_upd 
AFTER UPDATE ON demo.customers
FOR EACH ROW
BEGIN
 CALL flexviews.uow_state_change();
 INSERT INTO demo.customers_mvlog VALUES (-1, @__uow_id,OLD.CustomerID,OLD.CompanyName,OLD.ContactName,OLD.ContactTitle,OLD.Address,OLD.City,OLD.Region,OLD.PostalCode,OLD.Country,OLD.Phone,OLD.Fax);
 INSERT INTO demo.customers_mvlog VALUES (1, @__uow_id,NEW.CustomerID,NEW.CompanyName,NEW.ContactName,NEW.ContactTitle,NEW.Address,NEW.City,NEW.Region,NEW.PostalCode,NEW.Country,NEW.Phone,NEW.Fax);
 END;
;;

DROP TRIGGER IF EXISTS demo.trig_customers_del ;;

CREATE TRIGGER demo.trig_customers_del 
AFTER DELETE ON demo.customers
FOR EACH ROW
BEGIN
 CALL flexviews.uow_state_change();
 INSERT INTO demo.customers_mvlog VALUES (-1, @__uow_id,OLD.CustomerID,OLD.CompanyName,OLD.ContactName,OLD.ContactTitle,OLD.Address,OLD.City,OLD.Region,OLD.PostalCode,OLD.Country,OLD.Phone,OLD.Fax);

END;
;;




 -- MySQL doesn't allow prepared CREATE TRIGGER statements so you will have to 
 -- execute the following statements to create a materialized view log.
 /*** BE VERY CAREFUL *** 
 THE FOLLOWING STATEMENTS WILL FAIL IF YOU HAVE
 EXISTING *AFTER UPDATE|DELETE|INSERT* TRIGGERS
 ON THE SPECIFIED TABLE

 You may either change the triggers to *BEFORE* triggers
 or you can merge your trigger bodies with these trigger bodies.

 Copy everything between (and including) ; to DELIMITER ; and modify as necessary.
 ***/

DROP TABLE IF EXISTS demo.employees_mvlog;;
CREATE TABLE demo.employees_mvlog( dml_type INT DEFAULT 0, uow_id BIGINT, EmployeeID int(11), LastName varchar(20), FirstName varchar(10), Title varchar(30), TitleOfCourtesy varchar(25), BirthDate date, HireDate date, Address varchar(60), City varchar(15), Region varchar(15), PostalCode varchar(10), Country varchar(15), HomePhone varchar(24), Extension varchar(4), Photo varchar(40), Notes text, ReportsTo int(11), KEY(uow_id) ) ENGINE=INNODB;;

DROP TRIGGER IF EXISTS demo.trig_employees_ins ;;

CREATE TRIGGER demo.trig_employees_ins 
AFTER INSERT ON demo.employees
FOR EACH ROW
BEGIN
 CALL flexviews.uow_state_change();
 INSERT INTO demo.employees_mvlog VALUES (1, @__uow_id,NEW.EmployeeID,NEW.LastName,NEW.FirstName,NEW.Title,NEW.TitleOfCourtesy,NEW.BirthDate,NEW.HireDate,NEW.Address,NEW.City,NEW.Region,NEW.PostalCode,NEW.Country,NEW.HomePhone,NEW.Extension,NEW.Photo,NEW.Notes,NEW.ReportsTo);
END;
;;

DROP TRIGGER IF EXISTS demo.trig_employees_upd ;;

CREATE TRIGGER demo.trig_employees_upd 
AFTER UPDATE ON demo.employees
FOR EACH ROW
BEGIN
 CALL flexviews.uow_state_change();
 INSERT INTO demo.employees_mvlog VALUES (-1, @__uow_id,OLD.EmployeeID,OLD.LastName,OLD.FirstName,OLD.Title,OLD.TitleOfCourtesy,OLD.BirthDate,OLD.HireDate,OLD.Address,OLD.City,OLD.Region,OLD.PostalCode,OLD.Country,OLD.HomePhone,OLD.Extension,OLD.Photo,OLD.Notes,OLD.ReportsTo);
 INSERT INTO demo.employees_mvlog VALUES (1, @__uow_id,NEW.EmployeeID,NEW.LastName,NEW.FirstName,NEW.Title,NEW.TitleOfCourtesy,NEW.BirthDate,NEW.HireDate,NEW.Address,NEW.City,NEW.Region,NEW.PostalCode,NEW.Country,NEW.HomePhone,NEW.Extension,NEW.Photo,NEW.Notes,NEW.ReportsTo);
 END;
;;

DROP TRIGGER IF EXISTS demo.trig_employees_del ;;

CREATE TRIGGER demo.trig_employees_del 
AFTER DELETE ON demo.employees
FOR EACH ROW
BEGIN
 CALL flexviews.uow_state_change();
 INSERT INTO demo.employees_mvlog VALUES (-1, @__uow_id,OLD.EmployeeID,OLD.LastName,OLD.FirstName,OLD.Title,OLD.TitleOfCourtesy,OLD.BirthDate,OLD.HireDate,OLD.Address,OLD.City,OLD.Region,OLD.PostalCode,OLD.Country,OLD.HomePhone,OLD.Extension,OLD.Photo,OLD.Notes,OLD.ReportsTo);

END;
;;




 -- MySQL doesn't allow prepared CREATE TRIGGER statements so you will have to 
 -- execute the following statements to create a materialized view log.
 /*** BE VERY CAREFUL *** 
 THE FOLLOWING STATEMENTS WILL FAIL IF YOU HAVE
 EXISTING *AFTER UPDATE|DELETE|INSERT* TRIGGERS
 ON THE SPECIFIED TABLE

 You may either change the triggers to *BEFORE* triggers
 or you can merge your trigger bodies with these trigger bodies.

 Copy everything between (and including) ; to DELIMITER ; and modify as necessary.
 ***/

DROP TABLE IF EXISTS demo.order_details_mvlog;;
CREATE TABLE demo.order_details_mvlog( dml_type INT DEFAULT 0, uow_id BIGINT, odID int(10) unsigned, OrderID int(11), ProductID int(11), UnitPrice float(10,2), Quantity smallint(6), Discount float(1,0), KEY(uow_id) ) ENGINE=INNODB;;

DROP TRIGGER IF EXISTS demo.trig_order_details_ins ;;

CREATE TRIGGER demo.trig_order_details_ins 
AFTER INSERT ON demo.order_details
FOR EACH ROW
BEGIN
 CALL flexviews.uow_state_change();
 INSERT INTO demo.order_details_mvlog VALUES (1, @__uow_id,NEW.odID,NEW.OrderID,NEW.ProductID,NEW.UnitPrice,NEW.Quantity,NEW.Discount);
END;
;;

DROP TRIGGER IF EXISTS demo.trig_order_details_upd ;;

CREATE TRIGGER demo.trig_order_details_upd 
AFTER UPDATE ON demo.order_details
FOR EACH ROW
BEGIN
 CALL flexviews.uow_state_change();
 INSERT INTO demo.order_details_mvlog VALUES (-1, @__uow_id,OLD.odID,OLD.OrderID,OLD.ProductID,OLD.UnitPrice,OLD.Quantity,OLD.Discount);
 INSERT INTO demo.order_details_mvlog VALUES (1, @__uow_id,NEW.odID,NEW.OrderID,NEW.ProductID,NEW.UnitPrice,NEW.Quantity,NEW.Discount);
 END;
;;

DROP TRIGGER IF EXISTS demo.trig_order_details_del ;;

CREATE TRIGGER demo.trig_order_details_del 
AFTER DELETE ON demo.order_details
FOR EACH ROW
BEGIN
 CALL flexviews.uow_state_change();
 INSERT INTO demo.order_details_mvlog VALUES (-1, @__uow_id,OLD.odID,OLD.OrderID,OLD.ProductID,OLD.UnitPrice,OLD.Quantity,OLD.Discount);

END;
;;




 -- MySQL doesn't allow prepared CREATE TRIGGER statements so you will have to 
 -- execute the following statements to create a materialized view log.
 /*** BE VERY CAREFUL *** 
 THE FOLLOWING STATEMENTS WILL FAIL IF YOU HAVE
 EXISTING *AFTER UPDATE|DELETE|INSERT* TRIGGERS
 ON THE SPECIFIED TABLE

 You may either change the triggers to *BEFORE* triggers
 or you can merge your trigger bodies with these trigger bodies.

 Copy everything between (and including) ; to DELIMITER ; and modify as necessary.
 ***/

DROP TABLE IF EXISTS demo.orders_mvlog;;
CREATE TABLE demo.orders_mvlog( dml_type INT DEFAULT 0, uow_id BIGINT, OrderID int(11), CustomerID varchar(5), EmployeeID int(11), OrderDate date, RequiredDate date, ShippedDate date, ShipVia int(11), Freight float(1,0), ShipName varchar(40), ShipAddress varchar(60), ShipCity varchar(15), ShipRegion varchar(15), ShipPostalCode varchar(10), ShipCountry varchar(15), KEY(uow_id) ) ENGINE=INNODB;;

DROP TRIGGER IF EXISTS demo.trig_orders_ins ;;

CREATE TRIGGER demo.trig_orders_ins 
AFTER INSERT ON demo.orders
FOR EACH ROW
BEGIN
 CALL flexviews.uow_state_change();
 INSERT INTO demo.orders_mvlog VALUES (1, @__uow_id,NEW.OrderID,NEW.CustomerID,NEW.EmployeeID,NEW.OrderDate,NEW.RequiredDate,NEW.ShippedDate,NEW.ShipVia,NEW.Freight,NEW.ShipName,NEW.ShipAddress,NEW.ShipCity,NEW.ShipRegion,NEW.ShipPostalCode,NEW.ShipCountry);
END;
;;

DROP TRIGGER IF EXISTS demo.trig_orders_upd ;;

CREATE TRIGGER demo.trig_orders_upd 
AFTER UPDATE ON demo.orders
FOR EACH ROW
BEGIN
 CALL flexviews.uow_state_change();
 INSERT INTO demo.orders_mvlog VALUES (-1, @__uow_id,OLD.OrderID,OLD.CustomerID,OLD.EmployeeID,OLD.OrderDate,OLD.RequiredDate,OLD.ShippedDate,OLD.ShipVia,OLD.Freight,OLD.ShipName,OLD.ShipAddress,OLD.ShipCity,OLD.ShipRegion,OLD.ShipPostalCode,OLD.ShipCountry);
 INSERT INTO demo.orders_mvlog VALUES (1, @__uow_id,NEW.OrderID,NEW.CustomerID,NEW.EmployeeID,NEW.OrderDate,NEW.RequiredDate,NEW.ShippedDate,NEW.ShipVia,NEW.Freight,NEW.ShipName,NEW.ShipAddress,NEW.ShipCity,NEW.ShipRegion,NEW.ShipPostalCode,NEW.ShipCountry);
 END;
;;

DROP TRIGGER IF EXISTS demo.trig_orders_del ;;

CREATE TRIGGER demo.trig_orders_del 
AFTER DELETE ON demo.orders
FOR EACH ROW
BEGIN
 CALL flexviews.uow_state_change();
 INSERT INTO demo.orders_mvlog VALUES (-1, @__uow_id,OLD.OrderID,OLD.CustomerID,OLD.EmployeeID,OLD.OrderDate,OLD.RequiredDate,OLD.ShippedDate,OLD.ShipVia,OLD.Freight,OLD.ShipName,OLD.ShipAddress,OLD.ShipCity,OLD.ShipRegion,OLD.ShipPostalCode,OLD.ShipCountry);

END;
;;




 -- MySQL doesn't allow prepared CREATE TRIGGER statements so you will have to 
 -- execute the following statements to create a materialized view log.
 /*** BE VERY CAREFUL *** 
 THE FOLLOWING STATEMENTS WILL FAIL IF YOU HAVE
 EXISTING *AFTER UPDATE|DELETE|INSERT* TRIGGERS
 ON THE SPECIFIED TABLE

 You may either change the triggers to *BEFORE* triggers
 or you can merge your trigger bodies with these trigger bodies.

 Copy everything between (and including) ; to DELIMITER ; and modify as necessary.
 ***/

DROP TABLE IF EXISTS demo.products_mvlog;;
CREATE TABLE demo.products_mvlog( dml_type INT DEFAULT 0, uow_id BIGINT, ProductID int(11), ProductName varchar(40), SupplierID int(11), CategoryID int(11), QuantityPerUnit varchar(20), UnitPrice float(1,0), UnitsInStock smallint(6), UnitsOnOrder smallint(6), ReorderLevel smallint(6), Discontinued tinyint(1), KEY(uow_id) ) ENGINE=INNODB;;

DROP TRIGGER IF EXISTS demo.trig_products_ins ;;

CREATE TRIGGER demo.trig_products_ins 
AFTER INSERT ON demo.products
FOR EACH ROW
BEGIN
 CALL flexviews.uow_state_change();
 INSERT INTO demo.products_mvlog VALUES (1, @__uow_id,NEW.ProductID,NEW.ProductName,NEW.SupplierID,NEW.CategoryID,NEW.QuantityPerUnit,NEW.UnitPrice,NEW.UnitsInStock,NEW.UnitsOnOrder,NEW.ReorderLevel,NEW.Discontinued);
END;
;;

DROP TRIGGER IF EXISTS demo.trig_products_upd ;;

CREATE TRIGGER demo.trig_products_upd 
AFTER UPDATE ON demo.products
FOR EACH ROW
BEGIN
 CALL flexviews.uow_state_change();
 INSERT INTO demo.products_mvlog VALUES (-1, @__uow_id,OLD.ProductID,OLD.ProductName,OLD.SupplierID,OLD.CategoryID,OLD.QuantityPerUnit,OLD.UnitPrice,OLD.UnitsInStock,OLD.UnitsOnOrder,OLD.ReorderLevel,OLD.Discontinued);
 INSERT INTO demo.products_mvlog VALUES (1, @__uow_id,NEW.ProductID,NEW.ProductName,NEW.SupplierID,NEW.CategoryID,NEW.QuantityPerUnit,NEW.UnitPrice,NEW.UnitsInStock,NEW.UnitsOnOrder,NEW.ReorderLevel,NEW.Discontinued);
 END;
;;

DROP TRIGGER IF EXISTS demo.trig_products_del ;;

CREATE TRIGGER demo.trig_products_del 
AFTER DELETE ON demo.products
FOR EACH ROW
BEGIN
 CALL flexviews.uow_state_change();
 INSERT INTO demo.products_mvlog VALUES (-1, @__uow_id,OLD.ProductID,OLD.ProductName,OLD.SupplierID,OLD.CategoryID,OLD.QuantityPerUnit,OLD.UnitPrice,OLD.UnitsInStock,OLD.UnitsOnOrder,OLD.ReorderLevel,OLD.Discontinued);

END;
;;




 -- MySQL doesn't allow prepared CREATE TRIGGER statements so you will have to 
 -- execute the following statements to create a materialized view log.
 /*** BE VERY CAREFUL *** 
 THE FOLLOWING STATEMENTS WILL FAIL IF YOU HAVE
 EXISTING *AFTER UPDATE|DELETE|INSERT* TRIGGERS
 ON THE SPECIFIED TABLE

 You may either change the triggers to *BEFORE* triggers
 or you can merge your trigger bodies with these trigger bodies.

 Copy everything between (and including) ; to DELIMITER ; and modify as necessary.
 ***/

DROP TABLE IF EXISTS demo.shippers_mvlog;;
CREATE TABLE demo.shippers_mvlog( dml_type INT DEFAULT 0, uow_id BIGINT, ShipperID int(11), CompanyName varchar(40), Phone varchar(24), KEY(uow_id) ) ENGINE=INNODB;;

DROP TRIGGER IF EXISTS demo.trig_shippers_ins ;;

CREATE TRIGGER demo.trig_shippers_ins 
AFTER INSERT ON demo.shippers
FOR EACH ROW
BEGIN
 CALL flexviews.uow_state_change();
 INSERT INTO demo.shippers_mvlog VALUES (1, @__uow_id,NEW.ShipperID,NEW.CompanyName,NEW.Phone);
END;
;;

DROP TRIGGER IF EXISTS demo.trig_shippers_upd ;;

CREATE TRIGGER demo.trig_shippers_upd 
AFTER UPDATE ON demo.shippers
FOR EACH ROW
BEGIN
 CALL flexviews.uow_state_change();
 INSERT INTO demo.shippers_mvlog VALUES (-1, @__uow_id,OLD.ShipperID,OLD.CompanyName,OLD.Phone);
 INSERT INTO demo.shippers_mvlog VALUES (1, @__uow_id,NEW.ShipperID,NEW.CompanyName,NEW.Phone);
 END;
;;

DROP TRIGGER IF EXISTS demo.trig_shippers_del ;;

CREATE TRIGGER demo.trig_shippers_del 
AFTER DELETE ON demo.shippers
FOR EACH ROW
BEGIN
 CALL flexviews.uow_state_change();
 INSERT INTO demo.shippers_mvlog VALUES (-1, @__uow_id,OLD.ShipperID,OLD.CompanyName,OLD.Phone);

END;
;;




 -- MySQL doesn't allow prepared CREATE TRIGGER statements so you will have to 
 -- execute the following statements to create a materialized view log.
 /*** BE VERY CAREFUL *** 
 THE FOLLOWING STATEMENTS WILL FAIL IF YOU HAVE
 EXISTING *AFTER UPDATE|DELETE|INSERT* TRIGGERS
 ON THE SPECIFIED TABLE

 You may either change the triggers to *BEFORE* triggers
 or you can merge your trigger bodies with these trigger bodies.

 Copy everything between (and including) ; to DELIMITER ; and modify as necessary.
 ***/

DROP TABLE IF EXISTS demo.suppliers_mvlog;;
CREATE TABLE demo.suppliers_mvlog( dml_type INT DEFAULT 0, uow_id BIGINT, SupplierID int(11), CompanyName varchar(40), ContactName varchar(30), ContactTitle varchar(30), Address varchar(60), City varchar(15), Region varchar(15), PostalCode varchar(10), Country varchar(15), Phone varchar(24), Fax varchar(24), HomePage text, KEY(uow_id) ) ENGINE=INNODB;;

DROP TRIGGER IF EXISTS demo.trig_suppliers_ins ;;

CREATE TRIGGER demo.trig_suppliers_ins 
AFTER INSERT ON demo.suppliers
FOR EACH ROW
BEGIN
 CALL flexviews.uow_state_change();
 INSERT INTO demo.suppliers_mvlog VALUES (1, @__uow_id,NEW.SupplierID,NEW.CompanyName,NEW.ContactName,NEW.ContactTitle,NEW.Address,NEW.City,NEW.Region,NEW.PostalCode,NEW.Country,NEW.Phone,NEW.Fax,NEW.HomePage);
END;
;;

DROP TRIGGER IF EXISTS demo.trig_suppliers_upd ;;

CREATE TRIGGER demo.trig_suppliers_upd 
AFTER UPDATE ON demo.suppliers
FOR EACH ROW
BEGIN
 CALL flexviews.uow_state_change();
 INSERT INTO demo.suppliers_mvlog VALUES (-1, @__uow_id,OLD.SupplierID,OLD.CompanyName,OLD.ContactName,OLD.ContactTitle,OLD.Address,OLD.City,OLD.Region,OLD.PostalCode,OLD.Country,OLD.Phone,OLD.Fax,OLD.HomePage);
 INSERT INTO demo.suppliers_mvlog VALUES (1, @__uow_id,NEW.SupplierID,NEW.CompanyName,NEW.ContactName,NEW.ContactTitle,NEW.Address,NEW.City,NEW.Region,NEW.PostalCode,NEW.Country,NEW.Phone,NEW.Fax,NEW.HomePage);
 END;
;;

DROP TRIGGER IF EXISTS demo.trig_suppliers_del ;;

CREATE TRIGGER demo.trig_suppliers_del 
AFTER DELETE ON demo.suppliers
FOR EACH ROW
BEGIN
 CALL flexviews.uow_state_change();
 INSERT INTO demo.suppliers_mvlog VALUES (-1, @__uow_id,OLD.SupplierID,OLD.CompanyName,OLD.ContactName,OLD.ContactTitle,OLD.Address,OLD.City,OLD.Region,OLD.PostalCode,OLD.Country,OLD.Phone,OLD.Fax,OLD.HomePage);

END;
;;

DELIMITER ;

