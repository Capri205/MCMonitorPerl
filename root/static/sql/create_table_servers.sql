CREATE TABLE servers (
	servername		text	primary key not null,
	description		text,
	enginetype		text,
	engineversion	text,
	serverversion	text,
	hostname		text	not null,
	ipaddress		text	not null,
	port			integer not null,
	maintenancemode	integer,
	isup			integer,
	numconnections	integer,
	lastchecked		text,
	state			text,
	rconport		integer,
	rconpassword	text
);