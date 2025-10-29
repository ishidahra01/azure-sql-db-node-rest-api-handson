/*
    Azure PaaS ハンズオン用 SQL セットアップスクリプト
    
    このスクリプトは、ハンズオンで使用する最小限のスキーマとサンプルデータを作成します。
    Azure Portal の Query Editor や Azure Data Studio から実行してください。
*/

-- Customers テーブルの作成
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Customers' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.Customers (
        CustomerID     INT PRIMARY KEY,
        CustomerName   NVARCHAR(200) NOT NULL,
        PhoneNumber    NVARCHAR(50),
        WebsiteURL     NVARCHAR(200),
        AddressLine1   NVARCHAR(200),
        AddressLine2   NVARCHAR(200),
        PostalCode     NVARCHAR(20)
    );
    
    PRINT 'Customers テーブルを作成しました。';
END
ELSE
BEGIN
    PRINT 'Customers テーブルは既に存在します。';
END
GO

-- サンプルデータの投入
IF NOT EXISTS (SELECT * FROM dbo.Customers WHERE CustomerID = 123)
BEGIN
    INSERT INTO dbo.Customers
        (CustomerID, CustomerName, PhoneNumber, WebsiteURL,
         AddressLine1, AddressLine2, PostalCode)
    VALUES
        (123,
         N'Tailspin Toys (Roe Park, NY)',
         N'(212) 555-0100',
         N'http://www.tailspintoys.com/RoePark',
         N'Shop 219',
         N'528 Persson Road',
         N'90775');
    
    PRINT 'サンプルデータ (CustomerID: 123) を挿入しました。';
END
ELSE
BEGIN
    PRINT 'サンプルデータ (CustomerID: 123) は既に存在します。';
END
GO

-- 追加のサンプルデータ（オプション）
IF NOT EXISTS (SELECT * FROM dbo.Customers WHERE CustomerID = 124)
BEGIN
    INSERT INTO dbo.Customers
        (CustomerID, CustomerName, PhoneNumber, WebsiteURL,
         AddressLine1, AddressLine2, PostalCode)
    VALUES
        (124,
         N'Wingtip Toys (Seattle, WA)',
         N'(206) 555-0200',
         N'http://www.wingtiptoys.com',
         N'456 Main Street',
         N'Suite 100',
         N'98101');
    
    PRINT 'サンプルデータ (CustomerID: 124) を挿入しました。';
END
GO

-- ID 指定で顧客情報を取得するストアドプロシージャ
CREATE OR ALTER PROCEDURE dbo.GetCustomerById
    @CustomerID INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT
        c.CustomerID,
        c.CustomerName,
        c.PhoneNumber,
        c.WebsiteURL,
        c.AddressLine1,
        c.AddressLine2,
        c.PostalCode
    FROM dbo.Customers AS c
    WHERE c.CustomerID = @CustomerID
    FOR JSON PATH;
END
GO

PRINT 'ストアドプロシージャ GetCustomerById を作成しました。';
GO

-- すべての顧客情報を取得するストアドプロシージャ
CREATE OR ALTER PROCEDURE dbo.GetAllCustomers
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT
        c.CustomerID,
        c.CustomerName,
        c.PhoneNumber,
        c.WebsiteURL,
        c.AddressLine1,
        c.AddressLine2,
        c.PostalCode
    FROM dbo.Customers AS c
    ORDER BY c.CustomerID
    FOR JSON PATH;
END
GO

PRINT 'ストアドプロシージャ GetAllCustomers を作成しました。';
GO

-- 確認用: データを表示
SELECT 
    CustomerID,
    CustomerName,
    PhoneNumber
FROM dbo.Customers
ORDER BY CustomerID;
GO

PRINT 'セットアップが完了しました！';
PRINT '以下のストアドプロシージャが利用可能です:';
PRINT '  - dbo.GetCustomerById @CustomerID';
PRINT '  - dbo.GetAllCustomers';
GO
