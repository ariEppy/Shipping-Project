drop schema if exists shipping_company;
create schema shipping_company;
use shipping_company;
CREATE TABLE Ship
(
    ship_id INT PRIMARY KEY,
    name VARCHAR(20) NOT NULL,
	size VARCHAR(255) not null,
	status VARCHAR(255) not null,
	max_cap INT not null,
    weight int not null,
    unit VARCHAR(20) NOT NULL,
    current_weight INT not null,
    source_id int not null,
    destination_id int not null
)ENGINE = InnoDB;

CREATE TABLE Ports
(
	port_id INT PRIMARY KEY,
	ports_name VARCHAR(255) not null

)ENGINE = InnoDB;

CREATE TABLE Schedule
(
	schedule_id INT PRIMARY KEY,
	depart_date DATEtime ,
	arrive_date DATEtime ,
	ship_id INT not null,
    port_id_source INT not null,
    port_id_destination INT not null,
    route_status VARCHAR(255) not null,
	FOREIGN KEY (ship_id) REFERENCES ship(ship_id),
    FOREIGN KEY (port_id_source) REFERENCES Ports(port_id),
    FOREIGN KEY (port_id_destination) REFERENCES Ports(port_id)

)ENGINE = InnoDB;


CREATE TABLE Actual_Sailing
(
	actual_depart Datetime,
    actual_arrive datetime, 
	schedule_id INT not null,
    port_stop_id int not null,
    ship_id int,
    FOREIGN KEY (schedule_id) REFERENCES Schedule(schedule_id),
    FOREIGN KEY (port_stop_id) REFERENCES Ports(port_id),
    foreign key (ship_id) references Schedule(ship_id)

)ENGINE = InnoDB;

CREATE TABLE Crew
(
	crew_id INT PRIMARY KEY,
	ship_id INT not null,
	FOREIGN KEY (ship_id) REFERENCES Ship(ship_id)
) ENGINE = InnoDB;

create table crew_member
(  
	crew_member_id int primary key,
	name VARCHAR(255) not null,
	role VARCHAR(255) not null,
	crew_id INT not null,
    schedule_id int not null,
	FOREIGN KEY (crew_id) REFERENCES Crew(crew_id),
    Foreign key (schedule_id) references Actual_Sailing(schedule_id)
    )ENGINE = InnoDB;

CREATE TABLE suppliers
(
	supplier_id INT PRIMARY KEY,
    supplier_name VARCHAR(20) NOT NULL,
    supplier_address int NOT NULL
)ENGINE = InnoDB;

CREATE TABLE customers
(
	customer_id INT PRIMARY KEY,
	customer_name VARCHAR(20) NOT NULL,
    customers_address int NOT NULL
)ENGINE = InnoDB;

CREATE TABLE containers (
  container_id INT PRIMARY KEY,
  size VARCHAR(255),
  weight int,
  unit VARCHAR(20) NOT NULL,
  source_id int,
  destination_id int,
  current_weight int
)ENGINE = InnoDB;




CREATE TABLE orders (
  order_id INT PRIMARY KEY,
  supplier_id INT,
  customers_id INT,
  amount int,
  FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id),
  FOREIGN KEY (customers_id) REFERENCES customers(customer_id)
)ENGINE = InnoDB;

CREATE TABLE goods
(
	goods_id INT PRIMARY KEY,
    goods_name VARCHAR(20) NOT NULL,
    weight INT DEFAULT(0),
	unit VARCHAR(20) NOT NULL,
    category VARCHAR(20) NOT NULL,
    supplier_id INT not null,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id)
    )ENGINE = InnoDB;
    
create table delivery
(
	delivery_id int primary key,
    order_id INT,
	container_id INT,
    ship_id int,
    schedule_id INT,
    foreign key (order_id) references orders(order_id),
    foreign key (container_id) references containers(container_id),
    foreign key (ship_id) references Ship(ship_id),
    foreign key (schedule_id) references Schedule(schedule_id)
    )ENGINE = InnoDB;



