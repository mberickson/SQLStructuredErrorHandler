CREATE FUNCTION StructuredError.ErrorConvertToXML(@ErrorMessage VARCHAR(max), @xmlBefore xml = NULL, @xmlAfter xml = NULL)
RETURNS xml
AS
/**********************************************************************************************************************************
    DESCRIPTON:
        Convert an error message string into a structured error message in XML format.

    PARAMETERS:
        @ErrorMessage               Error message to convert.

    RETURN:
        Resulting structured error message in XML form.
**********************************************************************************************************************************/
BEGIN
    DECLARE @ErrorXML           XML = NULL        -- Developer error message.
          , @True               bit = 1
          , @False              bit = 0
          ;

    -- Try converting to XML.
    SET @ErrorXML = NULL ;
    IF SUBSTRING(LTRIM(@ErrorMessage), 1, 1) = '<'
        SET @ErrorXML = CONVERT(xml, @ErrorMessage) ;

    IF @ErrorXML IS NULL
    BEGIN
        -- Conversion failed, generate unknown error.
        SET @ErrorXML = StructuredError.ErrorLookup(N'ErrorHandler', N'UnknownError', (SELECT * FROM (SELECT ChildMessage=@ErrorMessage, PROCID=@@PROCID) AS T FOR XML AUTO)) ;
    END

    -- Insert requested XML.
    IF @xmlBefore IS NOT NULL
        SET @ErrorXML.modify('insert sql:variable("@xmlBefore") as first into (/E)[1]')  ;

    IF @xmlAfter IS NOT NULL
        SET @ErrorXML.modify('insert sql:variable("@xmlAfter") as last into (/E)[1]')  ;

    RETURN @ErrorXML ;
END
GO
