CREATE PROCEDURE [dbo].[USP_GetPatientDetailsOfDoctor] --[USP_GetPatientDetailsOfDoctor] 43167,1,100,null,2,2,NULL,1          
	@DoctorId AS INT
	,@PageIndex AS INT
	,@PageSize AS INT
	,@SearchText AS NVARCHAR(500) = NULL
	,@SortColumn INT = NULL
	,@SortDirection INT = NULL
	,@NewSearchText AS NVARCHAR(100) = NULL
	,@FilterBy INT = 0
AS
BEGIN
	CREATE TABLE #Accounts (AccountId INT)

	INSERT INTO #Accounts
	SELECT *
	FROM dbo.fn_GetRelatedAccounts(@DoctorId)

	--SELECT DISTINCT OwnerId FROM Account WHERE AccountId IN (SELECT AccountId FROM @Accounts)
	CREATE TABLE #Patients (
		PatientId INT
		,LocationId INT
		)

	INSERT INTO #Patients
	SELECT PatientId
		,ISNULL(Location, 0)
	FROM (
		SELECT ROW_NUMBER() OVER (
				PARTITION BY PatientId ORDER BY PatientId
					,Position DESC
					,CreationDate DESC
				) AS SrNo
			,PatientId
			,Location
			,Position
		FROM (
			SELECT DISTINCT PatientId
				,Location
				,2 Position
				,GETDATE() CreationDate
			FROM Patient
			INNER JOIN #Accounts Act ON Act.AccountId = Patient.AccountId
			WHERE Patient.PatientStatus = 0
			
			UNION
			
			SELECT P.PatientId
				,CASE 
					WHEN RefPatients.LocationId IS NULL
						THEN P.Location
					ELSE RefPatients.LocationId
					END AS Location
				,CASE 
					WHEN RefPatients.ReferedUserId = @DoctorId
						THEN 1
					ELSE 0
					END AS Position
				,RefPatients.CreationDate
			FROM Patient P
			INNER JOIN Patient_Member PM ON P.PatientId = PM.PatientId
			LEFT JOIN (
				SELECT Msg.PatientId
					,Msg.LocationId
					,Msg.ReferedUserId
					,Msg.CreationDate
				FROM Message Msg
				WHERE Msg.MessageTypeId = 2
				) AS RefPatients ON RefPatients.PatientId = PM.PatientId
			WHERE UserId IN (
					SELECT OwnerId
					FROM Account
					WHERE AccountId IN (
							SELECT AccountID
							FROM #Accounts
							)
					)
			) Pts
		) PtsFinal
	WHERE SrNo = 1

	--select * from #patients
	--return
	SELECT Patient.PatientId
		,Patient.FirstName
		,Patient.LastName
		,Patient.OwnerId
		,Patient.Email
		,CASE 
			WHEN Patient.gender = 0
				THEN 'Male'
			WHEN Patient.gender = 1
				THEN 'Female'
			END AS Gender
		,CASE 
			WHEN DateOfBirth = '1900-01-01'
				THEN NULL
			ELSE datediff(yy, DateOfBirth, getdate())
			END AS Age
		,Patient.AssignedPatientId
		,Addressinfo.Phone
		,Addressinfo.ExactAddress
		,Addressinfo.Address2
		,Addressinfo.City
		,Addressinfo.STATE
		,Addressinfo.ZipCode
		,Patient.ProfileImage
		,Patient.LastModifiedDate
		,m.FirstName + ' ' + m.LastName AS ReferredBy
		,m.UserId AS ReferredById
		,TotalRecord = COUNT(*) OVER ()
		,AIL.Location
		,NS.Voice
		,NS.[Text]
	FROM Patient WITH (NOLOCK)
	INNER JOIN #Patients TempP ON TempP.PatientId = Patient.PatientId
	LEFT JOIN Addressinfo ON Patient.PatientId = Addressinfo.UserId
		AND Usertype = 1
	LEFT JOIN Member m ON m.UserId = Patient.ReferredBy
	LEFT JOIN AddressInfo AIL ON AIL.AddressInfoId = TempP.LocationId
	LEFT JOIN Notification_Setting NS ON PATIENT.PatientId = NS.Patientid
	WHERE (
			(dbo.UDF_FullName_Format(Patient.FirstName, Patient.LastName) LIKE '%' + ISNULL(@SearchText, dbo.UDF_FullName_Format(Patient.FirstName, Patient.LastName)) + '%')
			OR ISNULL(Patient.Email, '') LIKE '%' + ISNULL(@SearchText, ISNULL(Patient.Email, '')) + '%'
			OR ISNULL(Patient.AssignedPatientId, '') LIKE '%' + ISNULL(@SearchText, ISNULL(Patient.AssignedPatientId, '')) + '%'
			OR dbo.UDF_FullName_Format(m.FirstName, m.LastName) LIKE '%' + ISNULL(@SearchText, ISNULL(m.FirstName, m.LastName)) + '%'
			)
		AND 1 = (
			CASE 
				WHEN @FilterBy = 1
					THEN CASE 
							WHEN ISNULL(Patient.FirstName, '') LIKE ISNULL(@NewSearchText, ISNULL(Patient.FirstName, '')) + '%'
								THEN 1
							ELSE 0
							END
				WHEN @FilterBy = 2
					THEN CASE 
							WHEN ISNULL(Patient.LastName, '') LIKE ISNULL(@NewSearchText, ISNULL(Patient.LastName, '')) + '%'
								THEN 1
							ELSE 0
							END
				WHEN @FilterBy = 10
					THEN CASE 
							WHEN ISNULL(Patient.Email, '') LIKE ISNULL(@NewSearchText, ISNULL(Patient.Email, '')) + '%'
								THEN 1
							ELSE 0
							END
				WHEN @FilterBy = 11
					THEN CASE 
							WHEN ISNULL(m.FirstName, '') LIKE ISNULL(@NewSearchText, ISNULL(m.FirstName, '')) + '%'
								THEN 1
							ELSE 0
							END
				WHEN @FilterBy = 3
					THEN CASE 
							WHEN ISNULL(AIL.Location, '') LIKE ISNULL(@NewSearchText, ISNULL(AIL.Location, '')) + '%'
								THEN 1
							ELSE 0
							END
				ELSE 1
				END
			)
	ORDER BY CASE 
			WHEN @SortColumn = 1
				AND @SortDirection = 1
				THEN Patient.FirstName
			END ASC
		,CASE 
			WHEN @SortColumn = 1
				AND @SortDirection = 2
				THEN Patient.FirstName
			END DESC
		,CASE 
			WHEN @SortColumn = 2
				AND @SortDirection = 1
				THEN Patient.LastName
			END ASC
		,CASE 
			WHEN @SortColumn = 2
				AND @SortDirection = 2
				THEN Patient.LastName
			END DESC
		,CASE 
			WHEN @SortColumn = 7
				AND @SortDirection = 1
				THEN Patient.AssignedPatientId
			END ASC
		,CASE 
			WHEN @SortColumn = 7
				AND @SortDirection = 2
				THEN AssignedPatientId
			END DESC
		,CASE 
			WHEN @SortColumn = 9
				AND @SortDirection = 1
				THEN Addressinfo.Phone
			END ASC
		,CASE 
			WHEN @SortColumn = 9
				AND @SortDirection = 2
				THEN Addressinfo.Phone
			END DESC
		,CASE 
			WHEN @SortColumn = 10
				AND @SortDirection = 1
				THEN Patient.Email
			END ASC
		,CASE 
			WHEN @SortColumn = 10
				AND @SortDirection = 2
				THEN Patient.Email
			END DESC
		,CASE 
			WHEN @SortColumn = 11
				AND @SortDirection = 1
				THEN m.FirstName + ' ' + m.LastName
			END ASC
		,CASE 
			WHEN @SortColumn = 11
				AND @SortDirection = 2
				THEN m.FirstName + ' ' + m.LastName
			END DESC
		,CASE 
			WHEN @SortColumn = 12
				AND @SortDirection = 1
				THEN Patient.PatientId
			END ASC
		,CASE 
			WHEN @SortColumn = 12
				AND @SortDirection = 2
				THEN Patient.PatientId
			END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

	FETCH NEXT @PageSize ROWS ONLY

	DROP TABLE #Accounts

	DROP TABLE #Patients
END
	--[USP_GetPatientDetailsOfDoctor] 36390,1,35,"Devansh Nigam",11,2 
