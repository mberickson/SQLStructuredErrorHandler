CREATE TABLE StructuredError.Errors (
    ErrorId          INT            NOT NULL,
    ProcedureName    VARCHAR (128)  NOT NULL,
    ErrorName        VARCHAR (128)  NOT NULL,
    ErrorMessage     VARCHAR (255)  NOT NULL,
    DeveloperMessage VARCHAR (255)  NULL,
    CONSTRAINT PK_Errors PRIMARY KEY NONCLUSTERED (ErrorId ASC),
    CONSTRAINT UNC_Errors UNIQUE CLUSTERED (ProcedureName ASC, ErrorName ASC)
);
GO
