CREATE PROCEDURE StructuredError.ErrorHandler
        @CallerProcId             int = 0
      , @AuditLogId               bigint = NULL
      , @ThrownErrorCapture       VARCHAR(max) = NULL
AS
/**********************************************************************************************************************************
    DESCRIPTON:
        General error handler to process structure error messages in the catch block of a try-catch statement.

    PARAMETERS:
        @CallerProcId               Procedure identifier of calling procedure, use global "@@PROCID".
        @AuditLogId                 Optional audit log entry that should be updated with error information.
        @ThrownErrorCapture         Optional previously capture error data. See notes below.

    RETURN CODES:
        Always zero.

    NOTES:
        This procedure obtains error status from the current value of the SQL "ERROR_..." functions. Sometimes it is necessary
        to perform cleanup operations prior to calling this procedure that will change the values of these functions. Therefore
        you can capture the value of these functions prior to cleanup operations and then pass it to this procedure. Keep in
        mine that the "IF", "WHILE" and "ROLLBACK" statements do not change the value of the error functions.

    EXAMPLE:
        Below is the following template for appropriate error handling in a procedure.

            CREATE PROCEDURE dbo.GetMeterEntityStatus
                    @intParam                   int
                ,   @stringParam                varchar(max)
                ,   @dateTimeParam              datetime
            AS
            BEGIN TRY
                DECLARE @True                           bit                 = 1
                ,       @False                          bit                 = 0
                ,       @CrLf                           nvarchar(2)         = CHAR(13) + CHAR(10)
                ,       @ProcedureName                  nvarchar(255)       = OBJECT_NAME(@@PROCID)
                ;
                DECLARE @RC                             int                 = 0
                ,       @doTran                         bit                 = CASE WHEN @@trancount > 0 THEN @False ELSE @True END
                ,       @AuditLogId                     bigint              = NULL
                ,       @InputData                      nvarchar(max)       =
                                '@intParam=' + ISNULL(CONVERT(nvarchar(40), @intParam), 'NULL')
                            + ', @stringParam=' + ISNULL('''' + @stringParam + '''', 'NULL')
                            + ', @dateTimeParam=' + ISNULL(CONVERT(nvarchar(40), @dateTimeParam), 'NULL')
                            + ' ;'
                ;
                EXEC StructuredError.BeginAuditLogProcEntry @AuditLogId OUTPUT, @@PROCID, @True,
                        (SELECT * FROM (SELECT intParam=@intParam, stringParam=@stringParam, dateTimeParam=@dateTimeParam) AS params FOR XML AUTO)
                ;

                -- Define procedure code here. --

                IF @someValue IS NULL
                BEGIN
                    -- Some error occurred.
                    SET @ErrorMessage = StructuredError.ErrorLookup(@ProcedureName, 'SomeError', (SELECT * FROM (SELECT someValue1=@someValue1, someValue2=@someValue2, someValue3=@someValue3) AS T FOR XML AUTO))
                    RAISERROR(@ErrorMessage, 16, 10);
                END

                -- Define procedure code here. --

                EXEC StructuredError.EndAuditLogEntry @AuditLogId, @@PROCID
                ;
                RETURN @RC;
            END TRY
            BEGIN CATCH
                DECLARE @ThrownErrorCapture VARCHAR(max) = (SELECT * FROM (SELECT ErrorNumber=ERROR_NUMBER(), ErrorMessage=ERROR_MESSAGE(), ErrorProcedure=ERROR_PROCEDURE(), ErrorLine=ERROR_LINE(), ErrorSeverity=ERROR_SEVERITY(), ErrorState=ERROR_STATE()) AS T FOR XML AUTO) ;
                IF @doTran = @True AND @@trancount > 0 ROLLBACK;

                -- Some cleanup operations here. --

                EXEC StructuredError.ErrorHandler @@PROCID, @AuditLogId, @ThrownErrorCapture
            END CATCH
**********************************************************************************************************************************/
SET NOCOUNT ON
;
BEGIN
    DECLARE @True                       bit = 1
    ,       @False                      bit = 0
    ,       @ErrorIndexViolation        int = 2601
    ,       @ErrorDeadlock              int = 1205
    ,       @ErrorUserDefined           int = 50000
    ;
    DECLARE @Severity                   int = ERROR_SEVERITY()
    ,       @State                      int = ERROR_STATE()
    ,       @Line                       int = ERROR_LINE()
    ,       @ErrorNumber                int = ERROR_NUMBER()
    ,       @ErrorMessage               varchar(max) = ERROR_MESSAGE()
    ,       @Procedure                  sysname = ISNULL(ERROR_PROCEDURE(), '')
    ,       @CallProc                   sysname = OBJECT_NAME(@CallerProcId)
    ,       @ErrorId                    bigint = NULL
    ,       @ErrorXML                   xml = NULL
    ,       @LogAppErrors               bit = 0
    ;
    -- Check for previously captured error information.
    IF @ThrownErrorCapture IS NOT NULL
    BEGIN
        SET @ErrorXML       = CONVERT(xml, @ThrownErrorCapture) ;
        SET @Severity       = @ErrorXML.value('(/T/@ErrorSeverity)[1]', 'int') ;
        SET @State          = @ErrorXML.value('(/T/@ErrorState)[1]', 'int') ;
        SET @ErrorNumber    = @ErrorXML.value('(/T/@ErrorNumber)[1]', 'int') ;
        SET @ErrorMessage   = @ErrorXML.value('(/T/@ErrorMessage)[1]', 'VARCHAR(max)') ;
        SET @Procedure      = @ErrorXML.value('(/T/@ErrorProcedure)[1]', 'sysname') ;
        SET @Line           = @ErrorXML.value('(/T/@ErrorLine)[1]', 'int') ;
        SET @ErrorXML.modify('delete /T') ;
        IF 0 = @ErrorXML.exist('/*') SET @ErrorXML = NULL ;
    END

    -- Display error for debugging purposes.
    IF EXISTS (SELECT 1 FROM StructuredError.Parameters WHERE ParameterName = 'DebugMode' AND ParameterValue LIKE '[yt1]%')
    BEGIN
        PRINT '-------------------------------------------' ;
        PRINT 'ErrorHandler: ' + COALESCE( @Procedure, '(null procedure)')
                               + COALESCE('[' + CONVERT(varchar(11), @Line) + ']', '') + ': '
                               + COALESCE(CONVERT(varchar(11), @ErrorNumber) + '-', '(unknown error number)-')
                               + COALESCE( @ErrorMessage, '(null message)')
        ;
        PRINT 'ErrorHandler: @Procedure=' + COALESCE(@Procedure, '(null)') ;
        PRINT 'ErrorHandler: @Line=' + COALESCE(CONVERT(varchar(11), @Line), '(null)') ;
        PRINT 'ErrorHandler: @ErrorNumber=' + COALESCE(CONVERT(varchar(11), @ErrorNumber), '(null)') ;
        PRINT 'ErrorHandler: @ErrorMessage=' + COALESCE(@ErrorMessage, '(null)') ;
        PRINT 'ErrorHandler: @CallerProcId=' + COALESCE(CONVERT(varchar(40), @CallerProcId), '(null)') ;
        PRINT 'ErrorHandler: Object_name(@CallerProcId)=' + COALESCE(Object_name(@CallerProcId), '(null)') ;
        PRINT 'ErrorHandler: @@procid=' + COALESCE(CONVERT(varchar(40), @@procid), '(null)') ;
        PRINT 'ErrorHandler: Object_name(@@procid)=' + COALESCE(Object_name(@@procid), '(null)') ;
        PRINT '-------------------------------------------' ;
    END

    -- If the error was raised from this SP, then do not include the details in the error being raised.
    -- However, rethrow the error that had been caught for the other SPs.
    IF @Procedure = Object_name(@@procid)
    BEGIN
        SET @ErrorXML = StructuredError.ErrorConvertToXML(@ErrorMessage, (SELECT * FROM (SELECT CalledBy=@CallProc, Line=@Line, DB=DB_NAME(), SPID=@@spid) AS T FOR XML AUTO), @ErrorXML) ;

        IF @AuditLogId IS NOT NULL
        BEGIN
            UPDATE  a
            SET     ErrorMessage = CONVERT(VARCHAR(max), @ErrorXML)
            ,       AuditEndTime = GETUTCDATE()
            FROM    StructuredError.AuditLog                    a
            WHERE   a.AuditLogId = @AuditLogId
            ;
        END

        SET @ErrorMessage = StructuredError.ErrorConvertToString(@ErrorXML, @True) ;
        RAISERROR(@ErrorMessage, @Severity, @State) ;
        RETURN;
    END

    -- This makes the details of the original error known to the caller (i.e. Middle Tier), while making the more friendly error
    -- the last error on the error stack that will be re-thrown by the MT if desired
    IF @ErrorNumber >= @ErrorUserDefined
    BEGIN
        -- Assume error generated from ErrorLookup.
        IF @CallProc = @Procedure SET @CallProc = NULL ;
        SET @ErrorXML = StructuredError.ErrorConvertToXML(@ErrorMessage, (SELECT * FROM (SELECT CalledBy=@CallProc, ThrownBy=@Procedure, ThrownLine=@Line, DB=DB_NAME(), SPID=@@spid) AS T FOR XML AUTO), @ErrorXML) ;

        IF @AuditLogId IS NOT NULL
        BEGIN
            UPDATE  a
            SET     ErrorMessage = CONVERT(VARCHAR(max), @ErrorXML)
            ,       AuditEndTime = GETUTCDATE()
            FROM    StructuredError.AuditLog                    a
            WHERE   a.AuditLogId = @AuditLogId
            ;
        END
        SET @ErrorMessage = StructuredError.ErrorConvertToString(@ErrorXML, @True) ;
        RAISERROR(@ErrorMessage, @Severity, @State) ;
        RETURN;
    END

    IF @ErrorNumber = @ErrorIndexViolation
    BEGIN
        SET @ErrorMessage = StructuredError.ErrorLookup(OBJECT_NAME(@@PROCID), 'IndexViolation', (SELECT * FROM (SELECT ErrorNumber=@ErrorNumber, ErrorMessage=@ErrorMessage, PROCID=@CallerProcId, ThrownBy=@Procedure, ThrownLine=@Line, ServerName=@@SERVERNAME, DB=DB_NAME(), SPID=@@spid) AS T FOR XML AUTO)) ;

        IF @AuditLogId IS NOT NULL
        BEGIN
            UPDATE  a
            SET     ErrorMessage = @ErrorMessage
            ,       AuditEndTime = GETUTCDATE()
            FROM    StructuredError.AuditLog                    a
            WHERE   a.AuditLogId = @AuditLogId
            ;
        END

        RAISERROR(@ErrorMessage, @Severity, @State) ;
        RETURN;
    END

    IF @ErrorNumber = @ErrorDeadlock
    BEGIN
        SET @ErrorMessage = StructuredError.ErrorLookup(OBJECT_NAME(@@PROCID), 'Deadlock', (SELECT * FROM (SELECT ErrorNumber=@ErrorNumber, ErrorMessage=@ErrorMessage, PROCID=@CallerProcId, ThrownBy=@Procedure, ThrownLine=@Line, ServerName=@@SERVERNAME, DB=DB_NAME(), SPID=@@spid) AS T FOR XML AUTO)) ;

        IF @AuditLogId IS NOT NULL
        BEGIN
            UPDATE  a
            SET     ErrorMessage = @ErrorMessage
            ,       AuditEndTime = GETUTCDATE()
            FROM    StructuredError.AuditLog                    a
            WHERE   a.AuditLogId = @AuditLogId
            ;
        END

        RAISERROR(@ErrorMessage, @Severity, @State) ;
        RETURN;
    END

    -- Throw the unknown error.
    SET @ErrorMessage = StructuredError.ErrorLookup(OBJECT_NAME(@@PROCID), 'UnknownSystemError', (SELECT * FROM (SELECT ErrorNumber=@ErrorNumber, ErrorMessage=@ErrorMessage, PROCID=@CallerProcId, ThrownBy=@Procedure, ThrownLine=@Line, ServerName=@@SERVERNAME, DB=DB_NAME(), SPID=@@spid) AS T FOR XML AUTO)) ;

    IF @AuditLogId IS NOT NULL
    BEGIN
        UPDATE  a
        SET     ErrorMessage = @ErrorMessage
        ,       AuditEndTime = GETUTCDATE()
        FROM    StructuredError.AuditLog                    a
        WHERE   a.AuditLogId = @AuditLogId
        ;
    END

    RAISERROR(@ErrorMessage, @Severity, @State) ;
    RETURN;
END
GO
