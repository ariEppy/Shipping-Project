use shipping_company;
-- Inserts for Ship table
INSERT INTO Ship (ship_id, name, size, status, max_cap, weight, unit, current_weight, source_id, destination_id) VALUES 
(0, 'Empty boat', 'none', 'nonexistent', 0, 0, '', 0, 0,0),
(1, 'Ship 1', 'Large', 'Inactive', 2, 100, 'kg', 0, 0,0),
(2, 'Ship 2', 'Medium', 'Inactive', 4, 75, 'kg', 0, 0,0),
(3, 'Ship 3', 'Small', 'Inactive', 2, 50, 'kg', 0,0,0);

-- Inserts for Ports table
INSERT INTO Ports (port_id, ports_name) VALUES 
(0, ''),
(1, 'Barcelona'),
(2, 'Tel Aviv'),
(3, 'Rome'),
(4, 'Crete'),
(5, 'Cyprus');

INSERT INTO Schedule (schedule_id, depart_date, arrive_date, ship_id, port_id_source, port_id_destination, route_status)
VALUES (0, null, null, 0, 0, 0, '');

Insert into Actual_Sailing (actual_depart, actual_arrive, schedule_id, port_stop_id, ship_id)
values (null, null, 0,0,0);

-- Inserts for Crew table
Insert into Crew(crew_id, ship_id) values
(0,0),
(1, 0),
(2, 0);
INSERT INTO crew_member(crew_member_id, name, role, crew_id, schedule_id) VALUES 
(1, 'John Doe', 'Captain', 1, 0),
(2, 'Jane Smith', 'Engineer', 1, 0),
(3, 'Mike Johnson', 'Deckhand', 0, 0),
(4, 'Bob Doe', 'Captain',0 , 0),
(5, 'Jill Smith', 'Engineer', 0, 0),
(6, 'Matt Johnson', 'Deckhand', 0, 0)
;

-- Inserts for suppliers table
INSERT INTO suppliers (supplier_id, supplier_name, supplier_address) VALUES 
(1, 'Supplier 1', 1),
(2, 'Supplier 2', 3),
(3, 'Supplier 3', 2);

-- Inserts for customers table
INSERT INTO customers (customer_id, customer_name, customers_address) VALUES 
(1, 'Customer 1', 1),
(2, 'Customer 2', 2),
(3, 'Customer 3', 3),
(4, 'Customer 4', 2);


-- Inserts for containers table 
INSERT INTO containers (container_id, size, weight, unit, source_id, destination_id, current_weight) VALUES 

(1, 'Large', 100, 'kg', 0,0,0),
(2, 'Medium', 50, 'kg',0,0,0),
(3, 'Small', 25, 'kg',0,0,0);

-- Inserts for goods table 
INSERT INTO goods (goods_id, goods_name, weight, unit, category, supplier_id) VALUES 
(1, 'BMW', 50, 'kg', 'Cars', 1),
(2, 'Cucumbers', 6, 'kg', 'Veg', 2),
(3, 'Apples', 5, 'kg', 'Fruit', 3);



