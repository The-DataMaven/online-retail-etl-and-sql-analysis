USE OnlineRetail;
GO

/* ============================================================================
   1. CLEANED RETAIL VIEW
   - Combines 2009–2010 and 2010–2011 tables without overlapping Dec 2010 dates
   - Standardizes country names and removes cancellations and invalid entries
   ============================================================================ */
CREATE OR ALTER VIEW CleanedRetail AS
WITH CombinedRetail AS (
    SELECT
        [Invoice],
        [StockCode],
        [Description],
        TRY_CAST([Quantity] AS INT) AS Quantity,
        [InvoiceDate],
        TRY_CAST([Price] AS FLOAT) AS Price,
        [Customer ID] AS CustomerID,
        [Country]
    FROM [OnlineRetail].[dbo].[Year 2009_2010]
    WHERE [InvoiceDate] < '20101201'

    UNION ALL

    SELECT
        [Invoice],
        [StockCode],
        [Description],
        TRY_CAST([Quantity] AS INT) AS Quantity,
        [InvoiceDate],
        TRY_CAST([Price] AS FLOAT) AS Price,
        [Customer ID] AS CustomerID,
        [Country]
    FROM [OnlineRetail].[dbo].[year 2010_2011]
)
SELECT
    [Invoice],
    [StockCode],
    [Description],
    Quantity,
    [InvoiceDate],
    Price,
    CustomerID,
    CASE 
        WHEN [Country] = 'RSA' THEN 'South Africa'
        WHEN [Country] = 'EIRE' THEN 'Ireland'
        WHEN [Country] = 'USA' THEN 'United States'
        ELSE [Country]
    END AS Country,
    Quantity * Price AS Sales
FROM CombinedRetail
WHERE
    [Invoice] NOT LIKE 'C%'
    AND Quantity > 0
    AND Price > 0;
GO

/* ============================================================================
   2. CUSTOMER RETURNS VIEW
   - Captures cancelled invoices ('C%') per customer to calculate net spend
   ============================================================================ */
CREATE OR ALTER VIEW CustomerReturns AS
WITH Cancelled AS (
    SELECT
        [Invoice],
        TRY_CAST([Quantity] AS INT) AS Quantity,
        [InvoiceDate],
        TRY_CAST([Price] AS FLOAT) AS Price,
        [Customer ID] AS CustomerID
    FROM [OnlineRetail].[dbo].[Year 2009_2010]
    WHERE [InvoiceDate] < '20101201'

    UNION ALL

    SELECT
        [Invoice],
        TRY_CAST([Quantity] AS INT) AS Quantity,
        [InvoiceDate],
        TRY_CAST([Price] AS FLOAT) AS Price,
        [Customer ID] AS CustomerID
    FROM [OnlineRetail].[dbo].[year 2010_2011]
)
SELECT
    CustomerID,
    SUM(Quantity * Price) AS ReturnValue
FROM Cancelled
WHERE
    [Invoice] LIKE 'C%'
    AND CustomerID IS NOT NULL
    AND LTRIM(RTRIM(CustomerID)) <> ''
GROUP BY CustomerID;
GO

/* ============================================================================
   3. RFM BASE METRICS VIEW
   - Computes Recency (anchored to 2011-12-10), Frequency, and Net Monetary
   ============================================================================ */
CREATE OR ALTER VIEW RFM AS
WITH CustomerSales AS (
    SELECT
        CustomerID,
        DATEDIFF(DAY, MAX(InvoiceDate), '20111210') AS Recency,
        COUNT(DISTINCT Invoice) AS Frequency,
        SUM(Sales) AS TotalSales
    FROM CleanedRetail
    WHERE CustomerID IS NOT NULL
      AND LTRIM(RTRIM(CustomerID)) <> ''
    GROUP BY CustomerID
)
SELECT
    cs.CustomerID,
    cs.Recency,
    cs.Frequency,
    ROUND(cs.TotalSales + ISNULL(cr.ReturnValue, 0), 2) AS Monetary
FROM CustomerSales cs
LEFT JOIN CustomerReturns cr
    ON cs.CustomerID = cr.CustomerID;
GO

/* ============================================================================
   4. RFM SCORING & SEGMENTATION TABLE
   - Scores customers into quintiles (1–5) and saves final segments to RFMScored
   ============================================================================ */
DROP TABLE IF EXISTS RFMScored;

WITH RFMScores AS (
    SELECT
        CustomerID,
        Recency,
        Frequency,
        Monetary,
        NTILE(5) OVER (ORDER BY Recency DESC) AS R_Score,
        NTILE(5) OVER (ORDER BY Frequency ASC) AS F_Score,
        NTILE(5) OVER (ORDER BY Monetary ASC) AS M_Score
    FROM RFM
)
SELECT
    CustomerID,
    Recency,
    Frequency,
    Monetary,
    R_Score,
    F_Score,
    M_Score,
    CASE
        WHEN R_Score >= 4 AND F_Score >= 4 AND M_Score >= 4 THEN 'Best Customers'
        WHEN R_Score >= 3 AND F_Score >= 3 AND M_Score >= 3 THEN 'Loyal Customers'
        WHEN R_Score = 1 AND F_Score >= 4 AND M_Score >= 4 THEN 'Cannot Lose Them'
        WHEN R_Score <= 2 AND F_Score >= 3 AND M_Score >= 3 THEN 'Slipping Away (At Risk)'
        WHEN R_Score >= 4 AND F_Score <= 2 THEN 'New Customers'
        ELSE 'Needs Attention / Hibernating'
    END AS CustomerSegment
INTO RFMScored
FROM RFMScores;
GO
