   -- Return endpoint data. If no endpoint exists return ERROR,ERROR,ERROR
    IF EXISTS (	SELECT * FROM sys.database_mirroring_endpoints )
	    SELECT e.NAME AS endpoint_name
		    ,e.state_desc
		    ,t.port
	    FROM sys.database_mirroring_endpoints e
	    INNER JOIN sys.tcp_endpoints t ON e.endpoint_id = t.endpoint_id
	    ORDER BY e.NAME
    ELSE
	    SELECT 'MISSING' AS endpoint_name
		    ,'MISSING' AS state_desc
		    ,'MISSING' AS port

/*
GRANT CONNECT ON endpoint::Mirroring TO [NT Service\MSSQL$INST1]
GRANT CONNECT ON endpoint::Mirroring TO [NT Service\MSSQL$INST2]
*/

/*

alter database AdventureWorks2012 set partner off

restore database AdventureWorks2012 with recovery


*/