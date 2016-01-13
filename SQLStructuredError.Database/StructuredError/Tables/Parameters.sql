CREATE TABLE StructuredError.Parameters (
    ParameterName           nvarchar(255)       NOT NULL,
    ParameterValue          nvarchar(max)       NULL,
    ParameterDescription    nvarchar(max)       NULL,
 CONSTRAINT PK_Parameters PRIMARY KEY CLUSTERED (ParameterName)
);
GO
