/*90 day date-range used per Customer Contact LOB*/
DECLARE
	@dateRange INT = 90;  

/* --------------------------------------------------------------------------------------------------------------------------------------------*/
/* Builds 'Pre' table with 0-default values to be updated in further steps to prevents many-to-many record duplication						   */
/* Takes all Retail Customers boarding in Q4 '20 to use as the Pre pop.														   */
/* Simulated Mail Date takes the Avg datediff between CustomerAddedDt & MailDt to use as the dateadd value									   */
/* --------------------------------------------------------------------------------------------------------------------------------------------*/
IF EXISTS (Select TOP 1 'EXISTS' From tempdb.dbo.sysobjects Where ID = OBJECT_ID(N'tempdb..#HistoricalCustomerAdded'))
BEGIN  Drop Table #HistoricalCustomerAdded END;	

CREATE TABLE
	#HistoricalCustomerAdded
		( CustomerID BIGINT NOT NULL
		 ,CustomerSeries VARCHAR(3)
		 ,CustomerAddedDt DATE NOT NULL
		 ,SimulatedMailDt DATE NOT NULL /*7.796179*/

		 ,CustomerAdded_OrdersHandled_30Day INT NOT NULL
		 ,CustomerAdded_OrdersHandled_60Day INT NOT NULL
		 ,CustomerAdded_OrdersHandled_90Day INT NOT NULL


		 ,SimMailDt_OrdersHandled_30Day INT NOT NULL
		 ,SimMailDt_OrdersHandled_60Day INT NOT NULL
		 ,SimMailDt_OrdersHandled_90Day INT NOT NULL

		 ,CustomerAddedSimMailDt_OrdersHandled INT NOT NULL

		 ,Paperless_MonthlyStatementsDt DATE
		 ,SubscriptionRegisteredDt DATE

		 ,MEPERIOD INT);

/* --------------------------------------------------------------------------------------------------------------------------------------------*/
CREATE CLUSTERED INDEX idx_CustomerID
ON #HistoricalCustomerAdded
(CustomerID);
/* --------------------------------------------------------------------------------------------------------------------------------------------*/

INSERT INTO
	#HistoricalCustomerAdded
		(CustomerID
		 ,CustomerSeries
		 ,CustomerAddedDt
		 ,SimulatedMailDt
		 ,CustomerAdded_OrdersHandled_30Day
		 ,CustomerAdded_OrdersHandled_60Day
		 ,CustomerAdded_OrdersHandled_90Day
		 ,SimMailDt_OrdersHandled_30Day
		 ,SimMailDt_OrdersHandled_60Day
		 ,SimMailDt_OrdersHandled_90Day
		 ,CustomerAddedSimMailDt_OrdersHandled
		 ,Paperless_MonthlyStatementsDt 
		 ,SubscriptionRegisteredDt 

		 ,MEPERIOD )

SELECT
	 Customer_Master.CustomerID
	,CustomerSeries = CASE WHEN LEFT(Customer_Master.CustomerID,1) = 2 THEN 'Retail'
					   END
	,Customer_Master.CustomerAddedDt
	,SimulatedMailDt = DATEADD(DAY,8,Customer_Master.CustomerAddedDt)

	,CustomerAdded_OrdersHandled_30Day = 0
	,CustomerAdded_OrdersHandled_60Day = 0
	,CustomerAdded_OrdersHandled_90Day = 0
	,SimMailDt_OrdersHandled_30Day = 0
	,SimMailDt_OrdersHandled_60Day = 0
	,SimMailDt_OrdersHandled_90Day = 0
	,CustomerAddedSimMailDt_OrdersHandled = 0

	,Paperless_MonthlyStatementsDt = NULL
	,SubscriptionRegisteredDt = NULL 


	,MEPERIOD = year(Customer_Master.CustomerAddedDt) * 100 + month(Customer_Master.CustomerAddedDt)
FROM
	smd.dbo.Customer_Master Customer_Master (NOLOCK)
WHERE
	LEFT(Customer_Master.CustomerID,1) = 2
	AND Customer_Master.CustomerAddedDt BETWEEN '2020-10-01' AND '2020-12-31';

/* --------------------------------------------------------------------------------------------------------------------------------------------*/
/* Gathers all Outbound Order data based on CustomerID and if the Outbound Order was received in the date parameter					           */
/* --------------------------------------------------------------------------------------------------------------------------------------------*/
IF EXISTS (Select TOP 1 'EXISTS' From tempdb.dbo.sysobjects Where ID = OBJECT_ID(N'tempdb..#HistoricalOutboundOrders'))
BEGIN  Drop Table #HistoricalOutboundOrders END;		

CREATE TABLE
	#HistoricalOutboundOrders
		(OrderID BIGINT NOT NULL
		 ,CustomerID BIGINT NULL
		 ,OrderDt DATE NOT NULL);

/* --------------------------------------------------------------------------------------------------------------------------------------------*/
CREATE CLUSTERED INDEX idx_CustomerID
ON #HistoricalOutboundOrders
(CustomerID);
/* --------------------------------------------------------------------------------------------------------------------------------------------*/

INSERT INTO
	#HistoricalOutboundOrders
		(OrderID
		,CustomerID
		,OrderDt)

SELECT
	  OrderCenterDataSummary.OrderID
	 ,OrderCenterDataSummary.CustomerID
	 ,OrderCenterDataSummary.OrderDt
FROM
	smd.DBO.OrderCenterDataSummary OrderCenterDataSummary
JOIN
	#HistoricalCustomerAdded HistoricalCustomerAdded
	ON  OrderCenterDataSummary.CustomerID = HistoricalCustomerAdded.CustomerID
	AND OrderCenterDataSummary.OrderDt BETWEEN HistoricalCustomerAdded.CustomerAddedDt AND DATEADD(DAY,@dateRange,HistoricalCustomerAdded.SimulatedMailDt) 
WHERE
	     OrderCenterDataSummary.OrderTypeID = 3 
	AND  OrderCenterDataSummary.IsPaid =  1; 

/* --------------------------------------------------------------------------------------------------------------------------------------------*/
/* Updates the Historical 'Pre' table with the output from the calcs | Looks for the count of Outbound Orders within the timeframe for each	   */
/* segment of data																															   */
/* --------------------------------------------------------------------------------------------------------------------------------------------*/
WITH HistoricalOutboundOrders
AS (
	SELECT
		HistoricalOutboundOrders.CustomerID
		,CustomerAdded_OrdersHandled_30Day = SUM(CASE WHEN HistoricalOutboundOrders.OrderDt BETWEEN HistoricalCustomerAdded.CustomerAddedDt AND DATEADD(DAY,30,HistoricalCustomerAdded.CustomerAddedDt) THEN 1 ELSE 0 END)
		,CustomerAdded_OrdersHandled_60Day = SUM(CASE WHEN HistoricalOutboundOrders.OrderDt BETWEEN HistoricalCustomerAdded.CustomerAddedDt AND DATEADD(DAY,60,HistoricalCustomerAdded.CustomerAddedDt) THEN 1 ELSE 0 END)
		,CustomerAdded_OrdersHandled_90Day = SUM(CASE WHEN HistoricalOutboundOrders.OrderDt BETWEEN HistoricalCustomerAdded.CustomerAddedDt AND DATEADD(DAY,90,HistoricalCustomerAdded.CustomerAddedDt) THEN 1 ELSE 0 END)
		,SimMailDt_OrdersHandled_30Day = SUM(CASE WHEN HistoricalOutboundOrders.OrderDt BETWEEN HistoricalCustomerAdded.SimulatedMailDt AND DATEADD(DAY,30,HistoricalCustomerAdded.SimulatedMailDt) THEN 1 ELSE 0 END)
		,SimMailDt_OrdersHandled_60Day = SUM(CASE WHEN HistoricalOutboundOrders.OrderDt BETWEEN HistoricalCustomerAdded.SimulatedMailDt AND DATEADD(DAY,60,HistoricalCustomerAdded.SimulatedMailDt) THEN 1 ELSE 0 END)
		,SimMailDt_OrdersHandled_90Day = SUM(CASE WHEN HistoricalOutboundOrders.OrderDt BETWEEN HistoricalCustomerAdded.SimulatedMailDt AND DATEADD(DAY,90,HistoricalCustomerAdded.SimulatedMailDt) THEN 1 ELSE 0 END)
		,CustomerAddedSimMailDt_OrdersHandled = SUM(CASE WHEN HistoricalOutboundOrders.OrderDt BETWEEN HistoricalCustomerAdded.CustomerAddedDt AND DATEADD(DAY,-1,HistoricalCustomerAdded.SimulatedMailDt) THEN 1 ELSE 0 END)
	FROM
		#HistoricalOutboundOrders HistoricalOutboundOrders
	LEFT JOIN	
		#HistoricalCustomerAdded HistoricalCustomerAdded
		ON HistoricalOutboundOrders.CustomerID = HistoricalCustomerAdded.CustomerID 
	GROUP BY
		HistoricalOutboundOrders.CustomerID)
	
UPDATE
	HistoricalCustomerAdded
SET	
	CustomerAdded_OrdersHandled_30Day = HistoricalOutboundOrders.CustomerAdded_OrdersHandled_30Day
	,CustomerAdded_OrdersHandled_60Day = HistoricalOutboundOrders.CustomerAdded_OrdersHandled_60Day
	,CustomerAdded_OrdersHandled_90Day = HistoricalOutboundOrders.CustomerAdded_OrdersHandled_90Day
	,SimMailDt_OrdersHandled_30Day = HistoricalOutboundOrders.SimMailDt_OrdersHandled_30Day
	,SimMailDt_OrdersHandled_60Day = HistoricalOutboundOrders.SimMailDt_OrdersHandled_60Day
	,SimMailDt_OrdersHandled_90Day = HistoricalOutboundOrders.SimMailDt_OrdersHandled_90Day
	,CustomerAddedSimMailDt_OrdersHandled = HistoricalOutboundOrders.CustomerAddedSimMailDt_OrdersHandled
FROM
	#HistoricalCustomerAdded HistoricalCustomerAdded
JOIN
	HistoricalOutboundOrders HistoricalOutboundOrders
	ON HistoricalCustomerAdded.CustomerID = HistoricalOutboundOrders.CustomerID


/* --------------------------------------------------------------------------------------------------------------------------------------------*/
/* Identifies all Customers that went Paperless within the date range for use in the Historical 'Pre' table			   */
/* --------------------------------------------------------------------------------------------------------------------------------------------*/
IF EXISTS (Select TOP 1 'EXISTS' From tempdb.dbo.sysobjects Where ID = OBJECT_ID(N'tempdb..#Historical_Paperless_MonthlyStatements'))
BEGIN  Drop Table #Historical_Paperless_MonthlyStatements END;	

CREATE TABLE
	#Historical_Paperless_MonthlyStatements
		(CustomerID BIGINT NOT NULL
		,EffectiveDt DATE NOT NULL);

CREATE CLUSTERED INDEX idx_CustomerID
ON #Historical_Paperless_MonthlyStatements
(CustomerID);

INSERT INTO
	#Historical_Paperless_MonthlyStatements
		(CustomerId
		,EffectiveDt)

SELECT 
	CustomerPreference.CustomerId
	,EffectiveDt = MIN(CAST(CustomerPreference.RowEffectiveDate AS DATE))                      
FROM 
	Smd.Customer.CustomerPreference CustomerPreference (NOLOCK)
JOIN 
	Smd.Preference Preference (NOLOCK)                                                                                                   
	ON CustomerPreference.PreferenceId = Preference.PreferenceId 
JOIN 
	Smd.Customer.PreferenceType PreferenceType (NOLOCK) 
	ON PreferenceType.PreferenceTypeId = CustomerPreference.PreferenceTypeId
	AND PreferenceType.PreferenceType = 'MonthlyStatementDelivery'
JOIN
	#HistoricalCustomerAdded HistoricalCustomerAdded
	ON CustomerPreference.CustomerID = HistoricalCustomerAdded.CustomerID
	AND CAST(CustomerPreference.RowEffectiveDate AS DATE) BETWEEN HistoricalCustomerAdded.CustomerAddedDt AND DATEADD(DAY,@dateRange,HistoricalCustomerAdded.CustomerAddedDt)     
WHERE 
	CustomerPreference.PreferenceId = 9
	AND CustomerPreference.PreferenceTypeID IN (1,2) 
GROUP BY
	CustomerPreference.CustomerId;

/* --------------------------------------------------------------------------------------------------------------------------------------------*/
/* Updates the Historical 'Pre' table with the JOIN results																					   */
/* --------------------------------------------------------------------------------------------------------------------------------------------*/
UPDATE
	#HistoricalCustomerAdded
SET
	Paperless_MonthlyStatementsDt = CASE WHEN Historical_Paperless_MonthlyStatements.EffectiveDt IS NOT NULL THEN Historical_Paperless_MonthlyStatements.EffectiveDt ELSE NULL END
FROM	
	#HistoricalCustomerAdded HistoricalCustomerAdded
JOIN
	#Historical_Paperless_MonthlyStatements Historical_Paperless_MonthlyStatements
	ON HistoricalCustomerAdded.CustomerID = Historical_Paperless_MonthlyStatements.CustomerID;

/* --------------------------------------------------------------------------------------------------------------------------------------------*/
/* Identifies all Customers that Subscribed to the newsletter within the date range													            */
/* --------------------------------------------------------------------------------------------------------------------------------------------*/
IF EXISTS (Select TOP 1 'EXISTS' From tempdb.dbo.sysobjects Where ID = OBJECT_ID(N'tempdb..#HistoricalSubscriptionRegistration'))
BEGIN  Drop Table #HistoricalSubscriptionRegistration END;	

CREATE TABLE
	#HistoricalSubscriptionRegistration
		(CustomerID BIGINT NOT NULL
		,RegistrationDt DATE NOT NULL);

CREATE CLUSTERED INDEX idx_CustomerID
ON #HistoricalSubscriptionRegistration
(CustomerID);

INSERT INTO
	#HistoricalSubscriptionRegistration
		(CustomerId
		,RegistrationDt)

SELECT
	SubscriptionAccess.CustomerID
	,RegistrationDt = SubscriptionAccess.CreatedDate
FROM
	Smd.Customer.SubscriptionAccess(NOLOCK) SubscriptionAccess
JOIN
	#HistoricalCustomerAdded HistoricalCustomerAdded
	ON SubscriptionAccess.CustomerID = HistoricalCustomerAdded.CustomerID
	AND CAST(SubscriptionAccess.CreatedDate AS DATE) BETWEEN HistoricalCustomerAdded.CustomerAddedDt AND DATEADD(DAY,@dateRange,HistoricalCustomerAdded.CustomerAddedDt)

/* --------------------------------------------------------------------------------------------------------------------------------------------*/
/* Updates Histrorical Table with join results                             			  										                   */
/* --------------------------------------------------------------------------------------------------------------------------------------------*/
UPDATE
	#HistoricalCustomerAdded
SET
	SubscriptionRegisteredDt = CASE WHEN HistoricalSubscriptionRegistration.RegistrationDt IS NOT NULL THEN HistoricalSubscriptionRegistration.RegistrationDt ELSE NULL END
FROM	
	#HistoricalCustomerAdded HistoricalCustomerAdded
JOIN
	#HistoricalSubscriptionRegistration HistoricalSubscriptionRegistration
	ON HistoricalCustomerAdded.CustomerID = HistoricalSubscriptionRegistration.CustomerID;

/* --------------------------------------------------------------------------------------------------------------------------------------------*/
/* --------------------------------------------------------------------------------------------------------------------------------------------*/
IF EXISTS (Select TOP 1 'EXISTS' From tempdb.dbo.sysobjects Where ID = OBJECT_ID(N'tempdb..#CustomerAdded'))
BEGIN  Drop Table #CustomerAdded END;	

CREATE TABLE
	#CustomerAdded
		(CustomerID BIGINT NOT NULL
		 ,CustomerSeries VARCHAR(3)
		 ,CustomerAddedDt DATE NOT NULL
		 ,MailDate DATE NOT NULL
		 ,Opened INT NULL
		 ,Clicked INT NULL

		 ,CustomerAdded_OrdersHandled_30Day INT NOT NULL
		 ,CustomerAdded_OrdersHandled_60Day INT NOT NULL
		 ,CustomerAdded_OrdersHandled_90Day INT NOT NULL
		 ,SimMailDt_OrdersHandled_30Day INT NOT NULL
		 ,SimMailDt_OrdersHandled_60Day INT NOT NULL
		 ,SimMailDt_OrdersHandled_90Day INT NOT NULL
		 ,CustomerAddedSimMailDt_OrdersHandled INT NOT NULL

		 ,Paperless_MonthlyStatementsDt DATE
		 ,SubscriptionRegisteredDt DATE

		 ,MEPERIOD INT);

CREATE CLUSTERED INDEX idx_CustomerID
ON #CustomerAdded
(CustomerID);

INSERT INTO
	#CustomerAdded
		(CustomerID
		 ,CustomerSeries
		 ,CustomerAddedDt
		 ,MailDate
		 ,Opened
		 ,Clicked
		 ,CustomerAdded_OrdersHandled_30Day
		 ,CustomerAdded_OrdersHandled_60Day
		 ,CustomerAdded_OrdersHandled_90Day
		 ,SimMailDt_OrdersHandled_30Day
		 ,SimMailDt_OrdersHandled_60Day
		 ,SimMailDt_OrdersHandled_90Day
		 ,CustomerAddedSimMailDt_OrdersHandled
		 ,Paperless_MonthlyStatementsDt 
		 ,SubscriptionRegisteredDt 
		 ,MEPERIOD )

SELECT
	DISTINCT Customer_Master.CustomerID
	,CustomerSeries = CASE WHEN LEFT(Customer_Master.CustomerID , 1) = 2 THEN 'Retail'
					   END

	,Customer_Master.CustomerAddedDt
	,MailDate = New_Customers.MailDate

	,Opened =  New_Customers.[Open]
	,Clicked = New_Customers.Click

	,CustomerAdded_OrdersHandled_30Day = 0
	,CustomerAdded_OrdersHandled_60Day = 0
	,CustomerAdded_OrdersHandled_90Day = 0
	,SimMailDt_OrdersHandled_30Day = 0
	,SimMailDt_OrdersHandled_60Day = 0
	,SimMailDt_OrdersHandled_90Day = 0
	,CustomerAddedSimMailDt_OrdersHandled = 0

	,Paperless_MonthlyStatementsDt = NULL
	,SubscriptionRegisteredDt = NULL 
	,EnrolledInACHDt = NULL

	,MEPERIOD = year(Customer_Master.CustomerAddedDt) * 100 + month(Customer_Master.CustomerAddedDt)
FROM
	Smd.dbo.Customer_Master Customer_Master (NOLOCK)  
JOIN
	Smd.Customer.New_Customer New_Customers (NOLOCK) /*TEST*/
	ON Customer_Master.CustomerID = New_Customers.CustomerID

/* --------------------------------------------------------------------------------------------------------------------------------------------*/
/* --------------------------------------------------------------------------------------------------------------------------------------------*/
IF EXISTS (Select TOP 1 'EXISTS' From tempdb.dbo.sysobjects Where ID = OBJECT_ID(N'tempdb..#OutboundOrders'))
BEGIN  Drop Table #OutboundOrders END;		

CREATE TABLE
	#OutboundOrders
		(OrderID BIGINT NOT NULL
		 ,CustomerID BIGINT NULL
		 ,OrderDt DATE NOT NULL);

CREATE CLUSTERED INDEX idx_CustomerID
ON #OutboundOrders
(CustomerID);

INSERT INTO
	#OutboundOrders
		(OrderID
		,CustomerID
		,OrderDt)

SELECT
	 OrderCenterDataSummary.OrderID
	,OrderCenterDataSummary.CustomerID
	,OrderCenterDataSummary.OrderDt
FROM
	Smd..OrderCenterDataSummary _OrderCenterDataSummary
JOIN
	#CustomerAdded CustomerAdded
	ON OrderCenterDataSummary.CustomerID = CustomerAdded.CustomerID
	AND OrderCenterDataSummary.OrderDt BETWEEN CustomerAdded.CustomerAddedDt AND DATEADD(DAY,@dateRange,CustomerAdded.MailDate)
WHERE
	     OrderCenterDataSummary.OrderTypeID = 3
	AND OrderCenterDataSummary.IsPaid = 1; 


/* --------------------------------------------------------------------------------------------------------------------------------------------*/
/* --------------------------------------------------------------------------------------------------------------------------------------------*/
WITH OutboundOrders
AS (
	SELECT
		OutboundOrders.CustomerID
		,CustomerAdded_OrdersHandled_30Day = sum(CASE WHEN DATEADD(DAY,30,CustomerAdded.CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) AND OutboundOrders.OrderDt BETWEEN CustomerAdded.CustomerAddedDt AND DATEADD(DAY,30,CustomerAdded.CustomerAddedDt) THEN 1 ELSE 0 END)
		,CustomerAdded_OrdersHandled_60Day = SUM(CASE WHEN DATEADD(DAY,60,CustomerAdded.CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) AND OutboundOrders.OrderDt BETWEEN CustomerAdded.CustomerAddedDt AND DATEADD(DAY,60,CustomerAdded.CustomerAddedDt) THEN 1 ELSE 0 END)
		,CustomerAdded_OrdersHandled_90Day = SUM(CASE WHEN DATEADD(DAY,90,CustomerAdded.CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) AND OutboundOrders.OrderDt BETWEEN CustomerAdded.CustomerAddedDt AND DATEADD(DAY,90,CustomerAdded.CustomerAddedDt) THEN 1 ELSE 0 END)
		,MailDt_OrdersHandled_30Day = SUM(CASE WHEN DATEADD(DAY,30,CustomerAdded.MailDate) <= CAST(GETDATE()-1 AS DATE) AND OutboundOrders.OrderDt BETWEEN CustomerAdded.MailDate AND DATEADD(DAY,30,CustomerAdded.MailDate) THEN 1 ELSE 0 END)
		,MailDt_OrdersHandled_60Day = SUM(CASE WHEN DATEADD(DAY,60,CustomerAdded.MailDate) <= CAST(GETDATE()-1 AS DATE) AND OutboundOrders.OrderDt BETWEEN CustomerAdded.MailDate AND DATEADD(DAY,60,CustomerAdded.MailDate) THEN 1 ELSE 0 END)
		,MailDt_OrdersHandled_90Day = SUM(CASE WHEN DATEADD(DAY,90,CustomerAdded.MailDate) <= CAST(GETDATE()-1 AS DATE) AND OutboundOrders.OrderDt BETWEEN CustomerAdded.MailDate AND DATEADD(DAY,90,CustomerAdded.MailDate) THEN 1 ELSE 0 END)
		,CustomerAddedMailDt_OrdersHandled = SUM(CASE WHEN OutboundOrders.OrderDt BETWEEN CustomerAdded.CustomerAddedDt AND DATEADD(DAY,-1,CustomerAdded.MailDate) THEN 1 ELSE 0 END)
	FROM
		#OutboundOrders OutboundOrders
	JOIN	
		#CustomerAdded CustomerAdded
		ON OutboundOrders.CustomerID = CustomerAdded.CustomerID 
	GROUP BY
		OutboundOrders.CustomerID)
	
UPDATE
	CustomerAdded
SET	
	CustomerAdded_OrdersHandled_30Day = OutboundOrders.CustomerAdded_OrdersHandled_30Day
	,CustomerAdded_OrdersHandled_60Day = OutboundOrders.CustomerAdded_OrdersHandled_60Day
	,CustomerAdded_OrdersHandled_90Day = OutboundOrders.CustomerAdded_OrdersHandled_90Day
	,SimMailDt_OrdersHandled_30Day = OutboundOrders.MailDt_OrdersHandled_30Day
	,SimMailDt_OrdersHandled_60Day = OutboundOrders.MailDt_OrdersHandled_60Day
	,SimMailDt_OrdersHandled_90Day = OutboundOrders.MailDt_OrdersHandled_90Day
	,CustomerAddedSimMailDt_OrdersHandled = OutboundOrders.CustomerAddedMailDt_OrdersHandled
FROM
	#CustomerAdded CustomerAdded
JOIN
	OutboundOrders OutboundOrders
	ON CustomerAdded.CustomerID = OutboundOrders.CustomerID


/* --------------------------------------------------------------------------------------------------------------------------------------------*/
/* --------------------------------------------------------------------------------------------------------------------------------------------*/
IF EXISTS (Select TOP 1 'EXISTS' From tempdb.dbo.sysobjects Where ID = OBJECT_ID(N'tempdb..#_Paperless_MonthlyStatements'))
BEGIN  Drop Table #_Paperless_MonthlyStatements END;	

CREATE TABLE
	#_Paperless_MonthlyStatements
		(CustomerID BIGINT NOT NULL
		,EffectiveDt DATE NOT NULL);

CREATE CLUSTERED INDEX idx_CustomerID
ON #_Paperless_MonthlyStatements
(CustomerID);

INSERT INTO
	#_Paperless_MonthlyStatements
		(CustomerId
		,EffectiveDt)

SELECT 
	CustomerPreference.CustomerId
	,EffectiveDt = MIN(CAST(CustomerPreference.RowEffectiveDate AS DATE))
FROM 
	Smd.Customer.CustomerPreference CustomerPreference (NOLOCK)
JOIN 
	Smd.Customer.Preference Preference (NOLOCK) 
	ON CustomerPreference.PreferenceId = Preference.PreferenceId 
JOIN 
	Smd.Customer.PreferenceType PreferenceType (NOLOCK) 
	ON PreferenceType.PreferenceTypeId = CustomerPreference.PreferenceTypeId
	AND PreferenceType.PreferenceType = 'MonthlyStatementDelivery'
JOIN
	#CustomerAdded CustomerAdded
	ON CustomerPreference.CustomerID = CustomerAdded.CustomerID
	AND CAST(CustomerPreference.RowEffectiveDate AS DATE) BETWEEN CustomerAdded.CustomerAddedDt AND DATEADD(DAY,@dateRange,CustomerAdded.CustomerAddedDt)
WHERE 
	CustomerPreference.PreferenceId = 9
	AND CustomerPreference.PreferenceTypeID IN (1,2) 
GROUP BY
	CustomerPreference.CustomerId;

/* --------------------------------------------------------------------------------------------------------------------------------------------*/
/* --------------------------------------------------------------------------------------------------------------------------------------------*/
UPDATE
	#CustomerAdded
SET
	Paperless_MonthlyStatementsDt = CASE WHEN Paperless_MonthlyStatements.EffectiveDt IS NOT NULL THEN Paperless_MonthlyStatements.EffectiveDt ELSE NULL END
FROM	
	#CustomerAdded CustomerAdded
JOIN
	#_Paperless_MonthlyStatements Paperless_MonthlyStatements
	ON CustomerAdded.CustomerID = Paperless_MonthlyStatements.CustomerID;

/* --------------------------------------------------------------------------------------------------------------------------------------------*/
/* --------------------------------------------------------------------------------------------------------------------------------------------*/
IF EXISTS (Select TOP 1 'EXISTS' From tempdb.dbo.sysobjects Where ID = OBJECT_ID(N'tempdb..#SubscriptionRegistration'))
BEGIN  Drop Table #SubscriptionRegistration END;	

CREATE TABLE
	#SubscriptionRegistration
		(CustomerID BIGINT NOT NULL
		,RegistrationDt DATE NOT NULL);

CREATE CLUSTERED INDEX idx_CustomerID
ON #SubscriptionRegistration
(CustomerID);

INSERT INTO
	#SubscriptionRegistration
		(CustomerId
		,RegistrationDt)

SELECT
	 SubscriptionAccess.CustomerID
	,RegistrationDt = SubscriptionAccess.CreatedDate
FROM
	Smd.Customer.SubscriptionAccess(NOLOCK) SubscriptionAccess
JOIN
	#CustomerAdded CustomerAdded
	ON SubscriptionAccess.CustomerID = CustomerAdded.CustomerID
	AND CAST(SubscriptionAccess.CreatedDate AS DATE) BETWEEN CustomerAdded.CustomerAddedDt AND DATEADD(DAY,@dateRange,CustomerAdded.CustomerAddedDt)

/* --------------------------------------------------------------------------------------------------------------------------------------------*/
/* --------------------------------------------------------------------------------------------------------------------------------------------*/
UPDATE
	#CustomerAdded
SET
	SubscriptionRegisteredDt = CASE WHEN SubscriptionRegistration.RegistrationDt IS NOT NULL THEN SubscriptionRegistration.RegistrationDt ELSE NULL END
FROM	
	#CustomerAdded CustomerAdded
JOIN
	#SubscriptionRegistration SubscriptionRegistration
	ON CustomerAdded.CustomerID = SubscriptionRegistration.CustomerID;

/* --------------------------------------------------------------------------------------------------------------------------------------------*/
/* --------------------------------------------------------------------------------------------------------------------------------------------*/

SELECT
	 MEPERIOD 
	,CustomerSeries = 'Retail Customers'

	,CustomerCount = COUNT(CustomerID)                           
	,CustomerCount_60Day = COUNT(CustomerID)                     
	,CustomerCount_90Day = COUNT(CustomerID)                     

	,CustomerAdded_OrdersHandled_30Day    = (1.00 * SUM(CustomerAdded_OrdersHandled_30Day))/COUNT(CustomerID)
	,CustomerAdded_OrdersHandled_60Day    = (1.00 * SUM(CustomerAdded_OrdersHandled_60Day))/COUNT(CustomerID)
	,CustomerAdded_OrdersHandled_90Day    = (1.00 * SUM(CustomerAdded_OrdersHandled_90Day))/COUNT(CustomerID)
	,SimMailDt_OrdersHandled_30Day    = (1.00 * SUM(SimMailDt_OrdersHandled_30Day))/COUNT(CustomerID)
	,SimMailDt_OrdersHandled_60Day    = (1.00 * SUM(SimMailDt_OrdersHandled_60Day))/COUNT(CustomerID)
	,SimMailDt_OrdersHandled_90Day    = (1.00 * SUM(SimMailDt_OrdersHandled_90Day))/COUNT(CustomerID)
	,CustomerAddedSimMailDt_OrdersHandled = (1.00 * SUM(CustomerAddedSimMailDt_OrdersHandled))/COUNT(CustomerID)

	,CustomerAdded_Paperless_30Day = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN CustomerAddedDt AND DATEADD(DAY,30,CustomerAddedDt) THEN 1 ELSE 0 END)) / COUNT(CustomerID)
	,CustomerAdded_Paperless_60Day = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN CustomerAddedDt AND DATEADD(DAY,60,CustomerAddedDt) THEN 1 ELSE 0 END)) / COUNT(CustomerID)
	,CustomerAdded_Paperless_90Day = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN CustomerAddedDt AND DATEADD(DAY,90,CustomerAddedDt) THEN 1 ELSE 0 END)) / COUNT(CustomerID)
	,SimMailDt_Paperless_30Day = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN SimulatedMailDt AND DATEADD(DAY,30,SimulatedMailDt) THEN 1 ELSE 0 END)) / COUNT(CustomerID)
	,SimMailDt_Paperless_60Day = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN SimulatedMailDt AND DATEADD(DAY,60,SimulatedMailDt) THEN 1 ELSE 0 END)) / COUNT(CustomerID)
	,SimMailDt_Paperless_90Day = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN SimulatedMailDt AND DATEADD(DAY,90,SimulatedMailDt) THEN 1 ELSE 0 END)) / COUNT(CustomerID)
	,CustomerAddedSimMailDt_Paperless = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN CustomerAddedDt AND DATEADD(DAY,-1,SimulatedMailDt) THEN 1 ELSE 0 END)) / COUNT(CustomerID)

	,CustomerAdded_SubscriptionRegistered_30Day = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN CustomerAddedDt AND DATEADD(DAY,30,CustomerAddedDt) THEN 1 ELSE 0 END)) / COUNT(CustomerID)
	,CustomerAdded_SubscriptionRegistered_60Day = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN CustomerAddedDt AND DATEADD(DAY,60,CustomerAddedDt) THEN 1 ELSE 0 END)) / COUNT(CustomerID)
	,CustomerAdded_SubscriptionRegistered_90Day = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN CustomerAddedDt AND DATEADD(DAY,90,CustomerAddedDt) THEN 1 ELSE 0 END)) / COUNT(CustomerID)
	,SimMailDt_SubscriptionRegistered_30Day = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN SimulatedMailDt AND DATEADD(DAY,30,SimulatedMailDt) THEN 1 ELSE 0 END)) / COUNT(CustomerID)
	,SimMailDt_SubscriptionRegistered_60Day = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN SimulatedMailDt AND DATEADD(DAY,60,SimulatedMailDt) THEN 1 ELSE 0 END)) / COUNT(CustomerID)
	,SimMailDt_SubscriptionRegistered_90Day = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN SimulatedMailDt AND DATEADD(DAY,90,SimulatedMailDt) THEN 1 ELSE 0 END)) / COUNT(CustomerID)
	,CustomerAddedSimMailDt_SubscriptionRegistered = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN CustomerAddedDt AND DATEADD(DAY,-1,SimulatedMailDt) THEN 1 ELSE 0 END)) / COUNT(CustomerID)

	
FROM
	#HistoricalCustomerAdded HistoricalCustomerAdded

UNION

SELECT
	MEPERIOD 
	,CustomerSeries = 'Retail Customers'

	
	,CustomerCount = SUM(CASE WHEN DATEADD(DAY,30,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,CustomerCount_60Day = SUM(CASE WHEN DATEADD(DAY,60,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,CustomerCount_90Day = SUM(CASE WHEN DATEADD(DAY,90,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)


	,CustomerAdded_OrdersHandled_30Day    = (1.00 * SUM(CustomerAdded_OrdersHandled_30Day))/SUM(CASE WHEN DATEADD(DAY,30,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,CustomerAdded_OrdersHandled_60Day    = (1.00 * SUM(CustomerAdded_OrdersHandled_60Day))/SUM(CASE WHEN DATEADD(DAY,60,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,CustomerAdded_OrdersHandled_90Day    = (1.00 * SUM(CustomerAdded_OrdersHandled_90Day))/SUM(CASE WHEN DATEADD(DAY,90,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)

	,SimMailDt_OrdersHandled_30Day    = (1.00 * SUM(SimMailDt_OrdersHandled_30Day))/SUM(CASE WHEN DATEADD(DAY,30,MailDate) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,SimMailDt_OrdersHandled_60Day    = (1.00 * SUM(SimMailDt_OrdersHandled_60Day))/SUM(CASE WHEN DATEADD(DAY,60,MailDate) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,SimMailDt_OrdersHandled_90Day    = (1.00 * SUM(SimMailDt_OrdersHandled_90Day))/SUM(CASE WHEN DATEADD(DAY,90,MailDate) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)

	,CustomerAddedSimMailDt_OrdersHandled = (1.00 * SUM(CustomerAddedSimMailDt_OrdersHandled))/COUNT(CustomerID)


	,CustomerAdded_Paperless_30Day = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN CustomerAddedDt AND DATEADD(DAY,30,CustomerAddedDt) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,30,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,CustomerAdded_Paperless_60Day = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN CustomerAddedDt AND DATEADD(DAY,60,CustomerAddedDt) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,60,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,CustomerAdded_Paperless_90Day = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN CustomerAddedDt AND DATEADD(DAY,90,CustomerAddedDt) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,90,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)

	,SimMailDt_Paperless_30Day = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN MailDate AND DATEADD(DAY,30,MailDate) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,30,MailDate) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,SimMailDt_Paperless_60Day = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN MailDate AND DATEADD(DAY,60,MailDate) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,60,MailDate) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,SimMailDt_Paperless_90Day = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN MailDate AND DATEADD(DAY,90,MailDate) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,90,MailDate) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)

	,CustomerAddedSimMailDt_Paperless = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN CustomerAddedDt AND DATEADD(DAY,-1,MailDate) THEN 1 ELSE 0 END)) / COUNT(CustomerID)


	,CustomerAdded_SubscriptionRegistered_30Day = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN CustomerAddedDt AND DATEADD(DAY,30,CustomerAddedDt) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,30,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,CustomerAdded_SubscriptionRegistered_60Day = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN CustomerAddedDt AND DATEADD(DAY,60,CustomerAddedDt) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,60,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,CustomerAdded_SubscriptionRegistered_90Day = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN CustomerAddedDt AND DATEADD(DAY,90,CustomerAddedDt) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,90,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)

	,SimMailDt_SubscriptionRegistered_30Day = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN MailDate AND DATEADD(DAY,30,MailDate) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,30,MailDate) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,SimMailDt_SubscriptionRegistered_60Day = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN MailDate AND DATEADD(DAY,60,MailDate) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,60,MailDate) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,SimMailDt_SubscriptionRegistered_90Day = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN MailDate AND DATEADD(DAY,90,MailDate) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,90,MailDate) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)

	,CustomerAddedSimMailDt_SubscriptionRegistered = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN CustomerAddedDt AND DATEADD(DAY,-1,MailDate) THEN 1 ELSE 0 END)) / COUNT(CustomerID)

FROM
	#CustomerAdded HistoricalCustomerAdded


/* --------------------------------------------------------------------------------------------------------------------------------------------*/
/* --------------------------------------------------------------------------------------------------------------------------------------------*/
SELECT 'Opened'
SELECT
	MEPERIOD 
	,CustomerSeries = 'Retail Customers'


	,CustomerCount = SUM(CASE WHEN DATEADD(DAY,30,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,CustomerCount_60Day = SUM(CASE WHEN DATEADD(DAY,60,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,CustomerCount_90Day = SUM(CASE WHEN DATEADD(DAY,90,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)



	,CustomerAdded_OrdersHandled_30Day    = (1.00 * SUM(CustomerAdded_OrdersHandled_30Day))/SUM(CASE WHEN DATEADD(DAY,30,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)               
	,CustomerAdded_OrdersHandled_60Day    = (1.00 * SUM(CustomerAdded_OrdersHandled_60Day))/SUM(CASE WHEN DATEADD(DAY,60,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,CustomerAdded_OrdersHandled_90Day    = (1.00 * SUM(CustomerAdded_OrdersHandled_90Day))/SUM(CASE WHEN DATEADD(DAY,90,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)

	,SimMailDt_OrdersHandled_30Day    = (1.00 * SUM(SimMailDt_OrdersHandled_30Day))/SUM(CASE WHEN DATEADD(DAY,30,MailDate) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,SimMailDt_OrdersHandled_60Day    = (1.00 * SUM(SimMailDt_OrdersHandled_60Day))/SUM(CASE WHEN DATEADD(DAY,60,MailDate) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,SimMailDt_OrdersHandled_90Day    = (1.00 * SUM(SimMailDt_OrdersHandled_90Day))/SUM(CASE WHEN DATEADD(DAY,90,MailDate) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)

	,CustomerAddedSimMailDt_OrdersHandled = (1.00 * SUM(CustomerAddedSimMailDt_OrdersHandled))/COUNT(CustomerID)


	,CustomerAdded_Paperless_30Day = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN CustomerAddedDt AND DATEADD(DAY,30,CustomerAddedDt) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,30,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,CustomerAdded_Paperless_60Day = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN CustomerAddedDt AND DATEADD(DAY,60,CustomerAddedDt) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,60,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,CustomerAdded_Paperless_90Day = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN CustomerAddedDt AND DATEADD(DAY,90,CustomerAddedDt) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,90,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)

	,SimMailDt_Paperless_30Day = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN MailDate AND DATEADD(DAY,30,MailDate) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,30,MailDate) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,SimMailDt_Paperless_60Day = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN MailDate AND DATEADD(DAY,60,MailDate) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,60,MailDate) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,SimMailDt_Paperless_90Day = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN MailDate AND DATEADD(DAY,90,MailDate) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,90,MailDate) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)

	,CustomerAddedSimMailDt_Paperless = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN CustomerAddedDt AND DATEADD(DAY,-1,MailDate) THEN 1 ELSE 0 END)) / COUNT(CustomerID)


	
	,CustomerAdded_SubscriptionRegistered_30Day = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN CustomerAddedDt AND DATEADD(DAY,30,CustomerAddedDt) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,30,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,CustomerAdded_SubscriptionRegistered_60Day = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN CustomerAddedDt AND DATEADD(DAY,60,CustomerAddedDt) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,60,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,CustomerAdded_SubscriptionRegistered_90Day = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN CustomerAddedDt AND DATEADD(DAY,90,CustomerAddedDt) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,90,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)

	,SimMailDt_SubscriptionRegistered_30Day = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN MailDate AND DATEADD(DAY,30,MailDate) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,30,MailDate) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,SimMailDt_SubscriptionRegistered_60Day = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN MailDate AND DATEADD(DAY,60,MailDate) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,60,MailDate) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,SimMailDt_SubscriptionRegistered_90Day = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN MailDate AND DATEADD(DAY,90,MailDate) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,90,MailDate) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)

	,CustomerAddedSimMailDt_SubscriptionRegistered = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN CustomerAddedDt AND DATEADD(DAY,-1,MailDate) THEN 1 ELSE 0 END)) / COUNT(CustomerID)


FROM
	#CustomerAdded HistoricalCustomerAdded
WHERE
	Opened = 1

/* --------------------------------------------------------------------------------------------------------------------------------------------*/
/* --------------------------------------------------------------------------------------------------------------------------------------------*/


SELECT 'Clicked'
SELECT
	MEPERIOD 
	,CustomerSeries = 'Retail Customers'


	,CustomerCount = SUM(CASE WHEN DATEADD(DAY,30,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,CustomerCount_60Day = SUM(CASE WHEN DATEADD(DAY,60,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,CustomerCount_90Day = SUM(CASE WHEN DATEADD(DAY,90,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)



	,CustomerAdded_OrdersHandled_30Day    = (1.00 * SUM(CustomerAdded_OrdersHandled_30Day))/SUM(CASE WHEN DATEADD(DAY,30,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,CustomerAdded_OrdersHandled_60Day    = (1.00 * SUM(CustomerAdded_OrdersHandled_60Day))/SUM(CASE WHEN DATEADD(DAY,60,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,CustomerAdded_OrdersHandled_90Day    = (1.00 * SUM(CustomerAdded_OrdersHandled_90Day))/SUM(CASE WHEN DATEADD(DAY,90,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)

	,SimMailDt_OrdersHandled_30Day    = (1.00 * SUM(SimMailDt_OrdersHandled_30Day))/SUM(CASE WHEN DATEADD(DAY,30,MailDate) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,SimMailDt_OrdersHandled_60Day    = (1.00 * SUM(SimMailDt_OrdersHandled_60Day))/SUM(CASE WHEN DATEADD(DAY,60,MailDate) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,SimMailDt_OrdersHandled_90Day    = (1.00 * SUM(SimMailDt_OrdersHandled_90Day))/SUM(CASE WHEN DATEADD(DAY,90,MailDate) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)

	,CustomerAddedSimMailDt_OrdersHandled = (1.00 * SUM(CustomerAddedSimMailDt_OrdersHandled))/COUNT(CustomerID)



	,CustomerAdded_Paperless_30Day = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN CustomerAddedDt AND DATEADD(DAY,30,CustomerAddedDt) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,30,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,CustomerAdded_Paperless_60Day = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN CustomerAddedDt AND DATEADD(DAY,60,CustomerAddedDt) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,60,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,CustomerAdded_Paperless_90Day = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN CustomerAddedDt AND DATEADD(DAY,90,CustomerAddedDt) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,90,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)

	,SimMailDt_Paperless_30Day = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN MailDate AND DATEADD(DAY,30,MailDate) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,30,MailDate) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,SimMailDt_Paperless_60Day = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN MailDate AND DATEADD(DAY,60,MailDate) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,60,MailDate) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,SimMailDt_Paperless_90Day = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN MailDate AND DATEADD(DAY,90,MailDate) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,90,MailDate) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)

	,CustomerAddedSimMailDt_Paperless = (1.00 * SUM(CASE WHEN Paperless_MonthlyStatementsDt BETWEEN CustomerAddedDt AND DATEADD(DAY,-1,MailDate) THEN 1 ELSE 0 END)) / COUNT(CustomerID)


	
	,CustomerAdded_SubscriptionRegistered_30Day = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN CustomerAddedDt AND DATEADD(DAY,30,CustomerAddedDt) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,30,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,CustomerAdded_SubscriptionRegistered_60Day = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN CustomerAddedDt AND DATEADD(DAY,60,CustomerAddedDt) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,60,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,CustomerAdded_SubscriptionRegistered_90Day = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN CustomerAddedDt AND DATEADD(DAY,90,CustomerAddedDt) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,90,CustomerAddedDt) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)

	,SimMailDt_SubscriptionRegistered_30Day = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN MailDate AND DATEADD(DAY,30,MailDate) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,30,MailDate) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,SimMailDt_SubscriptionRegistered_60Day = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN MailDate AND DATEADD(DAY,60,MailDate) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,60,MailDate) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)
	,SimMailDt_SubscriptionRegistered_90Day = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN MailDate AND DATEADD(DAY,90,MailDate) THEN 1 ELSE 0 END)) / SUM(CASE WHEN DATEADD(DAY,90,MailDate) <= CAST(GETDATE()-1 AS DATE) THEN 1 ELSE 0 END)

	,CustomerAddedSimMailDt_SubscriptionRegistered = (1.00 * SUM(CASE WHEN SubscriptionRegisteredDt BETWEEN CustomerAddedDt AND DATEADD(DAY,-1,MailDate) THEN 1 ELSE 0 END)) / COUNT(CustomerID)

FROM
	#CustomerAdded HistoricalCustomerAdded
WHERE
	Clicked = 1





SELECT
	 Distinct LA.CustomerID
	,LA.CustomerAddedDt
	,LA.MailDate
	,OutBound.OrderID
	,OutBound.OrderDt
	,LA.Opened
	,LA.Clicked
	,DaysFromEmail = DATEDIFF(DAY,LA.MailDate,OutBound.OrderDt)
	,OrderType1 = CASE WHEN OrderID.OrderType1 IS NOT NULL THEN OrderID.OrderType1
					  WHEN CustomerID.OrderType1 IS NOT NULL THEN CustomerID.OrderType1
					  ELSE NULL END
	,OrderType2 = CASE WHEN OrderID.OrderType2 IS NOT NULL THEN OrderID.OrderType2
					  WHEN CustomerID.OrderType2 IS NOT NULL THEN CustomerID.OrderType2
					  ELSE NULL END
	,OrderType3 = CASE WHEN OrderID.OrderType3 IS NOT NULL THEN OrderID.OrderType3
					  WHEN CustomerID.OrderType3 IS NOT NULL THEN CustomerID.OrderType3
					  ELSE NULL END
	,JoinType = CASE WHEN OrderID.TransactionId IS NOT NULL THEN 'OrderID'
					 WHEN CustomerID.TransactionId IS NOT NULL THEN 'CustomerID x OrderDt'
					 ELSE 'No Match'
					 END
FROM
	#CustomerAdded LA
JOIN
	#OutboundOrders OutBound
	ON LA.CustomerID = OutBound.CustomerID
	AND OutBound.OrderDt >= LA.MailDate
LEFT JOIN
	Smd.customer.OrderCenterSummary OrderID
	ON OutBound.OrderID = OrderID.OrderId
	AND OrderID.WorkType = 'Outbound Order'


