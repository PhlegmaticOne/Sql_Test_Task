--||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

-- 1.
-- Database creation

CREATE DATABASE bank_db
GO

USE bank_db;
GO

--Tables setup

CREATE TABLE SocialStatuses(
	Id uniqueidentifier primary key default NEWID(),
	Name nvarchar(50) not null
);

CREATE TABLE Cities(
	Id uniqueidentifier primary key default NEWID(),
	Name nvarchar(70) not null
);

CREATE TABLE Clients(
	Id uniqueidentifier primary key default NEWID(),
	Name nvarchar(100) not null,
	Surname nvarchar(100) not null,
	SocialStatusId uniqueidentifier not null,
);

CREATE TABLE Banks(
	Id uniqueidentifier primary key default NEWID(),
	Name nvarchar(100) not null unique
);

CREATE TABLE BankBranches(
	Id uniqueidentifier primary key default NEWID(),
	BankId uniqueidentifier not null,
);

CREATE TABLE CitiesBankBranches(
	CityId uniqueidentifier not null,
	BankBranchId uniqueidentifier not null
);

CREATE TABLE Cards(
	Id uniqueidentifier primary key default NEWID(),
	AccountId uniqueidentifier not null,
	Balance money not null default 0
);

CREATE TABLE Accounts(
	Id uniqueidentifier primary key default NEWID(),
	Balance money not null default 0,
	ClientId uniqueidentifier not null,
	BankId uniqueidentifier not null
);
GO

-- Constraints setup

-- Clients and social statuses
ALTER TABLE Clients ADD CONSTRAINT FK_SocialStatuses_Clients 
FOREIGN KEY (SocialStatusId) REFERENCES SocialStatuses (Id)

-- Banks and bank branches
ALTER TABLE BankBranches ADD CONSTRAINT FK_Banks_BankBranches
FOREIGN KEY (BankId) REFERENCES Banks (Id)

-- Many to many
-- To cities
ALTER TABLE CitiesBankBranches ADD CONSTRAINT FK_CitiesBankBranches_Cities
FOREIGN KEY (CityId) REFERENCES Cities (Id)

-- To bank branches
ALTER TABLE CitiesBankBranches ADD CONSTRAINT FK_CitiesBankBranches_BankBranches
FOREIGN KEY (BankBranchId) REFERENCES BankBranches (Id)

-- Cards and Accounts
ALTER TABLE Cards ADD CONSTRAINT FK_Cards_Accounts
FOREIGN KEY (AccountId) REFERENCES Accounts (Id)

-- Accounts and clients
ALTER TABLE Accounts ADD CONSTRAINT FK_Accounts_Clients
FOREIGN KEY (ClientId) REFERENCES Clients (Id)

-- Accounts and banks
ALTER TABLE Accounts ADD CONSTRAINT FK_Accounts_Banks
FOREIGN KEY (BankId) REFERENCES Banks (Id)


-- Unique constraint: users must have one account per bank
ALTER TABLE Accounts ADD CONSTRAINT UQ_Accounts_Clients_Banks
UNIQUE (ClientId, BankId)
GO



--||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

-- Data insertion

USE bank_db
GO

-- Data preparation

DECLARE @banks nvarchar(100) =
	'Tinkoff,Sberbank,Belarusbank,AlfaBank,Belinvest,Belgazprombank'

DECLARE @cities nvarchar(100) =
	'Moscow,Saint-Peterburg,Minsk,Gomel,Brest,Vitebsk,Grodno,Mogilev'

DECLARE @socialStatuses nvarchar(100) = 
	'Default,Pensioner,Disabled,Veteran,Foreigner,Orphan'

DECLARE @people nvarchar(MAX) =
	'VASILIY VASILEVICH,ANDREY ANDREEVICH,ALEXANDR ALEXANDROVICH,DENIS DENISOVICH,KIRILL KIRILLOVICH,ALEXEY ALEXEEVICH,ANATOLIY ANATOLEVICH,PAVEL PAVLOVICH'

DECLARE @cardsPerAccountCount int = 2

DECLARE @maxBalance int = 100000

DECLARE @minBalance int = 1000



-- Insert Social statuses
INSERT INTO SocialStatuses (Name)
SELECT * FROM string_split(@socialStatuses, ',') 

-- Insert cities
INSERT INTO Cities (Name)
SELECT * FROM string_split(@cities, ',') 

-- Insert banks
INSERT INTO Banks (Name)
SELECT * FROM string_split(@banks, ',')


DECLARE @i int = 0
DECLARE @k int = 3

-- Insert k bank branches for each bank
WHILE @i < @k
BEGIN
	INSERT INTO BankBranches (BankId) SELECT Banks.Id FROM Banks
	SET @i = @i + 1
END


-- Find 3 random city ids for each branch and insert info in many-to-many table

DECLARE BankBranchesIdCursor CURSOR LOCAL STATIC FOR 
SELECT BankBranches.Id FROM BankBranches

DECLARE @currentBranchId uniqueidentifier

OPEN BankBranchesIdCursor
FETCH NEXT FROM BankBranchesIdCursor INTO @currentBranchId
WHILE @@FETCH_STATUS = 0
BEGIN
	INSERT INTO CitiesBankBranches (BankBranchId, CityId)
	SELECT TOP 3 @currentBranchId, Cities.Id FROM Cities ORDER BY NEWID()

    FETCH NEXT FROM BankBranchesIdCursor INTO @currentBranchId
END
   
CLOSE BankBranchesIdCursor
DEALLOCATE BankBranchesIdCursor


-- Clients insertion
DECLARE PeopleCursor CURSOR LOCAL STATIC FOR 
SELECT value FROM string_split(@people, ',')

DECLARE @currentHuman nvarchar(50)

OPEN PeopleCursor
FETCH NEXT FROM PeopleCursor INTO @currentHuman
WHILE @@FETCH_STATUS = 0
BEGIN
	DECLARE @randomStatusId uniqueidentifier = 
	(SELECT TOP 1 SocialStatuses.Id FROM SocialStatuses ORDER BY NEWID())

	DECLARE @pos int = CHARINDEX(' ', @currentHuman)  
	DECLARE @length int = LEN(@currentHuman)
	DECLARE @name nvarchar(30) = SUBSTRING(@currentHuman, 1, @pos - 1)
	DECLARE @surname nvarchar(30) = SUBSTRING(@currentHuman, @pos + 1, @length)

	INSERT INTO Clients (Name, Surname, SocialStatusId) VALUES (@name, @surname, @randomStatusId)

    FETCH NEXT FROM PeopleCursor INTO @currentHuman
END
   
CLOSE PeopleCursor
DEALLOCATE PeopleCursor


-- Accounts generation
DECLARE ClientsCursor CURSOR LOCAL STATIC FOR 
SELECT Clients.Id FROM Clients

DECLARE @currentClient uniqueidentifier

OPEN ClientsCursor
FETCH NEXT FROM ClientsCursor INTO @currentClient
WHILE @@FETCH_STATUS = 0
BEGIN
	
	INSERT INTO Accounts (BankId, ClientId, Balance)
	SELECT B.Id, @currentClient, FLOOR(RAND()*(@maxBalance-@minBalance)+@minBalance) FROM 
	(SELECT TOP 3 Banks.Id FROM Banks ORDER BY NEWID()) B

    FETCH NEXT FROM ClientsCursor INTO @currentClient
END
   
CLOSE ClientsCursor
DEALLOCATE ClientsCursor


-- Cards generation
DECLARE AccountsCursor CURSOR LOCAL STATIC FOR 
SELECT Accounts.Id, Accounts.Balance FROM Accounts

DECLARE @currentAccountId uniqueidentifier
DECLARE @currentAccountBalance money

OPEN AccountsCursor
FETCH NEXT FROM AccountsCursor INTO @currentAccountId, @currentAccountBalance
WHILE @@FETCH_STATUS = 0
BEGIN
	DECLARE @q int = 0

	DECLARE @cardMaxBalance int = @currentAccountBalance / @cardsPerAccountCount

	WHILE @q < @cardsPerAccountCount
	BEGIN
		INSERT INTO Cards (AccountId, Balance) VALUES
		(@currentAccountId, FLOOR(RAND()*(@cardMaxBalance-@minBalance)+@minBalance))
		
		SET @q = @q + 1
	END

    FETCH NEXT FROM AccountsCursor INTO @currentAccountId, @currentAccountBalance
END
   
CLOSE AccountsCursor
DEALLOCATE AccountsCursor

-- Attempting to insert a new Account for a user who already has an Account with a given bank
-- Unique constraint fails insertion
DECLARE @existingBankId  uniqueidentifier, @existingClientId uniqueIdentifier

SELECT TOP 1  
	@existingBankId = Accounts.BankId,
	@existingClientId = Accounts.ClientId
FROM Accounts
ORDER BY NEWID()

INSERT INTO Accounts (BankId, ClientId) VALUES (@existingBankId, @existingClientId)


-- 2.
DECLARE @cityToSearch nvarchar(50) = 'Minsk'

SELECT DISTINCT Banks.Name FROM Cities
INNER JOIN CitiesBankBranches ON Cities.Id = CitiesBankBranches.CityId
INNER JOIN BankBranches ON BankBranches.Id = CitiesBankBranches.BankBranchId
INNER JOIN Banks ON Banks.Id = BankBranches.BankId
WHERE Cities.Name = @cityToSearch


-- 3.
SELECT Cards.Id, Cards.Balance, Clients.Name, Clients.Surname, Banks.Name
FROM Cards
INNER JOIN Accounts ON Cards.AccountId = Accounts.Id
INNER JOIN Clients ON Clients.Id = Accounts.ClientId
INNER JOIN Banks ON Banks.Id = Accounts.BankId


-- 4.
SELECT Cards.AccountId, (Accounts.Balance - SUM(Cards.Balance)) as AccountBalanceMinusCardsTotalBalance
FROM Cards
INNER JOIN Accounts ON Cards.AccountId = Accounts.Id
GROUP BY Cards.AccountId, Accounts.Balance
HAVING SUM(Cards.Balance) != Accounts.Balance


--5.1.
SELECT SocialStatuses.Name, COUNT(Cards.Id) AS CardsPerStatusCount
FROM Cards
INNER JOIN Accounts ON Accounts.Id = Cards.AccountId
INNER JOIN Clients ON Clients.Id = Accounts.ClientId
RIGHT JOIN SocialStatuses ON SocialStatuses.Id = Clients.SocialStatusId
GROUP BY SocialStatuses.Name

--5.2
SELECT S.Name, (SELECT COUNT(Cards.Id) AS CardsPerStatusCount
			    FROM Cards
			    INNER JOIN Accounts ON Accounts.Id = Cards.AccountId
			    INNER JOIN Clients ON Clients.Id = Accounts.ClientId
			    WHERE Clients.SocialStatusId = S.Id) as CardsPerStatusCount
FROM SocialStatuses S


--6
-- Procedure code
USE [bank_db]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[AddTenDollarsToAccountsHavingClientStatus] 
	@socialStatusId uniqueidentifier
AS
BEGIN
	SET NOCOUNT ON;

	IF NOT EXISTS (SELECT * FROM SocialStatuses WHERE Id = @socialStatusId)
	BEGIN;
		DECLARE @msg1 nvarchar(100) = 
		FORMATMESSAGE('There is no social status with Id: %s', convert(nvarchar(36), @socialStatusId));

		THROW 98001, @msg1, 1
	END;

	UPDATE ACC
	SET ACC.Balance = ACC.Balance + 10
	FROM  Accounts ACC 
	INNER JOIN Clients ON Clients.Id = ACC.ClientId
	WHERE Clients.SocialStatusId = @socialStatusId

	IF @@ROWCOUNT = 0
	BEGIN;
		DECLARE @msg2 nvarchar(100) = 
		FORMATMESSAGE('There are no any clients with social status (%s)', convert(nvarchar(36), @socialStatusId));

		THROW 99001, @msg2, 2
	END;
END

-- Test cases

-- 1) Invalid social status id
DECLARE @invalidStatusId uniqueidentifier = '00000000-0000-0000-0000-000000000000'
EXEC AddTenDollarsToAccountsHavingClientStatus @invalidStatusId

-- 2) Status with id that nobody has
DECLARE @statusIdNoClientsHave uniqueidentifier = 
(SELECT TOP 1 SocialStatuses.Id FROM Clients 
RIGHT JOIN SocialStatuses ON Clients.SocialStatusId = SocialStatuses.Id
WHERE Clients.Name is null)

IF @statusIdNoClientsHave is not null
BEGIN
	EXEC AddTenDollarsToAccountsHavingClientStatus @statusIdNoClientsHave
END

--3) Default execution
DECLARE @randomStatusId uniqueidentifier = 
(SELECT TOP 1 SocialStatuses.Id FROM Clients 
RIGHT JOIN SocialStatuses ON Clients.SocialStatusId = SocialStatuses.Id
WHERE Clients.Name is not null
ORDER BY NEWID())

SELECT Accounts.Id, Accounts.Balance
FROM Accounts
INNER JOIN Clients ON Accounts.ClientId = Clients.Id
WHERE Clients.SocialStatusId = @randomStatusId

EXEC AddTenDollarsToAccountsHavingClientStatus @randomStatusId

SELECT Accounts.Id, Accounts.Balance
FROM Accounts
INNER JOIN Clients ON Accounts.ClientId = Clients.Id
WHERE Clients.SocialStatusId = @randomStatusId

--7.
SELECT Clients.Name, Clients.Surname, Cards.AccountId, (Accounts.Balance - SUM(Cards.Balance)) as AvailableMoney
FROM Cards
INNER JOIN Accounts ON Cards.AccountId = Accounts.Id
INNER JOIN Clients ON Clients.Id = Accounts.ClientId
GROUP BY Cards.AccountId, Accounts.Balance, Clients.Name, Clients.Surname
ORDER BY Clients.Name, Clients.Surname

--8.
-- Procedure 
-- Procedure uses trigger (instead of update) from 9 task
USE [bank_db]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PerformTransactionFromAccountToCard]
	@accountId uniqueidentifier,
	@cardId uniqueidentifier,
	@amount money
AS
BEGIN
	SET NOCOUNT ON;

	IF @amount <= 0
	BEGIN
		DECLARE @msg1 nvarchar(200) = 'Transer value must be greater than zero';

		THROW 100001, @msg1, 3;
	END

	IF NOT EXISTS (SELECT * FROM Accounts WHERE Id = @accountId)
	BEGIN
		DECLARE @msg2 nvarchar(200) = 
		FORMATMESSAGE('Account (%s) does not exist', convert(nvarchar(36), @accountId));

		THROW 101001, @msg2, 4;
	END

	DECLARE @cardAccountId uniqueidentifier = 
	(SELECT TOP 1 Cards.AccountId FROM Cards WHERE Cards.Id = @cardId)

	IF @cardAccountId is null
	BEGIN
		DECLARE @msg3 nvarchar(200) = 
		FORMATMESSAGE('Card (%s) does not exist', convert(nvarchar(36), @cardId));

		THROW 102001, @msg3, 5
	END

	IF @cardAccountId != @accountId
	BEGIN
		DECLARE @msg4 nvarchar(200) = 
		FORMATMESSAGE('Card (%s) does not belong to Account (%s)',
		convert(nvarchar(36), @cardId), convert(nvarchar(36), @accountId));

		THROW 103001, @msg4, 6;
	END
	
	BEGIN TRANSACTION;
	BEGIN TRY
		UPDATE Cards
		SET Balance = Balance + @amount
		WHERE Cards.Id = @cardId
	END TRY
	BEGIN CATCH
		ROLLBACK;
		THROW;
	END CATCH
	COMMIT;
END

-- Test cases
-- 1) Transfer value <= 0
DECLARE @invalidId uniqueidentifier = '00000000-0000-0000-0000-000000000000'
DECLARE @transferValue int = -69
EXEC PerformTransactionFromAccountToCard @invalidId, @invalidId, @transferValue

-- 2) Account does not exist
DECLARE @invalidId uniqueidentifier = '00000000-0000-0000-0000-000000000000'
DECLARE @transferValue int = 69
EXEC PerformTransactionFromAccountToCard @invalidId, @invalidId, @transferValue

-- 3) Card does not exist but account exists
DECLARE @randomAccountId uniqueidentifier = 
(SELECT TOP 1 Accounts.Id FROM Accounts ORDER BY NEWID())
 
DECLARE @invalidId uniqueidentifier = '00000000-0000-0000-0000-000000000000'
DECLARE @transferValue int = 69
EXEC PerformTransactionFromAccountToCard @randomAccountId, @invalidId, @transferValue

-- 4) Card exists but it has AccountId foreign key value not equal to @accountId procedure parameter
DECLARE @randomAccountId uniqueidentifier = 
(SELECT TOP 1 Accounts.Id FROM Accounts ORDER BY NEWID())
 
DECLARE @randomCardId uniqueidentifier = 
(SELECT TOP 1 Cards.Id FROM Cards WHERE Cards.AccountId != @randomAccountId ORDER BY NEWID())
 
DECLARE @transferValue int = 69
 
EXEC PerformTransactionFromAccountToCard @randomAccountId, @randomCardId, @transferValue

-- 5) Transfer value is too big
DECLARE @randomAccountId uniqueidentifier, @accountBalance money 
SELECT TOP 1 @randomAccountId = Accounts.Id,
             @accountBalance = Accounts.Balance
FROM Accounts
ORDER BY NEWID()

DECLARE @randomCardId uniqueidentifier = 
(SELECT TOP 1 Cards.Id FROM Cards
 WHERE Cards.AccountId = @randomAccountId
 ORDER BY NEWID())
 
DECLARE @transferValue int = @accountBalance
 
EXEC PerformTransactionFromAccountToCard @randomAccountId, @randomCardId, @transferValue

--6) Default execution
DECLARE @randomAccountId uniqueidentifier, @accountBalance money 
DECLARE @randomCardId uniqueidentifier, @cardTotalBalance money

SELECT TOP 1 @randomAccountId = Accounts.Id,
             @accountBalance = Accounts.Balance
FROM Accounts
ORDER BY NEWID()

SET @randomCardId = 
(SELECT TOP 1 Cards.Id FROM Cards WHERE Cards.AccountId = @randomAccountId ORDER BY NEWID())

SET @cardTotalBalance = 
(SELECT SUM(Cards.Balance) FROM Cards WHERE Cards.AccountId = @randomAccountId)

-- Transer half of remained money 
DECLARE @transferValue int = (@accountBalance - @cardTotalBalance) / 2


SELECT *, @accountBalance as AccountBalance 
FROM Cards WHERE Cards.AccountId = @randomAccountId
 
EXEC PerformTransactionFromAccountToCard @randomAccountId, @randomCardId, @transferValue

SELECT *, @accountBalance as AccountBalance 
FROM Cards WHERE Cards.AccountId = @randomAccountId

-- 9)
-- 9.1 Card trigger (used in transer procedure)
-- Trigger code
USE [bank_db]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TRIGGER [dbo].[Cards_InsteadOfUpdate]
ON [dbo].[Cards]
INSTEAD OF UPDATE
AS
BEGIN

	DECLARE @updatingCardId uniqueidentifier, @updatingAccountId uniqueidentifier, @updatingBalance money
 
    SELECT @updatingAccountId = inserted.AccountId,
           @updatingBalance = inserted.Balance,
		   @updatingCardId = inserted.Id
    FROM inserted

	DECLARE @availableAccountBalance money =
	(SELECT TOP 1 Accounts.Balance FROM Accounts WHERE Accounts.Id = @updatingAccountId)
	

	DECLARE @cardsTotalBalance money = 
	(SELECT SUM(Cards.Balance) 
	 FROM Cards 
	 WHERE Cards.AccountId = @updatingAccountId AND Cards.Id != @updatingCardId)
	 + @updatingBalance

	DECLARE @remainedBalance money = @availableAccountBalance - @cardsTotalBalance
	IF @remainedBalance < 0
	BEGIN
		DECLARE @msg nvarchar(200) = 
		FORMATMESSAGE('There is not enough Balance on Account to make transfer. Available account balance is (%s). With this transer it will be (%s)',
		CONVERT(varchar(20), CAST(@availableAccountBalance AS DECIMAL(18,2))), CONVERT(varchar(20), CAST(@remainedBalance AS DECIMAL(18,2))));

		THROW 104001, @msg, 7;
	END

	UPDATE Cards
	SET Balance = @updatingBalance
	WHERE Cards.Id = @updatingCardId
END
-- Tested in 8 task

--9.2 Account trigger
-- Trigger code
USE [bank_db]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TRIGGER [dbo].[Accounts_InsteadOfUpdate]
ON [dbo].[Accounts]
INSTEAD OF UPDATE
AS
BEGIN
	DECLARE UpdatingAccountsCursor CURSOR LOCAL STATIC FOR 
	SELECT inserted.Id, inserted.Balance FROM inserted

	DECLARE @updatingAccountId uniqueidentifier
	DECLARE @updatingAccountBalance money

	BEGIN TRANSACTION;

	OPEN UpdatingAccountsCursor
	FETCH NEXT FROM UpdatingAccountsCursor INTO @updatingAccountId, @updatingAccountBalance
	WHILE @@FETCH_STATUS = 0
	BEGIN

		DECLARE @totalBalanceOnCards money = 
		(SELECT SUM(Cards.Balance) FROM Cards WHERE Cards.AccountId = @updatingAccountId)

		IF @updatingAccountBalance < @totalBalanceOnCards
		BEGIN
			ROLLBACK;
			
			CLOSE UpdatingAccountsCursor
			DEALLOCATE UpdatingAccountsCursor;
			DECLARE @msg nvarchar(200) = 
			FORMATMESSAGE('Updating Account (%s) balance value is incorrect. Yoy are trying to set balance: %s, but total cards balance is: (%s)',
			convert(nvarchar(36), @updatingAccountId), CONVERT(varchar(20), CAST(@updatingAccountBalance AS DECIMAL(18,2))), CONVERT(varchar(20), CAST(@totalBalanceOnCards AS DECIMAL(18,2))));
			THROW 105001, @msg, 8;
		END
		ELSE
		BEGIN
			UPDATE Accounts
			SET Balance = @updatingAccountBalance
			WHERE Accounts.Id = @updatingAccountId
		END

		FETCH NEXT FROM UpdatingAccountsCursor INTO @updatingAccountId, @updatingAccountBalance
	END
   
	CLOSE UpdatingAccountsCursor
	DEALLOCATE UpdatingAccountsCursor

	COMMIT

END

-- Test cases
-- 1) Trying to set value less than total cards balance in random account
DECLARE @randomAccountId uniqueidentifier, @accountBalance money 

SELECT TOP 1 @randomAccountId = Accounts.Id,
             @accountBalance = Accounts.Balance
FROM Accounts
ORDER BY NEWID()

DECLARE @cardTotalBalance money = 
(SELECT SUM(Cards.Balance) FROM Cards WHERE Cards.AccountId = @randomAccountId)

SELECT * FROM Accounts WHERE Accounts.Id = @randomAccountId

UPDATE Accounts
SET Balance = @cardTotalBalance / 2
WHERE Id = @randomAccountId

SELECT * FROM Accounts WHERE Accounts.Id = @randomAccountId

-- 2) Default execution
DECLARE @randomAccountId uniqueidentifier, @accountBalance money 

SELECT TOP 1 @randomAccountId = Accounts.Id,
             @accountBalance = Accounts.Balance
FROM Accounts
ORDER BY NEWID()

DECLARE @cardTotalBalance money = 
(SELECT SUM(Cards.Balance) FROM Cards WHERE Cards.AccountId = @randomAccountId)

SELECT * FROM Accounts WHERE Accounts.Id = @randomAccountId

DECLARE @balanceToSet money;
SET @balanceToSet = @accountBalance + 420
--SET @balanceToSet = (@accountBalance - @cardTotalBalance) / 2

UPDATE Accounts
SET Balance = @balanceToSet
WHERE Id = @randomAccountId

SELECT * FROM Accounts WHERE Accounts.Id = @randomAccountId