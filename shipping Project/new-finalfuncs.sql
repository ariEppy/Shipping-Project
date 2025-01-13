
 -- func 1 :
DELIMITER //
CREATE FUNCTION isDirectTrip(scheduleid INT)
RETURNS Boolean
DETERMINISTIC
BEGIN
    
    DECLARE completed_stops INT;
    
    SELECT COUNT(*) INTO completed_stops
    FROM Actual_Sailing
    WHERE schedule_id = scheduleid;
    
    IF completed_stops = 1 THEN
        RETURN true;
    ELSE
        RETURN false;
    END IF;
END //
DELIMITER ;
-- returns if a schedule was direct or if it had stops on the way

select isDirectTrip(2);
select isDirectTrip(1);

 
-- func 2 :
DELIMITER //
CREATE FUNCTION get_top_customers(N INT)
RETURNS VARCHAR(1000)
DETERMINISTIC
BEGIN
    DECLARE customer_info_list VARCHAR(1000);
    
    SET customer_info_list = (
        SELECT GROUP_CONCAT(CONCAT(subquery.customer_name, ' - ', subquery.order_count, ' orders') SEPARATOR '\n')
        FROM (
            SELECT c.customer_name, COUNT(*) AS order_count
            FROM customers AS c
            JOIN orders AS o ON c.customer_id = o.customers_id
            GROUP BY c.customer_name
            ORDER BY order_count DESC
            LIMIT N
        ) AS subquery
    );
    
    RETURN customer_info_list;
END //
DELIMITER ;


-- give back the customer who bought the most

select get_top_customers(2);

 -- func 3 : 
DELIMITER //
CREATE FUNCTION calculate_average_journey_time(shipid INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE total_journey_time DECIMAL(10,2);
    DECLARE total_journeys INT;
    
    SELECT SUM(DATEDIFF(arrive_date,depart_date)) INTO total_journey_time
    FROM Schedule
    WHERE ship_id = shipid;
    
    SELECT COUNT(*) INTO total_journeys
    FROM Schedule
    WHERE ship_id = shipid;
    
    IF total_journeys > 0 THEN
        RETURN total_journey_time / total_journeys;
    ELSE
        RETURN 0;
    END IF;
END //
DELIMITER ;
-- calculate the number of days it took a ship to complete a sailing

select calculate_average_journey_time(1);

-- func 4 : 
DELIMITER //
CREATE FUNCTION get_ship_status(shipid INT) RETURNS VARCHAR(255)
DETERMINISTIC
BEGIN
    DECLARE ship_status VARCHAR(255);
    
    SELECT status INTO ship_status
    FROM Ship
    WHERE ship_id = shipid;
    
    RETURN ship_status;
END //
DELIMITER ;
-- This function retrieves the status of a ship based on the specified ship_id.
select get_ship_status(1);



-- func 6 : 
DELIMITER //
CREATE FUNCTION count_completed_schedules(shipid INT) RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE completed_schedules INT;
    
    SELECT COUNT(*) INTO completed_schedules
    FROM Schedule
    WHERE ship_id = shipid
    AND route_status = 'Completed';
    
    RETURN completed_schedules;
END //
DELIMITER ;
-- This function counts the number of completed schedules for a ship based on the specified ship_id.

select count_completed_schedules(1);

-- func 7 :
DELIMITER //
CREATE FUNCTION get_schedule_duration(scheduleid INT) RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE duration INT;
    
    SELECT TIMESTAMPDIFF(HOUR, depart_date, arrive_date) INTO duration
    FROM Schedule
    WHERE schedule_id = scheduleid;
    
    RETURN duration;
END //
DELIMITER ;
-- This function calculates the duration in hours between the depart_date and arrive_date of a schedule based on the specified schedule_id.

select get_schedule_duration(1);

-- func 8 :
DELIMITER //
CREATE FUNCTION get_crew_role_count(role_ VARCHAR(255)) RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE role_count INT;
    
    SELECT COUNT(*) INTO role_count
    FROM Crew_member
    WHERE role = role_;
    
    RETURN role_count;
END //
DELIMITER ;
-- This function retrieves the count of crew members with a specific role from the Crew members table based on the provided role.
-- It returns the number of crew members who have the specified role.

select get_crew_role_count('Captain');

-- func 9 :
DELIMITER //

CREATE FUNCTION CHECK_CONTAINER_CAPACITY(containerid INT)
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    DECLARE currentweight INT;
    DECLARE maxweight INT;
    DECLARE available_good INT;
    
    SELECT current_weight, weight INTO currentweight, maxweight
    FROM containers c
    WHERE c.container_id = containerid;
    
	select goods.goods_id into available_good
    from goods
    where maxweight - currentweight >= goods.weight
    LIMIT 1;
    
    IF (currentweight = maxweight) OR available_good is null THEN
        RETURN 'Full';
    ELSE
        RETURN 'Not Full';
    END IF;
END //

DELIMITER ;

-- This function checks if a container has reached its maximum capacity.

select CHECK_CONTAINER_CAPACITY(1);
select CHECK_CONTAINER_CAPACITY(2);

-- func 10 :
DELIMITER //
CREATE FUNCTION calculate_avg_arrival_delay() RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE avg_delay DECIMAL(10,2);
    
    SELECT AVG(TIMESTAMPDIFF(HOUR, Schedule.arrive_date, Actual_Sailing.actual_arrive)) INTO avg_delay
    FROM Actual_Sailing
    JOIN Schedule ON Actual_Sailing.schedule_id = Schedule.schedule_id
    WHERE Schedule.arrive_date IS NOT NULL AND Actual_Sailing.actual_arrive IS NOT NULL;
    
    RETURN avg_delay;
END //
DELIMITER ;
SELECT calculate_avg_arrival_delay();
-- this function calculate the avarage arrival delay of the ships

-- func 11:
DELIMITER $$
CREATE FUNCTION CalculateShipsOnSail() RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE ships_on_sail INT;
    
    SELECT COUNT(*) INTO ships_on_sail
    FROM Schedule
    WHERE route_status = 'scheduled';
    
    RETURN ships_on_sail;
END $$
DELIMITER ;
-- this function calculate how many ships are on sail right now
select CalculateShipsOnSail();


