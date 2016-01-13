CREATE FUNCTION StructuredError.SplitString
/**********************************************************************************************************************************
    DESCRIPTON:
       Split a string into parts base on a separation character into a table.

   EXAMPLE:
      SELECT * FROM StructuredError.SplitString( '~', 'MAINT~12221~10001~10/25/2004~CANCELLED~1' )
      SELECT * FROM StructuredError.SplitString( '~', '' )
      SELECT * FROM StructuredError.SplitString( '~', NULL )
      SELECT * FROM StructuredError.SplitString( NULL, 'MAINT~12221~10001~10/25/2004~CANCELLED~1' )
      SELECT * FROM StructuredError.SplitString( '', 'MAINT~12221~10001~10/25/2004~CANCELLED~1' )

   RETURN:
      Table with one column containing resulting strings.
**********************************************************************************************************************************/
(
    @strSearch       AS varchar(255)            -- String to search for.
   ,@strText         AS varchar(MAX )           -- Text to search for string.
)
RETURNS @tblResult TABLE (
    rowid       int NOT NULL identity(1,1),
    result      varchar(MAX) NOT NULL,
    PRIMARY KEY (rowid)
)
AS
BEGIN
    DECLARE @iLastPos        int
          , @iPos            int
          , @lngSearch       int
          , @lngText         int
          , @lngSubstring    int
          , @strResult       varchar(MAX)
          ;
    IF @strText IS NULL RETURN ;
    SET @lngText = LEN(@strText + 'X') - 1 ;
 
    IF @strSearch IS NULL SET @strSearch = '' ;
    SET @lngSearch = LEN(@strSearch + 'X') - 1 ;
 
    IF @lngSearch <= 0
    BEGIN
        INSERT INTO @tblResult
        SELECT @strText AS result
        ;
        RETURN ;
    END
 
    SET @strResult    = NULL ;
    SET @iLastPos     = 1 ;
    SET @iPos         = CHARINDEX( @strSearch, @strText ) ;
 
    WHILE @iPos > 0
    BEGIN
        SET @lngSubstring = @iPos - @iLastPos ;
        IF @lngSubstring > 0
            INSERT INTO @tblResult
            SELECT SUBSTRING( @strText, @iLastPos, @lngSubstring ) AS result
            ;
        SET @iLastPos  = @iPos + @lngSearch ;
        SET @iPos      = CHARINDEX( @strSearch, @strText, @iLastPos ) ;
    END
 
    SET @lngSubstring = @lngSearch + @lngText - @iLastPos ;
    IF @lngSubstring > 0
        INSERT INTO @tblResult
        SELECT SUBSTRING( @strText, @iLastPos, @lngSubstring ) AS result
        ;
    RETURN ;
END
GO
