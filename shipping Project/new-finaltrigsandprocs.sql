DELIMITER //
-- fit the order in a container
CREATE TRIGGER put_order_in_container
AFTER INSERT ON orders
FOR EACH ROW
BEGIN
    DECLARE supplier_address INT;
    DECLARE customer_address INT;
    DECLARE good_weight INT;
    DECLARE order_amount INT;
    DECLARE container_id INT;
    DECLARE current_weight INT;
    DECLARE source_id INT;
    DECLARE destination_id INT;
    declare this_delivery_id int;
    
    -- Get supplier and customer addresses
    SELECT suppliers.supplier_address INTO supplier_address
    FROM suppliers
    WHERE suppliers.supplier_id = NEW.supplier_id;

    SELECT customers.customers_address INTO customer_address
    FROM customers
    WHERE customers.customer_id = NEW.customers_id;

    -- make sure that customer and supplier are from different ports
    IF supplier_address != customer_address THEN
        -- find a container to fit the goods*weight
        SELECT goods.weight, orders.amount INTO good_weight, order_amount
        FROM goods, orders  
        WHERE goods.supplier_id = NEW.supplier_id AND orders.order_id = NEW.order_id and
        goods.supplier_id = orders.supplier_id;

        SELECT containers.container_id, containers.current_weight, containers.source_id, containers.destination_id
        INTO container_id, current_weight, source_id, destination_id
        FROM containers
        WHERE containers.weight-containers.current_weight >= good_weight * order_amount
        AND ((containers.source_id = 0  AND containers.destination_id = 0)
             OR (containers.source_id = supplier_address AND containers.destination_id = customer_address))
        LIMIT 1;


        -- Update the delivery table
		SET this_delivery_id = (SELECT COALESCE(MAX(delivery_id), 0) + 1 FROM delivery);
        INSERT INTO delivery (delivery_id, order_id, container_id, ship_id, schedule_id)
        VALUES (this_delivery_id, NEW.order_id, container_id, 0, 0);
        
        -- Update the container's details
            UPDATE containers
            SET current_weight = current_weight + (good_weight * order_amount),
                source_id = supplier_address,
                destination_id = customer_address
            WHERE containers.container_id = container_id;
            

    END IF;
END //

DELIMITER ;

DELIMITER //

CREATE TRIGGER put_container_on_ship_if_container_full
AFTER UPDATE ON containers
FOR EACH ROW
BEGIN
    DECLARE container_weight int;
    DECLARE container_current_weight INT;
    DECLARE container_source_id INT;
    DECLARE container_destination_id INT;
    DECLARE container_full BOOLEAN;
    DECLARE available_ship_id INT;
    declare available_good int;
    

    -- Get container's details after the update
    SELECT weight, current_weight, source_id, destination_id
    INTO container_weight, container_current_weight, container_source_id, container_destination_id
    FROM containers
    WHERE container_id = NEW.container_id;

	
    -- Check if the containers full
    select goods.goods_id into available_good
    from goods
    where container_weight - container_current_weight >= goods.weight
     LIMIT 1;
    
    SET container_full = ((container_current_weight = container_weight) OR (available_good is null));

    -- if its full then find an available ship (with enough weight and the same source/destination as the container)
    IF container_full THEN
        
        SELECT ship_id
        INTO available_ship_id
        FROM Ship
        WHERE weight - current_weight >= container_current_weight
		and ((Ship.source_id = container_source_id and Ship.destination_id = container_destination_id) or (Ship.source_id = 0 and Ship.destination_id =0))
        LIMIT 1;

        -- Update the available ship's current weight, source ID, and destination ID
        IF available_ship_id IS NOT NULL THEN
            UPDATE Ship
            SET current_weight = current_weight + container_current_weight,
                source_id = container_source_id,
                destination_id = container_destination_id,
                status = 'Active'
            WHERE ship_id = available_ship_id;

            -- Update the ship ID in delivery
            UPDATE delivery
            SET ship_id = available_ship_id
            WHERE container_id = NEW.container_id;
            

            
        END IF;
    END IF;
END //

DELIMITER ;

DELIMITER //

CREATE TRIGGER ship_is_full_so_set_schedule
AFTER UPDATE ON Ship
FOR EACH ROW
BEGIN
    -- Check if ship's weight equals current_weight or if the current weight is at its max possible
   declare available_container int;
   declare this_schedule_id int;

            
   select containers.container_id into available_container
   from containers, ship, delivery
   where containers.container_id = delivery.container_id and
   delivery.ship_id = ship.ship_id and 
   ship.weight - ship.current_weight >= containers.weight
   LIMIT 1;
   
    -- if the ship is at its fullest weight then
    IF NEW.current_weight = NEW.weight or available_container is null THEN
        -- Insert a row into Schedule
        
        SET this_schedule_id = (SELECT COALESCE(MAX(schedule_id), 0) + 1 FROM schedule);
        INSERT INTO Schedule (schedule_id, depart_date, arrive_date, ship_id, port_id_source, port_id_destination, route_status)
        VALUES (this_schedule_id, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 2 DAY), NEW.ship_id, NEW.source_id, NEW.destination_id, 'scheduled');
       
		END IF;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER inserted_Schedule_assign_crew
AFTER insert ON Schedule
FOR EACH ROW
BEGIN
	declare available_crew int;
    -- find an available crew
	select crew_id into available_crew
   from Crew
   where ship_id = 0 and crew_id != 0
   LIMIT 1;
   -- if we have a crew available then set its ship id
   if available_crew is not null then 
   update Crew set ship_id = new.ship_id where crew_id = available_crew; 
   end if;
END //
DELIMITER ;


DELIMITER //
CREATE TRIGGER update_Schedule_Delivery
AFTER UPDATE ON Schedule
FOR EACH ROW
BEGIN
    IF NEW.route_status = 'Completed' THEN
        -- Update the schedule_id in delivery
        UPDATE delivery
        SET schedule_id = NEW.schedule_id
        WHERE (ship_id = NEW.ship_id) AND (schedule_id = 0 OR schedule_id IS NULL);
    END IF;
END //
DELIMITER ;
-- before we set actual sail we need to be sure we have a full crew on board. if we can set sail then check if we have completed our trip
DELIMITER //
CREATE TRIGGER update_statuses_and_weights_if_completed
before insert ON Actual_Sailing
FOR EACH ROW
BEGIN
    DECLARE destination_id INT;
    DECLARE schedule_status VARCHAR(255);
    DECLARE ship_status VARCHAR(255);
    declare has_crew int;
    declare amount_of_crew int;
    declare cap int;
 
	-- before we actually set sail we need to make sure that our ship has a crew and that its a full crew
    select crew_id into has_crew from Crew where ship_id = new.ship_id;
    select count(crew_id) into amount_of_crew from crew_member where crew_id = has_crew;
    select max_cap into cap from Ship where ship_id = new.ship_id;
    
    if has_crew is not null and amount_of_crew = cap then
    SELECT port_id_destination INTO destination_id
    FROM Schedule
    WHERE schedule_id = NEW.schedule_id
    order by schedule_id
    limit 1;
    
    IF NEW.port_stop_id = destination_id THEN
        SET schedule_status = 'completed';
        SET ship_status = 'Inactive';
       
        
        UPDATE Schedule SET route_status = schedule_status WHERE schedule_id = NEW.schedule_id;
        UPDATE Ship SET status = ship_status, source_id =0, destination_id =0, current_weight = 0 WHERE ship_id = NEW.ship_id;
        UPDATE containers SET current_weight = 0, source_id = 0, destination_id = 0 WHERE container_id in (SELECT container_id FROM Delivery WHERE ship_id = NEW.ship_id);
		-- release the crew and its members
        update crew_member set crew_id = 0, schedule_id = 0 where crew_id = (select crew_id from Crew where ship_id = new.ship_id);
        update crew set ship_id = 0 where ship_id = new.ship_id;
    END IF;
   end if;
	if has_crew is null then
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot insert a row into actual_sailing because this ship does not have a crew.';
    END IF;
    if amount_of_crew < cap then
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot insert a row into actual_sailing because this ship does not have a full crew yet.';
    END IF;
    
END //
DELIMITER ;
-- after we insert an actual sailing row -> update the crew members schedule id
DELIMITER //
CREATE TRIGGER set_crew_member_schedule
after INSERT ON Actual_Sailing
FOR EACH ROW
BEGIN
	declare destination_id int;

    SELECT port_id_destination INTO destination_id
    FROM Schedule
    WHERE schedule_id = NEW.schedule_id
    order by schedule_id
    limit 1;
    
    IF NEW.port_stop_id != destination_id THEN
	update crew_member set schedule_id = new.schedule_id 
    where crew_id = (select crew_id from crew where ship_id = new.ship_id);
    end if;
end //
delimiter ;

-- if we want to add a crew member to a crew then make sure its not full and it has a ship associated with it
DELIMITER //
CREATE TRIGGER add_crew_member_to_crew
before update ON crew_member
FOR EACH ROW
BEGIN
	
    DECLARE max_capacity INT;
    DECLARE current_capacity INT;
    declare crew_has_ship int;
    
    select ship_id into crew_has_ship from crew where crew_id = new.crew_id;
    if old.crew_id != new.crew_id and old.crew_id = 0 and crew_has_ship = 0 then
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'crew is not assigned to a ship yet';
    end if;
	 if old.crew_id != new.crew_id and old.crew_id = 0 and crew_has_ship != 0 then
    SELECT max_cap INTO max_capacity
    FROM Ship
    WHERE ship_id = (select ship_id from crew where crew_id = new.crew_id)
   ;

    SELECT COUNT(*) INTO current_capacity
    FROM Crew_member
    WHERE crew_id = new.crew_id;

    IF current_capacity = max_capacity THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ship is already full of crew members';
    END IF;
    end if;
END //
DELIMITER ;

-- we only allow for one supplier to have one good - these two triggers makes sure of it!
DELIMITER //
CREATE TRIGGER check_duplicate_supplier_id_insert
BEFORE INSERT ON goods
FOR EACH ROW
BEGIN
    DECLARE duplicatesCount INT;
    
    SET duplicatesCount = (
        SELECT COUNT(*)
        FROM goods
        WHERE supplier_id = NEW.supplier_id
    );
    
    IF duplicatesCount > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Duplicate supplier_id is not allowed.';
    END IF;
END //

DELIMITER //

CREATE TRIGGER check_duplicate_supplier_id_update
BEFORE UPDATE ON goods
FOR EACH ROW
BEGIN
    DECLARE duplicatesCount INT;
    
    SET duplicatesCount = (
        SELECT COUNT(*)
        FROM goods
        WHERE supplier_id = NEW.supplier_id
          AND goods_id <> NEW.goods_id
    );
    
    IF duplicatesCount > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Duplicate supplier_id is not allowed.';
    END IF;
END //

DELIMITER ;


DELIMITER //
CREATE PROCEDURE GetShipDetails(IN shipId INT)
BEGIN
    SELECT * 
    FROM Ship
    WHERE ship_id = shipId;
END//
DELIMITER ;
#call GetShipDetails(1);

DELIMITER //
CREATE PROCEDURE CalculateGoodsWeightInOrder(IN orderId INT)
BEGIN
    DECLARE amount1 INT;
    DECLARE supplierID INT;
    DECLARE weight1 INT;
    
    SELECT amount, supplier_id INTO amount1, supplierID
    FROM Orders
    WHERE order_id = orderId;
    
    SELECT weight INTO weight1
    FROM goods
    WHERE supplier_id = supplierID;
   
    select (weight1*amount1) as goods_weight;
    
END//
DELIMITER ;
#call CalculateGoodsWeightInOrder(2);

DELIMITER //
CREATE PROCEDURE GetPortDetails(IN portId INT)
BEGIN
    SELECT * FROM Ports WHERE port_id = portId;
END//
DELIMITER ;
#call GetPortDetails(2);

DELIMITER //
CREATE PROCEDURE CalculateContainerWeightRatio(IN containerId INT)
BEGIN
	declare ratio DECIMAL(5,2);
    
    SELECT (current_weight / weight) as containerWeightRatio FROM containers WHERE container_id = containerId;
END//
DELIMITER ;
#call CalculateContainerWeightRatio(1);

DELIMITER //
CREATE PROCEDURE GetSupplierOrders(IN supplierId INT)
BEGIN
    SELECT * FROM orders WHERE supplier_id = supplierId;
END//
DELIMITER ;
#call GetSupplierOrders(1);

-- if we want to add to an order thats not yet on a ship we can
DELIMITER //
CREATE PROCEDURE AddToOrderNewAmount(IN orderId INT, IN newAmount INT)
BEGIN
    DECLARE supId INT;
    DECLARE custId INT;
    DECLARE oldAmount INT;
    DECLARE weight1 INT;
    DECLARE newWeight INT;
    DECLARE oldWeight INT;
    DECLARE shipId INT;
    DECLARE contId INT;
    DECLARE containerCurr INT;
    DECLARE containWeight INT;
    DECLARE this_order_id INT;
    
    SELECT supplier_id, amount, customers_id INTO supId, oldAmount, custId FROM orders WHERE order_id = orderId;
    SELECT weight INTO weight1 FROM goods WHERE supplier_id = supId;
    SET newWeight = (weight1 * newAmount);
    SET oldWeight = (weight1 * oldAmount);
    
    SELECT container_id, ship_id INTO contId, shipId FROM delivery WHERE order_id = orderId; 
    SELECT current_weight, weight INTO containerCurr, containWeight FROM containers WHERE container_id = contId;

    -- Check if the new amount is greater than the old amount 
    IF newAmount > oldAmount THEN
        -- Check if we can fit the new amount into the existing container
        IF (containerCurr - oldWeight + newWeight) <= containWeight AND shipId = 0 THEN
            UPDATE orders SET amount = newAmount WHERE order_id = orderId;
            UPDATE Containers SET current_weight = containerCurr - oldWeight + newWeight WHERE container_id = contId;
        END IF;
        -- If we can't fit the new order in the existing container (and the container isn't on the ship yet), then delete the previous order and insert a new order
        else IF (containerCurr - oldWeight + newWeight) > containWeight AND shipId = 0 THEN
            DELETE FROM Orders WHERE order_id = orderId;
			UPDATE Containers SET current_weight = containerCurr - oldWeight WHERE container_id = contId;
            DELETE FROM Delivery WHERE order_id = orderId;
            SET this_order_id = (SELECT COALESCE(MAX(order_id), 0) + 1 FROM orders);
            INSERT INTO Orders VALUES (this_order_id, supId, custId, newAmount);
        END IF;
    END IF;
END//
DELIMITER ;
#select * from orders;
#select * from containers;
#insert into orders values (7,2, 4,2); 
#call AddToOrderNewAmount(7,3);

-- if we want to lower our amount of our order then we can (as long as its not yet on a ship)
DELIMITER //
CREATE PROCEDURE SubtractFromOrderNewAmount(IN orderId INT, IN newAmount INT)
BEGIN
    DECLARE supId INT;
    DECLARE custId INT;
    DECLARE oldAmount INT;
    DECLARE weight1 INT;
    DECLARE newWeight INT;
    DECLARE oldWeight INT;
    DECLARE shipId INT;
    DECLARE contId INT;
    DECLARE containerCurr INT;
    DECLARE containWeight INT;
    DECLARE this_order_id INT;
    
    SELECT supplier_id, amount, customers_id INTO supId, oldAmount, custId FROM orders WHERE order_id = orderId;
    SELECT weight INTO weight1 FROM goods WHERE supplier_id = supId;
    SET newWeight = (weight1 * newAmount);
    SET oldWeight = (weight1 * oldAmount);
    
    SELECT container_id, ship_id INTO contId, shipId FROM delivery WHERE order_id = orderId; 
    SELECT current_weight, weight INTO containerCurr, containWeight FROM containers WHERE container_id = contId;

    -- Check if the subtracted amount is valid
    IF newAmount <= oldAmount THEN
        -- Check if we can fit the updated amount into the existing container
        IF (newAmount != 0 and shipId = 0) THEN
            UPDATE orders SET amount = newAmount WHERE order_id = orderId;
            UPDATE Containers SET current_weight = containerCurr - oldWeight + newWeight WHERE container_id = contId;
        END IF;
        -- if the new amount is 0 - cancelled their order then
		IF (newAmount = 0 AND shipId = 0) THEN
			UPDATE Containers SET current_weight = 0, source_id = 0, destination_id=0 WHERE container_id = contId;
			DELETE FROM Delivery WHERE order_id = orderId;
            DELETE FROM Orders WHERE order_id = orderId;
			
            
        END IF;
    END IF;
END//

DELIMITER ;
#select * from orders;
#select * from containers;
#call SubtractFromOrderNewAmount(10,2);

DELIMITER //
CREATE PROCEDURE GetCustomerOrders(IN customerId INT)
BEGIN
    SELECT * FROM orders WHERE customers_id = customerId;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE getOrderStatuses()
BEGIN
	
	select orders.*, Schedule.route_status 
    from orders, delivery, Schedule
    where orders.order_id = delivery.order_id and delivery.schedule_id = Schedule.schedule_id;
END//
DELIMITER ;
#call getOrderStatuses();

DELIMITER //
CREATE PROCEDURE GetCrewCount(in crew int)
BEGIN
    select count(*)
    from crew_member
    where crew_id = crew;
END//
DELIMITER ;

#call GetCrewCount(1);

-- Insert a new order
INSERT INTO orders VALUES (1, 1, 2, 1);
select * from containers;
select * from ship;
insert into orders values (2,1,4,1);
select * from containers;
select * from ship;
select * from schedule;
select * from crew;
select * from crew_member;
insert into Actual_Sailing
value ('2023-05-25 00:00:00', '2023-05-27 00:00:00', 1, 3, 1);
select * from crew_member; 
INSERT INTO suppliers (supplier_id, supplier_name, supplier_address) VALUES 
(4, 'Supplier 4', 4);
insert into goods values (4, 'Strawberries', 5, 'kg', 'Fruit', 4);
   insert into Actual_Sailing
    value ('2023-05-27 00:05:00', '2023-05-27 00:30:00', 1, 2, 1);
    select * from Actual_Sailing;
     select * from crew_member;
     select * from crew;
       
       select * from Ship;
       select * from Schedule;
       select * from delivery;
     # update crew_member set crew_id = 2 where crew_member_id = 3;
      select * from crew_member;
     select * from crew;
     INSERT INTO orders VALUES (3, 1, 2, 1);
insert into orders values (4,1,4,1);
 select * from Ship;
       select * from Schedule;
       select * from delivery;
       update crew_member set crew_id = 1 where crew_member_id = 5;
        update crew_member set crew_id = 1 where crew_member_id = 3;
        insert into Actual_Sailing
    value ('2023-05-27 00:05:00', '2023-05-27 00:30:00', 2, 2, 1);
     select * from Ship;
       select * from Schedule;
       select * from delivery;
       INSERT INTO orders VALUES (5, 1, 2, 1);
insert into orders values (6,1,4,1);
       update crew_member set crew_id = 1 where crew_member_id = 5;
        update crew_member set crew_id = 1 where crew_member_id = 3;
       