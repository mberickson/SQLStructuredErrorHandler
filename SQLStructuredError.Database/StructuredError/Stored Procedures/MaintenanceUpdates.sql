CREATE PROCEDURE StructuredError.MaintenanceUpdates
AS
/**********************************************************************************************************************************
    DESCRIPTON:
        Perform general maintenance operations for AMP Source Metering database.

    PARAMETERS:
        (none)

    RETURN CODES:
        Always zero.

    NOTES:
        Purges obsolete entries in table "StructuredError.AuditLog".

    EXAMPLE:
        EXEC StructuredError.MaintenanceUpdates
**********************************************************************************************************************************/
SET NOCOUNT ON

BEGIN TRY
    DECLARE @True                           bit                 = 1
    ,       @False                          bit                 = 0
    ;
    DECLARE @RC                             int                 = 0
    ,       @doTran                         bit                 = CASE WHEN @@trancount > 0 THEN @False ELSE @True END
    ,       @AuditLogId                     bigint              = NULL
    ,       @PurgeUtcDatetime               datetime            = DATEADD(week, -1, CONVERT(datetime, CONVERT(date, GETUTCDATE())))
    ;
    EXEC StructuredError.BeginAuditLogProcEntry @AuditLogId OUTPUT, @@PROCID, @False
    ;
    -- Delete any audit records.
    DELETE  TOP(100) al
    FROM    StructuredError.AuditLog        al
    WHERE   ((al.AuditEndTime IS NULL ) OR (al.AuditEndTime < @PurgeUtcDatetime))
    AND     al.AuditStartTime < @PurgeUtcDatetime
    ;
    RETURN @RC;
END TRY
BEGIN CATCH
    IF @doTran = @True AND @@trancount > 0 ROLLBACK;
    EXEC StructuredError.ErrorHandler @@PROCID
END CATCH
GO
