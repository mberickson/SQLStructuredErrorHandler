CREATE FUNCTION StructuredError.ErrorConvertToString(@ErrorXML XML, @LimitLength bit)
RETURNS VARCHAR(max)
AS
/**********************************************************************************************************************************
    DESCRIPTON:
        Convert a structured error message in XML format into a string.

    PARAMETERS:
        @ErrorXML                   Structured error message to convert.
        @LimitLength                Indicates length of string should be limited for "RAISERROR".

    RETURN:
        Resulting structured error message in string form.
**********************************************************************************************************************************/
BEGIN
    DECLARE @ErrorMessage       VARCHAR(max) = NULL        -- Developer error message.
          , @MaxErrorLength     int = 2047                  -- Max characters for RAISERROR message.
          , @True               bit = 1
          , @False              bit = 0
          ;
    -- Get resulting message making sure it fits within the 2047 character limitation of RAISERROR.
    SET @ErrorMessage = CONVERT(varchar(max), @ErrorXML);
    WHILE (@LimitLength = @True) AND (LEN(@ErrorMessage) > @MaxErrorLength)
    BEGIN
        -- Trim XML so that resulting message can fit in the RAISERROR output string.
             IF 1 = @ErrorXML.exist('(/E/*[not(local-name() = ("T", "E"))])[last()]')
                -- Remove any node that is not a "T" or "E" element.
                SET @ErrorXML.modify('delete (/E/*[not(local-name() = ("T", "E"))])[last()]');
        ELSE IF 1 = @ErrorXML.exist('/E/E[last()]/E[last()]')
                -- Remove child "E" element in last child "E" element.
                SET @ErrorXML.modify('delete /E/E[last()]/E[last()]');
        ELSE IF 1 = @ErrorXML.exist('/E/E[last()]')
                -- Remove last child "E" element.
                SET @ErrorXML.modify('delete /E/E[last()]');
        ELSE IF 1 = @ErrorXML.exist('/E/T[last()]')
                -- Remove last child "T" element.
                SET @ErrorXML.modify('delete /E/T[last()]');
        ELSE IF 1 = @ErrorXML.exist('/E/@D')
                -- Remove developer message.
                SET @ErrorXML.modify('delete /E/@D');
        ELSE
                -- Tried everything, give up.
                BREAK ;
        SET @ErrorMessage = CONVERT(varchar(max), @ErrorXML);
    END

    RETURN @ErrorMessage ;
END
GO
