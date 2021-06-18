use arcadia_cbos
go
SELECT * FROM journalclosenotification
where journalclose_journalcloseid in (
	select j.journalcloseid 
	from journalclose j 
    inner join gasstation g
		on j.gasStation_gasStationID = g.gasstationid
	where g.posGasStationID =6064
	and j.businessDate = '2021-02-19'
	and j.shift = 4
);