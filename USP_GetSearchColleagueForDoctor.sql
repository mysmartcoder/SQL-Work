CREATE PROCEDURE [dbo].[USP_GetSearchColleagueForDoctor] --[USP_GetSearchColleagueForDoctor] 46107,1,10,'bharat',null,null,null,null,null,null,null,null       
	@UserId AS INT
	,@PageIndex AS INT
	,@PageSize AS INT
	,@Name AS NVARCHAR(500) = NULL
	,@Email AS NVARCHAR(500) = NULL
	,@phone AS NVARCHAR(500) = NULL
	,@City AS NVARCHAR(500) = NULL
	,@State AS NVARCHAR(500) = NULL
	,@Zipcode AS NVARCHAR(500) = NULL
	,@Institute AS NVARCHAR(500) = NULL
	,@SpecialtityList AS NVARCHAR(500) = NULL
	,@Keywords AS NVARCHAR(500) = NULL
AS
BEGIN
	DECLARE @StateCode NVARCHAR(100) = NULL
	DECLARE @NewZipCode NVARCHAR(100) = NULL
	DECLARE @Lat1 VARCHAR(100)
	DECLARE @Lon1 VARCHAR(100)

	SET @Lat1 = 33.24
	SET @Lon1 = - 111.96

	SELECT @NewZipCode = ZipCode_Location.ZipCode
		,@Lat1 = LATITUDE
		,@Lon1 = LONGITUDE
	FROM ZipCode_Location
	INNER JOIN AddressInfo ON ZipCode_Location.ZipCode = AddressInfo.ZipCode
	WHERE AddressInfo.ZipCode = @Keywords
		AND AddressInfo.UserType = 0
		AND AddressInfo.ContactType = 1

	SELECT @StateCode = statecode
	FROM statemaster
	WHERE statename = @Keywords

	IF @StateCode = ''
		OR @StateCode = NULL
		SET @StateCode = NULL

	DECLARE @Result AS NVARCHAR(max)
	DECLARE @exec AS NVARCHAR(max)

	-- Set Default LONGITUDE and LATITUDE bcz some user doest enter zipcode show miles not come         
	SET @Result = ''
	SET @exec = ''

	IF (isnull(@Zipcode, '') = '')
	BEGIN
		SELECT @Lat1 = LATITUDE
			,@Lon1 = LONGITUDE
		FROM ZipCode_Location
		INNER JOIN AddressInfo ON ZipCode_Location.ZipCode = AddressInfo.ZipCode
		WHERE AddressInfo.UserId = @UserId
			AND AddressInfo.UserType = 0
			AND AddressInfo.ContactType = 1
	END
	ELSE
	BEGIN
		SELECT TOP 1 @Lat1 = LATITUDE
			,@Lon1 = LONGITUDE
		FROM ZipCode_Location
		WHERE ZipCode = ISNULL(@NewZipCode, ZipCode)
	END

	--  (select top 1 AccountName from account_Master as AC left join Account as A on A.AccountId          
	--=AC.AccountId where A.OwnerId=y.UserId) As OfficeName          
	SET @Result = 'Select y.*,          
dbo.UDF_GetMemberSpecialities(y.UserId,1) AS Specialities          
from                    
(Select X.*,ROW_NUMBER() OVER (order by case when Miles is null then 1 else 0 end, Miles ) as RowNumber,Count(*) OVER() as TotalRecord from          
(select distinct  VW_AdvanceSearchView.UserId         
,VW_AdvanceSearchView.FirstName,VW_AdvanceSearchView.LastName ,        
VW_AdvanceSearchView.ImageName,VW_AdvanceSearchView.ExactAddress,VW_AdvanceSearchView.Address2,        
VW_AdvanceSearchView.City,VW_AdvanceSearchView.State,VW_AdvanceSearchView.ZipCode,        
CAST(ROUND(dbo.UDF_DistanceBetween(' + @Lat1 + ',' + @Lon1 + ',VW_AdvanceSearchView.LATITUDE,VW_AdvanceSearchView.LONGITUDE), 1, 1) AS DECIMAL (8, 1)) AS Miles           
,VW_AdvanceSearchView.AccountName as OfficeName        
from VW_AdvanceSearchView         
WHERE VW_AdvanceSearchView.UserId <> ' + CAST(@UserId AS NVARCHAR(500)) + 
		' and          
VW_AdvanceSearchView.status = 1 and VW_AdvanceSearchView.ContactType=1 and        
VW_AdvanceSearchView.UserType=0          
and VW_AdvanceSearchView.userid not in (SELECT distinct ColleagueId FROM Member_Colleagues WHERE Member_Colleagues.Userid=' + CAST(@UserId AS NVARCHAR(500)) + ')          
and VW_AdvanceSearchView.userid not in (SELECT distinct UserId FROM Member_Colleagues WHERE Member_Colleagues.ColleagueId=' + CAST(@UserId AS NVARCHAR(500)) + ')          
'

	IF (
			@Name != NULL
			OR @Name != ''
			)
	BEGIN
		--set @exec=@exec+'and (VW_AdvanceSearchView.FirstName like ''%'+@Name+'%'' or VW_AdvanceSearchView.LastName like ''%'+@Name+'%'')'          
		SET @exec = @exec + 'and (dbo.UDF_FullName_Format(VW_AdvanceSearchView.FirstName,VW_AdvanceSearchView.LastName) like ''%''+ ISNULL(''' + @Name + ''',dbo.UDF_FullName_Format(VW_AdvanceSearchView.FirstName,VW_AdvanceSearchView.LastName))+''%'')'
	END

	IF (
			@Email != NULL
			OR @Email != ''
			)
	BEGIN
		SET @exec = @exec + 'and  (VW_AdvanceSearchView.UserName like ''%' + @Email + '%'' or VW_AdvanceSearchView.SecondaryEmail like ''%' + @Email + '%'' or VW_AdvanceSearchView.EmailAddress like ''%' + @Email + '%'')'
	END

	IF (
			@phone != NULL
			OR @phone != ''
			)
	BEGIN
		SET @exec = @exec + 'and REPLACE(REPLACE(REPLACE(REPLACE(VW_AdvanceSearchView.phone,''('',''''),'')'',''''),''-'',''''),'' '','''') like ''%' + @phone + '%'''
	END

	IF (
			@City != NULL
			OR @City != ''
			)
	BEGIN
		SET @exec = @exec + 'and VW_AdvanceSearchView.City like ''%' + @City + '%'''
	END

	IF (
			@State != NULL
			OR @State != ''
			)
	BEGIN
		SET @exec = @exec + 'and VW_AdvanceSearchView.State like ''%' + @State + '%'''
	END

	IF (
			@Zipcode != NULL
			OR @ZipCode != ''
			)
	BEGIN
		SET @exec = @exec + 'and VW_AdvanceSearchView.Zipcode like ''%' + ISnull(@ZipCode, @NewZipCode) + '%'''
	END

	IF (
			@Institute != NULL
			OR @Institute != ''
			)
	BEGIN
		SET @exec = @exec + 'and VW_AdvanceSearchView.Institute like ''%' + @Institute + '%'''
	END

	IF (
			@SpecialtityList != NULL
			OR @SpecialtityList != ''
			)
	BEGIN
		SET @exec = @exec + 'and VW_AdvanceSearchView.Specialities in (' + @SpecialtityList + ')'
	END

	IF (
			@Keywords != NULL
			OR @Keywords != ''
			)
	BEGIN
		SET @exec = @exec + ' and ( dbo.UDF_FullName_Format(VW_AdvanceSearchView.FirstName,VW_AdvanceSearchView.LastName) like ''%'' +ISNULL(''' + @Keywords + ''',dbo.UDF_FullName_Format(VW_AdvanceSearchView.FirstName,VW_AdvanceSearchView.LastName))+''%''      
  
or VW_AdvanceSearchView.UserName like ''%' + @Keywords + '%'' or VW_AdvanceSearchView.SecondaryEmail like ''%' + @Keywords + '%'' 
or VW_AdvanceSearchView.ZipCode like ''%' + @Keywords + '%''       
or VW_AdvanceSearchView.AccountName like ''%' + @Keywords + '%'' or VW_AdvanceSearchView.EmailAddress like ''%' + @Keywords + '%''
or VW_AdvanceSearchView.Specialities in ( select specialityid from Dental_Specialities where description like ''%' + @Keywords + '%'')
or REPLACE(REPLACE(REPLACE(REPLACE(VW_AdvanceSearchView.phone,''('',''''),'')'',''''),''-'',''''),'' '','''') like ''%' + @Keywords + '%''          
or VW_AdvanceSearchView.City like ''%' + @Keywords + '%'' or VW_AdvanceSearchView.State like ''%' + isnull(@StateCode, @Keywords) + '%'') '
	END

	DECLARE @bet1 VARCHAR(100) = ''
	DECLARE @bet2 VARCHAR(100) = ''

	SET @bet1 = (@PageIndex - 1) * @PageSize + 1
	SET @bet2 = @PageIndex * @PageSize
	SET @exec = @exec + '           
Group by VW_AdvanceSearchView.UserId          
,VW_AdvanceSearchView.FirstName,VW_AdvanceSearchView.LastName ,VW_AdvanceSearchView.ImageName ,VW_AdvanceSearchView.AccountName          
,VW_AdvanceSearchView.ExactAddress,VW_AdvanceSearchView.Address2,VW_AdvanceSearchView.City,VW_AdvanceSearchView.State,        
VW_AdvanceSearchView.Country,VW_AdvanceSearchView.ZipCode,VW_AdvanceSearchView.LATITUDE,VW_AdvanceSearchView.LONGITUDE,VW_AdvanceSearchView.Username        
) as X ) AS Y   WHERE            
Y.RowNumber between ' + @bet1 + ' and ' + @bet2 + ' order by case when Miles is null then 0 else 1 end,Miles,State asc'
	SET @Result = @Result + @exec

	EXEC (@Result)

	PRINT @Result
END
