CREATE PROCEDURE StructuredError.BeginAuditLogProcEntry
        @AuditLogId             bigint OUTPUT
      , @CallerProcId           int
      , @ReadonlyProc           bit
      , @xmlParams              XML = NULL
AS
/**********************************************************************************************************************************
    DESCRIPTON:
        Begin audit entry for a store procedure.

    PARAMETERS:
        @AuditLogId                 Output identifier of audit log entry that was created.
        @CallerProcId               Procedure identifier of calling procedure, use global "@@PROCID".
        @ReadonlyProc               Indicates this is a read-only procedure.
        @xmlParams                  Optional, XML object containing parameter definitions in element "params".

    RETURN CODES:
        Always zero.

    NOTES:
        The caller should call "StructuredError.EndAuditLogEntry" or "StructuredError.ErrorHandler" when the procedure is done.

    EXAMPLE:
        See example in procedure "StructuredError.ErrorHandler".
**********************************************************************************************************************************/
SET NOCOUNT ON
;
BEGIN
    DECLARE @True                           bit                 = 1
    ,       @False                          bit                 = 0
    ;
    DECLARE @RC                             int                 = 0
    ,       @parameterName                  varchar(255)        = CASE WHEN @ReadonlyProc = @True THEN 'AuditGetLog' ELSE 'AuditLog' END
    ;
    SET @AuditLogId = NULL
    ;
    IF EXISTS (SELECT TOP(1) 1 FROM StructuredError.Parameters WHERE ParameterName = @parameterName AND ParameterValue LIKE '[yt1]%')
    BEGIN
        IF @xmlParams.exist('/params') = @False
        BEGIN
            SET @xmlParams.modify('insert <params>{(//*[1]/@*)}{(//*[1]/text())}</params> after (/*)[1]');
            SET @xmlParams.modify('delete //*[1]');
        END

        INSERT INTO StructuredError.AuditLog (ProcedureName, InputData)
        SELECT  ProcedureName = OBJECT_NAME(@CallerProcId)
        ,       InputData = @xmlParams
        ;
        SET @AuditLogId = SCOPE_IDENTITY()
        ;
    END

    RETURN @RC;
END
GO
