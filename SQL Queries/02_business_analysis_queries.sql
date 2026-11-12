USE OnlineRetail;
GO

-- 1. What is the overall gross and net revenue?
SELECT 
    ROUND(SUM(Sales), 2) AS GrossRevenue,
    ROUND(SUM(Sales) + (SELECT ISNULL(SUM(ReturnValue), 0) FROM CustomerReturns), 2) AS NetRevenueAfterReturns
FROM CleanedRetail;

-- 2. Which countries generate the most revenue?
SELECT TOP 10
    Country,
    ROUND(SUM(Sales), 2) AS TotalRevenue,
    COUNT(DISTINCT Invoice) AS TotalOrders
FROM CleanedRetail
GROUP BY Country
ORDER BY TotalRevenue DESC;

-- 3. Who are our best customers, and who is slipping away?
-- 3A. Segment-level summary (count and revenue per segment)
SELECT
    CustomerSegment,
    COUNT(CustomerID) AS CustomerCount,
    ROUND(SUM(Monetary), 2) AS TotalNetRevenue,
    ROUND(AVG(Recency), 0) AS AvgDaysSinceLastOrder
FROM RFMScored
GROUP BY CustomerSegment
ORDER BY TotalNetRevenue DESC;

-- 3B. Top 10 Best Customers by Net Spend
SELECT TOP 10
    CustomerID,
    Recency,
    Frequency,
    Monetary,
    CustomerSegment
FROM RFMScored
WHERE CustomerSegment = 'Best Customers'
ORDER BY Monetary DESC;

-- 3C. Top 10 High-Value Customers Slipping Away (Win-Back Priority)
SELECT TOP 10
    CustomerID,
    Recency,
    Frequency,
    Monetary,
    CustomerSegment
FROM RFMScored
WHERE CustomerSegment IN ('Cannot Lose Them', 'Slipping Away (At Risk)')
ORDER BY Monetary DESC;

-- 4. Are there seasonal patterns or growth over time?
SELECT
    FORMAT(InvoiceDate, 'yyyy-MM') AS SalesMonth,
    ROUND(SUM(Sales), 2) AS TotalRevenue,
    COUNT(DISTINCT Invoice) AS TotalOrders
FROM CleanedRetail
GROUP BY FORMAT(InvoiceDate, 'yyyy-MM')
ORDER BY SalesMonth;

-- 5. Which products are the best-sellers?
SELECT TOP 10
    StockCode,
    Description,
    SUM(Quantity) AS TotalUnitsSold,
    ROUND(SUM(Sales), 2) AS TotalRevenue
FROM CleanedRetail
GROUP BY StockCode, Description
ORDER BY TotalRevenue DESC;

-- 6. When do customers shop more? (By Hour of Day)
SELECT
    DATEPART(HOUR, InvoiceDate) AS HourOfDay,
    COUNT(DISTINCT Invoice) AS TotalOrders,
    ROUND(SUM(Sales), 2) AS TotalRevenue
FROM CleanedRetail
GROUP BY DATEPART(HOUR, InvoiceDate)
ORDER BY TotalOrders DESC;
