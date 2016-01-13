CREATE TABLE StructuredError.AuditLog (
    AuditLogId              bigint              IDENTITY (1, 1) NOT NULL,
    ProcedureName           VARCHAR(255)        NOT NULL,
    InputData               XML                 NULL,
    OuputData               XML                 NULL,
    ErrorMessage            XML                 NULL,
    AuditStartTime          datetime2           NOT NULL CONSTRAINT [DF_AuditLog_AuditTime] DEFAULT (GETUTCDATE()), 
    AuditEndTime            datetime2           NULL, 
    CONSTRAINT PK_AuditLog PRIMARY KEY CLUSTERED (AuditLogId)
);
GO
