/**********************************************************************************************************************************
    DESCRIPTON:
        Post-Deployment Script Template that is appended to the build script.
**********************************************************************************************************************************/
SET NOCOUNT ON
;
PRINT 'Update table StructuredError.Errors'
;
TRUNCATE TABLE StructuredError.Errors
;
INSERT INTO StructuredError.Errors (ErrorId, ProcedureName, ErrorName, ErrorMessage, DeveloperMessage) 
    VALUES (1000, N'ErrorHandler', N'UnknownError', N'Unknown error message "#ErrorName#" for procedure "#ProcedueName#" is not defined in the error table. #ChildMessage#', NULL)
         , (1001, N'ErrorHandler', N'UnknownSystemError', N'Unknown SQL Server error on server #ServerName# from database #DB#. #ErrorMessage#', NULL)
         , (1002, N'ErrorHandler', N'IndexViolation', N'Unable to perform this operation because there is another record with the same name at the same location.', '#ErrorMessage#')
         , (1003, N'ErrorHandler', N'Deadlock', N'System is currently busy, please try again later.', 'Database deadlock error occurred. #ErrorMessage#')
         , (1100, N'MaintenanceUpdates', N'UnknownError', N'Unknown error message "#ErrorName#" for procedure "#ProcedueName#" is not defined in the error table.', NULL)
         ;
GO

PRINT 'Update table StructuredError.Parameters'
;
DECLARE @Parameters TABLE (
    ParameterName           nvarchar(255)       NOT NULL,
    ParameterValue          nvarchar(max)       NULL,
    ParameterDescription    nvarchar(max)       NULL,
    PRIMARY KEY CLUSTERED (ParameterName)
);
INSERT INTO @Parameters (ParameterName, ParameterValue, ParameterDescription)
    VALUES (N'AuditReadLog', 'false', 'Controls logging of read procedure calls into AuditLog table.')
         , (N'AuditWriteLog', 'false', 'Controls logging of create and update procedure calls into AuditLog table.')
         , (N'DebugMode', 'false', 'Controls display of debugging messages.')
         , (N'PurgePeriod', '<TimeSpan Month="0" Week="1" Day="0" />', 'Defines how long error log information should be retained.')
;
MERGE   StructuredError.Parameters          AS target
USING   @Parameters                         AS source   ON source.ParameterName = target.ParameterName
WHEN MATCHED THEN
        UPDATE SET target.ParameterDescription = source.ParameterDescription
WHEN NOT MATCHED BY TARGET THEN
        INSERT (ParameterName, ParameterValue, ParameterDescription)
        VALUES (ParameterName, ParameterValue, ParameterDescription)
;
GO

PRINT 'Do maintenance updaes.'
;
EXEC StructuredError.MaintenanceUpdates;
GO
