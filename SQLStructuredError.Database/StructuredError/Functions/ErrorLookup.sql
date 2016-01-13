CREATE FUNCTION StructuredError.ErrorLookup(@ProcedureName VARCHAR(128), @ErrorName VARCHAR(128), @xmlArgs XML = NULL)
RETURNS VARCHAR(max)
AS
/**********************************************************************************************************************************
    DESCRIPTON:
        Generate structured error message for the error in the error table identified by procedure and error name.

    PARAMETERS:
        @ProcedureName              Name of the procedure that owns the error. Normally use OBJECT_NAME(@@PROCID).
        @ErrorName                  Name of the error.
        @xmlArgs                    Optional XML with tokens to be evaluated (see note below.)

    RETURN:
        Structured XML error message as a string to be used in RAISERROR.

        Example format:
            <E N="2021003" M="The Branch specified was not found"
                           D="Specified branch id not found or deleted."
                           P="ArticleIsDeletable" L="103">
               <T EntityId="15" EntityType="2"/>
            <E/>

        Element and attribute names are intentionally kept short as possible to make effective use of the 2047 character limitation 
        of the SQL command "RAISERROR".

            • E – element: Topmost error definition all structured error messages. Attributes include the following:
                o N – attribute:  Unique error code number in the errors table.
                o M – attribute:  User friendly text to display to the user.
                o D – attribute: Optional detail developer text. If this text is the same as "M", then it is excluded.
                o P – attribute: Name of procedure reporting the error.
                o L – attribute: Line number in procedure where the error was thrown.
                o This element can contain zero or more "T" or "E" child elements. A child "T" element contains attribute information 
                  related to the error. A child "E" element is the original error reported by a lower level procedure.
            • T – Element: Zero or more child element to an "E" element that contains useful token information as attributes to the 
                  error such as the type of entity and entity identifier. The list of attributes to this element will vary from error 
                  to error.

    NOTES:
        - The following is an example SQL statement to construct a list of tokens (i.e. attributes with values) for parameter "@xmlArgs".
           (SELECT * FROM (SELECT EntityId = @EntityId, EntityType = @EntityType, EntityName = @EntityName, PROCID=@@PROCID, LINE=51) AS T FOR XML AUTO)
          Below is am example XML that may be produced by this statement:
            <T EntityId="10", EntityType="Article", EntityName="New Code Entity2 Conceptual Article", PROCID="1921598084", LINE="51" />
        - The XML provided is inserted as a child to the error ("E") element created. This allows any detail error elements to be included in the
          resulting XML. The second example below shows how this can be done.
        - Since the resulting output is designed to be used directly in the SQL command "RAISERROR", which has a 2047 character limitation on the message
          string, this procedure will trim child nodes in the XML until the resulting string fits within this limitation. The second example below
          demonstrates this.
        - All XML attributes in the token ("T") element that is provided as a child to the error ("E") element are available for substitution in the 
          error message and display message of the error text. This is done by placing a "#" before and after the attribute name. For example the text 
          "#EntityTypeName# #EntityId# is already deleted in the database" and the token settings "EntityTypeName="Article"" and "EntityId="10"", will 
          produce "Article 10 is already deleted in the database." If the token is not provided, then the text is left as is.
        - The special substitution token "#ChildMessage#" may be used in the eror and display message to be replaced with the error or display message 
          from the first child error ("E") element. If there is no child error element, then this substitution token is replace with nothing.
        - The special attributes "PROCID" and "LINE" in the token ("T") element are promoted to be attributes of the error ("E") element as attributes 
          "P" and "L" respectively and removed from the token element. The "PROCID" attribute is assumed to contain the SQL procedure id of a procedure, 
          therefore the procedure identifier is translated to a procedure name for the "P" attribute in the error element. The procedure identifier of 
          the current procedure is easily obtained using the "@@PROCID" global variable.

    EXAMPLE:
        DECLARE @EntityId       bigint = 10
              , @EntityType     VARCHAR(64) = N'Article'
              , @EntityName     VARCHAR(255) = N'New Code Entity2 Conceptual Article'
              , @MyData1        StructuredError.EntityLanguageTableType 
              ;
        INSERT INTO @MyData1 SELECT * FROM (SELECT EntityId = N'15', LanguageRegionSetId = N'9' ) t 
        ;
        SELECT  LEN(ErrorXML) AS lng, ErrorXML
        FROM    (SELECT   ErrorXML = StructuredError.ErrorLookup('ArticleIsDeletable', 'IsDeleted', DEFAULT)
                 UNION ALL
                 SELECT   StructuredError.ErrorLookup('ArticleIsDeletable', 'IsDeleted', (SELECT * FROM (SELECT EntityId = @EntityId, EntityType = @EntityType, EntityName = @EntityName, PROCID = OBJECT_ID('StructuredError.ArticleIsDeletable'), LINE = 103) AS T FOR XML AUTO))
                 UNION ALL
                 SELECT ErrorXML = StructuredError.ErrorLookup('ArticleIsDeletable', 'NotFound', (SELECT * FROM (SELECT EntityId = d.EntityId, EntityType = StructuredError.EntityType_Branch(), EntityName = ap.BranchName) AS T FOR XML AUTO))
                 FROM    @MyData1 AS d
                 LEFT
                 JOIN    StructuredError.BranchProperties    AS ap ON ap.BranchId = d.EntityId
                ) AS X
        ;

        Produces the following results:
        lng  ErrorXML
        ---- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        102  <E N="5021006" M="The Article has been marked as deleted" D="The Article has been marked as deleted" P="ArticleIsDeletable"/>
        224  <E N="5021006" M="The Article has been marked as deleted" D="The Article has been marked as deleted" P="ArticleIsDeletable" L="103"><T EntityId="10" EntityType="Article" EntityName="New Code Entity2 Conceptual Article" /></E>
        130  <E N="2021003" M="The Branch specified was not found" D="The Branch specified was not found" P="ArticleIsDeletable"><T EntityId="15" EntityType="2"/></E>

    EXAMPLE:
        Given the following entries in the error table "StructuredError.Errors":
            ErrorId ProcessName      EntityTypeId ErrorName    ErrorMessage                                               DisplayMessage
            ------- ---------------- ------------ ------------ ---------------------------------------------------------- ----------------------------------------------------------
            5021000 Test_ErrorLookup 5            UnknownError The operation failed due to some unforeseen circumstances. The operation failed due to some unforeseen circumstances.
            5021003 Test_ErrorLookup 5            NotFound     The Article #EntityId# specified was not found             The Article specified was not found
            5021006 Test_ErrorLookup 5            IsDeleted    The Article #EntityId# has been marked as deleted          The Article has been marked as deleted

        The following code:
            CREATE PROCEDURE StructuredError.Test_ErrorLookup
            AS
            BEGIN
                DECLARE @EntityId                   bigint = StructuredError.EntityType_Article()
                      , @EntityTypeName             VARCHAR(64) = 'Article'
                      , @ErrorMessage               VARCHAR(max)
                      , @MaxErrorMessageLength      int = 2047 -- Max characters for RAISERROR message.
                      , @True                       bit = 1
                      , @False                      bit = 0
                      , @MyData1                    StructuredError.EntityLanguageTableType
                      ;

                CREATE
                TABLE   #IsDeletableResults(
                        EntityTypeId        bigint,
                        EntityId            bigint,
                        LanguageRegionSetId bigint,
                        IsDeletable         bit,
                        HasError            bit,
                        ErrorMessage        VARCHAR(max),
                        PRIMARY KEY (EntityTypeId, EntityId, LanguageRegionSetId)
                ) ;

                INSERT INTO @MyData1 SELECT * FROM (SELECT EntityId = N'15', LanguageRegionSetId = N'9' ) t
                ;
                INSERT INTO #IsDeletableResults
                SELECT  TOP (20) EntityTypeId = @EntityId
                ,       EntityId = ap.ArticleId
                ,       LanguageRegionSetId = ap.LanguageRegionSetId
                ,       IsDeletable = 0
                ,       HasError = @True
                ,       ErrorMessage = 
                            CASE WHEN (ap.ArticleId % 2) = 0
                                THEN StructuredError.Error_Article_IsDeletable_NotFound((SELECT * FROM (SELECT EntityTypeName = @EntityTypeName, EntityId = ap.ArticleId, PROCID = @@PROCID, LINE = 61) AS T FOR XML AUTO))
                                ELSE StructuredError.Error_Article_IsDeletable_IsDeleted((SELECT * FROM (SELECT EntityTypeName = @EntityTypeName, EntityId = ap.ArticleId, PROCID = @@PROCID, LINE = 62) AS T FOR XML AUTO))
                            END
                FROM    StructuredError.Articles                a   WITH(NOLOCK)
                JOIN    StructuredError.ArticleProperties       ap  WITH(NOLOCK)
                                                        ON  ap.ArticleId = a.ArticleId
                                                        AND ap.LanguageRegionSetId = 9
                ORDER
                BY      ap.ArticlePropertyRowGuid DESC
                ;
                SELECT * FROM #IsDeletableResults
                ;
                SET @ErrorMessage = (SELECT * FROM (SELECT PROCID = @@PROCID, LINE = 71) AS T FOR XML AUTO) ;
                SELECT @ErrorMessage += ErrorMessage FROM #IsDeletableResults WHERE HasError = @True ;
                SET @ErrorMessage = StructuredError.Error_Article_IsDeletable_UnknownError(@ErrorMessage);

                SELECT LNG = LEN(@ErrorMessage), @ErrorMessage ;

                DROP TABLE #IsDeletableResults ;
            END

            BEGIN TRY
                EXEC StructuredError.Test_ErrorHandler
            END TRY
            BEGIN CATCH
                DECLARE @Severity           int = ERROR_SEVERITY()
                      , @State              int = ERROR_STATE()
                      , @Line               int = ERROR_LINE()
                      , @ErrorNumber        int = ERROR_NUMBER()
                      , @ErrorMessage       VARCHAR(max) = ERROR_MESSAGE()
                      ;
                SELECT  ErrorNumber=@ErrorNumber, ErrorMessage=@ErrorMessage, lng=LEN(@ErrorMessage) ;
                SELECT  ErrorXML= CONVERT(xml, @ErrorMessage) ;
            END CATCH

        Will produce the following XML string.
            <E N="5021000" M="The operation failed due to some unforeseen circumstances." D="The operation failed due to some unforeseen circumstances." P="Test_ErrorLookup" L="71">
                <E N="5021006" M="The Article has been marked as deleted" D="The Article 5 has been marked as deleted" P="Test_ErrorLookup" L="62">
                    <T EntityTypeName="Article" EntityId="5"/>
                </E>
                <E N="5021003" M="The Article specified was not found" D="The Article 8 specified was not found" P="Test_ErrorLookup" L="61">
                    <T EntityTypeName="Article" EntityId="8"/>
                </E>
                <E N="5021006" M="The Article has been marked as deleted" D="The Article 9 has been marked as deleted" P="Test_ErrorLookup" L="62">
                    <T EntityTypeName="Article" EntityId="9"/>
                </E>
                <E N="5021006" M="The Article has been marked as deleted" D="The Article 19 has been marked as deleted" P="Test_ErrorLookup" L="62">
                    <T EntityTypeName="Article" EntityId="19"/>
                </E>
                <E N="5021003" M="The Article specified was not found" D="The Article 24 specified was not found" P="Test_ErrorLookup" L="61">
                    <T EntityTypeName="Article" EntityId="24"/>
                </E>
                <E N="5021006" M="The Article has been marked as deleted" D="The Article 25 has been marked as deleted" P="Test_ErrorLookup" L="62">
                    <T EntityTypeName="Article" EntityId="25"/>
                </E>
                <E N="5021003" M="The Article specified was not found" D="The Article 26 specified was not found" P="Test_ErrorLookup" L="61">
                    <T EntityTypeName="Article" EntityId="26"/>
                </E>
                <E N="5021006" M="The Article has been marked as deleted" D="The Article 27 has been marked as deleted" P="Test_ErrorLookup" L="62">
                    <T EntityTypeName="Article" EntityId="27"/>
                </E>
                <E N="5021003" M="The Article specified was not found" D="The Article 34 specified was not found" P="Test_ErrorLookup" L="61">
                    <T EntityTypeName="Article" EntityId="34"/>
                </E>
                <E N="5021003" M="The Article specified was not found" D="The Article 36 specified was not found" P="Test_ErrorLookup" L="61">
                    <T EntityTypeName="Article" EntityId="36"/>
                </E>
            </E>

        Notes:
            - All "T" elements have the "PROCID" and "LINE" attributes removed since this information has been elevated to the parent and is redundant.
            - All "T" elements that have no attributes have been removed, therefor the topmost root "E" element does not have one in this example.
            - The list of child "E" elements have been trimmed to the first 10 so that the resulting XML string fits in the 2047 character limitation.
            - The tokens "#EntityId#" in the error message text has been replaced by the value of the "EntityId" attribute of the child "T" element.
**********************************************************************************************************************************/
BEGIN
    DECLARE @UnknownErrorId     int = 999900101             -- Error id to use if error not found.
    ,       @ErrorId            int = NULL                  -- Identifier of error.
    ,       @ErrorXML           XML = NULL                  -- Resulting error XML.
    ,       @ErrorMessage       VARCHAR(max) = NULL        -- User error message.
    ,       @DeveloperMessage   VARCHAR(max) = NULL        -- Developer error message.
    ,       @ChildMessage       VARCHAR(max) = NULL        -- Child user message for "#ChildMessage#" token.
    ,       @MaxErrorLength     int = 2047                  -- Max characters for RAISERROR message.
    ,       @LimitLength        bit = 1                     -- Indicates length of result string is limited by @MaxErrorLength
    ,       @True               bit = 1
    ,       @False              bit = 0
    ;

    IF @xmlArgs IS NULL SET @xmlArgs = CONVERT(xml, '') ;

    -- Get list of tokens values
    DECLARE @TokenTable     TABLE (
        RowId               int NOT NULL IDENTITY(1, 1)
    ,   Name                VARCHAR(256) NOT NULL
    ,   Value               VARCHAR(1024) NULL
    ,   PRIMARY KEY (RowId)
    );
    INSERT INTO @TokenTable (Name, Value)
    SELECT  t.Name, t.Value
    FROM    (   SELECT Name = LTRIM(RTRIM(a.t.value('local-name(.)', 'VARCHAR(256)')))
                ,      Value = a.t.value('.', 'VARCHAR(1024)')
                FROM   @xmlArgs.nodes('/T/@*')      a(t)
            ) AS t
    WHERE   ((t.Name IS NOT NULL) AND (t.Name <> ''))
    ;
    INSERT INTO @TokenTable (Name, Value)
    SELECT  nt.Name, nt.Value
    FROM    (   SELECT  Name = N'ProcedureName', Value = @ProcedureName
                UNION ALL SELECT  Name = N'ErrorName', Value = @ErrorName
            ) AS nt
    LEFT
    JOIN    @TokenTable                     t   ON t.Name = nt.Name
    WHERE   t.Name IS NULL
    ;
    -- Get special options to this procedure.
    SELECT  @LimitLength = CASE WHEN SUBSTRING(t.Value, 1, 1) IN ('1', 'T', 'Y') THEN @True ELSE @False END
    FROM    @TokenTable     t
    WHERE   t.Name = 'LimitLength'
    ;
    -- Get error message.
    SELECT  @ErrorId = e.ErrorId
    ,       @ErrorMessage = e.ErrorMessage
    ,       @DeveloperMessage = e.DeveloperMessage
    FROM    StructuredError.Errors          e
    WHERE   e.ProcedureName = @ProcedureName
    AND     e.ErrorName = @ErrorName
    ;
    -- If error message record not found, use default error message.
    IF @ErrorId IS NULL
    BEGIN
        SELECT  @ErrorId = e.ErrorId
        ,       @ErrorMessage = e.ErrorMessage
        ,       @DeveloperMessage = e.DeveloperMessage
        FROM    StructuredError.Errors          e
        WHERE   e.ProcedureName = 'ErrorHandler'
        AND     e.ErrorName = N'UnknownError'
        ;
        IF @ErrorId IS NULL
        BEGIN
            SELECT  @ErrorId = 0
            ,       @ErrorMessage = 'Unknown error message "#ErrorName#" for procedure "#ProcedueName#" is not defined in the error table. #ChildMessage#'
            ,       @DeveloperMessage = NULL
            ;
        END
        SET @xmlArgs.modify('insert attribute ErrorId {sql:variable("@ErrorId")} into /T[1]') ;
    END

    -- Evaluate all tokens in message.
    SELECT  @ErrorMessage   = REPLACE(@ErrorMessage,   '#' + t.Name + '#', ISNULL(t.Value, ''))
    ,       @DeveloperMessage = REPLACE(@DeveloperMessage, '#' + t.Name + '#', ISNULL(t.Value, ''))
    FROM    @TokenTable             t
    ;
    IF (0 < CHARINDEX('#ChildMessage#', ISNULL(@ErrorMessage, ''))) OR (0 < CHARINDEX('#ChildMessage#', ISNULL(@DeveloperMessage, '')))
    BEGIN
        -- @ErrorMessage and (/E/@M) should never be NULL, but @DeveloperMessage and (/E/@D) may be NULL.
        SET @ChildMessage = ISNULL(@xmlArgs.value('(/E[1]/@M)[1]', 'VARCHAR(max)'), '');
        SET @ErrorMessage = REPLACE(@ErrorMessage, '#ChildMessage#', @ChildMessage);
        SET @DeveloperMessage = REPLACE(@DeveloperMessage, '#ChildMessage#', ISNULL(@xmlArgs.value('(/E[1]/@D)[1]', 'VARCHAR(max)'), @ChildMessage));
    END

    -- Construct structured error text.
    SET @ErrorXML = (
        SELECT  N = E.ErrorId
        ,       M = E.ErrorMessage
        ,       D = E.DeveloperMessage
        ,       P = E.ProcedureName
        ,       L = E.Line
        FROM   (    SELECT  ErrorId = @ErrorId
                    ,       ErrorMessage = @ErrorMessage
                    ,       DeveloperMessage = @DeveloperMessage
                    ,       ProcedureName = ISNULL((SELECT TOP(1) OBJECT_NAME(CONVERT(int, Value)) FROM @TokenTable WHERE Name = 'PROCID'), @ProcedureName)
                    ,       Line = (SELECT TOP(1) Value FROM @TokenTable WHERE Name = 'LINE')
               ) E
        FOR XML AUTO
    ) ;
    -- Insert XML arguments as child of this error element.
    SET @ErrorXML.modify('insert sql:variable("@xmlArgs") as first into (/E)[1]');
    -- Remove the token attributes that were promoted to error element.
    SET @ErrorXML.modify('delete /E/T/@*[upper-case(local-name()) = ("PROCID", "LINE", "LIMITLENGTH")]') ;
    -- Remove any token elements that do not have any attributes.
    SET @ErrorXML.modify('delete //T[not(@*)]') ;
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
