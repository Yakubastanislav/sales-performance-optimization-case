select * from sales_raw

CREATE OR REPLACE VIEW stg.SalesClean AS
SELECT
    OrderID,
    STR_TO_DATE(OrderDate, '%m/%d/%Y')                              AS OrderDate,
    Region,
    Channel,
    ProductCategory,
    ProductName,
    CAST(
        REPLACE(REPLACE(REPLACE(SalesAmount, '$', ''), ' ', ''), ',', '.')
        AS DECIMAL(18,2)
    )                                                                AS SalesAmount,
    CAST(
        REPLACE(REPLACE(REPLACE(CostAmount, '$', ''), ' ', ''), ',', '.')
        AS DECIMAL(18,2)
    )                                                                AS CostAmount,
    CAST(Quantity AS SIGNED)                                         AS Quantity,
    CustomerID,
    CustomerType,
    CAST(IsRepeatPurchase AS UNSIGNED)                               AS IsRepeatPurchase,
    TransactionType,
    CASE
        WHEN STR_TO_DATE(OrderDate, '%m/%d/%Y') BETWEEN '2024-08-01' AND '2025-07-31' THEN 'PY'
        WHEN STR_TO_DATE(OrderDate, '%m/%d/%Y') BETWEEN '2025-08-01' AND '2026-07-31' THEN 'CY'
        ELSE 'Other'
    END                                                              AS FiscalYear
FROM sales_raw
WHERE STR_TO_DATE(OrderDate, '%m/%d/%Y') IS NOT NULL;

SELECT * FROM stg.SalesClean

`GENERAL OVERVIEW`

SELECT
    COUNT(*)                                  AS TotalRows,
    COUNT(DISTINCT OrderID)                   AS UniqueOrders,
    COUNT(DISTINCT CustomerID)                AS UniqueCustomers,
    MIN(OrderDate)                            AS MinDate,
    MAX(OrderDate)                            AS MaxDate,
    ROUND(SUM(SalesAmount), 2)                AS TotalSales,
    ROUND(SUM(CostAmount), 2)                 AS TotalCost,
    ROUND(SUM(SalesAmount - CostAmount), 2)   AS GrossProfit,
    ROUND(
        SUM(SalesAmount - CostAmount) * 100.0 / NULLIF(SUM(SalesAmount), 0)
    , 2)                                      AS GrossMarginPct,
    ROUND(AVG(IsRepeatPurchase) * 100, 2)     AS RepeatRatePct,
    ROUND(SUM(TransactionType='Return') * 100.0 / COUNT(*), 2) AS ReturnRatePct
FROM stg.SalesClean;

`PY vs CY`

SELECT
    ROUND(MAX(CASE WHEN FiscalYear='PY' THEN Sales END), 2)        AS PY_Sales,
    ROUND(MAX(CASE WHEN FiscalYear='CY' THEN Sales END), 2)        AS CY_Sales,
    ROUND(
        (MAX(CASE WHEN FiscalYear='CY' THEN Sales END) -
         MAX(CASE WHEN FiscalYear='PY' THEN Sales END))
        / NULLIF(MAX(CASE WHEN FiscalYear='PY' THEN Sales END), 0) * 100
    , 2)                                                           AS Sales_YoY_Pct,
    ROUND(MAX(CASE WHEN FiscalYear='PY' THEN GP END), 2)           AS PY_GrossProfit,
    ROUND(MAX(CASE WHEN FiscalYear='CY' THEN GP END), 2)           AS CY_GrossProfit,
    ROUND(MAX(CASE WHEN FiscalYear='PY' THEN Margin END), 2)       AS PY_Margin_Pct,
    ROUND(MAX(CASE WHEN FiscalYear='CY' THEN Margin END), 2)       AS CY_Margin_Pct
FROM (
    SELECT
        FiscalYear,
        SUM(SalesAmount) AS Sales,
        SUM(SalesAmount - CostAmount) AS GP,
        SUM(SalesAmount - CostAmount) * 100.0 / NULLIF(SUM(SalesAmount), 0) AS Margin
    FROM stg.SalesClean
    WHERE FiscalYear IN ('PY','CY')
    GROUP BY FiscalYear
) t;

`RPR PY vs CY`

SELECT
    Region,
    ROUND(AVG(CASE WHEN FiscalYear='PY' THEN IsRepeatPurchase END) * 100, 2) AS PY_RepeatPct,
    ROUND(AVG(CASE WHEN FiscalYear='CY' THEN IsRepeatPurchase END) * 100, 2) AS CY_RepeatPct,
    ROUND(
        AVG(CASE WHEN FiscalYear='CY' THEN IsRepeatPurchase END) * 100
      - AVG(CASE WHEN FiscalYear='PY' THEN IsRepeatPurchase END) * 100
    , 2) AS Delta_PP
FROM stg.SalesClean
WHERE FiscalYear IN ('PY','CY')
GROUP BY Region
ORDER BY Delta_PP ASC;

`AOV T.TEST(excel)`

SELECT
    Channel,
    COUNT(*)                          AS N,
    ROUND(AVG(SalesAmount), 2)        AS Mean_AOV,
    ROUND(STDDEV(SalesAmount), 2)     AS StdDev_AOV
FROM stg.SalesClean
WHERE TransactionType = 'Sale'
  AND Channel IN ('Online','Direct')
GROUP BY Channel;

`YoY`

WITH monthly AS (
    SELECT
        MONTH(OrderDate)  AS MonthNum,
        MONTHNAME(OrderDate) AS MonthName,
        FiscalYear,
        SUM(SalesAmount)  AS Sales
    FROM stg.SalesClean
    WHERE FiscalYear IN ('PY','CY')
    GROUP BY MONTH(OrderDate), MONTHNAME(OrderDate), FiscalYear
)
SELECT
    MonthNum,
    MonthName,
    ROUND(MAX(CASE WHEN FiscalYear='PY' THEN Sales END), 2) AS PY_Sales,
    ROUND(MAX(CASE WHEN FiscalYear='CY' THEN Sales END), 2) AS CY_Sales,
    ROUND(
        (MAX(CASE WHEN FiscalYear='CY' THEN Sales END) -
         MAX(CASE WHEN FiscalYear='PY' THEN Sales END))
        / NULLIF(MAX(CASE WHEN FiscalYear='PY' THEN Sales END), 0) * 100
    , 2) AS YoY_Pct
FROM monthly
GROUP BY MonthNum, MonthName
ORDER BY MonthNum;

`RUNNING TOTAL, MOM`

WITH monthly AS (
    SELECT
        STR_TO_DATE(CONCAT(YEAR(OrderDate),'-',LPAD(MONTH(OrderDate),2,'0'),'-01'), '%Y-%m-%d') AS MonthStart,
        SUM(SalesAmount) AS Sales
    FROM stg.SalesClean
    GROUP BY STR_TO_DATE(CONCAT(YEAR(OrderDate),'-',LPAD(MONTH(OrderDate),2,'0'),'-01'), '%Y-%m-%d')
)
SELECT
    MonthStart,
    ROUND(Sales, 2) AS Sales,
    ROUND(SUM(Sales) OVER (ORDER BY MonthStart), 2) AS RunningTotal,
    ROUND(AVG(Sales) OVER (
        ORDER BY MonthStart
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS MovingAvg_3M,
    ROUND(LAG(Sales) OVER (ORDER BY MonthStart), 2) AS PrevMonth,
    ROUND(
        (Sales - LAG(Sales) OVER (ORDER BY MonthStart))
        / NULLIF(LAG(Sales) OVER (ORDER BY MonthStart), 0) * 100
    , 2) AS MoM_Pct
FROM monthly
ORDER BY MonthStart;

`TOP 3 FOR EACH REGION`

WITH ranked AS (
    SELECT
        Region,
        ProductName,
        SUM(SalesAmount) AS Sales,
        ROW_NUMBER() OVER (
            PARTITION BY Region
            ORDER BY SUM(SalesAmount) DESC
        ) AS rn
    FROM stg.SalesClean
    WHERE TransactionType = 'Sale'
    GROUP BY Region, ProductName
)
SELECT Region, rn, ProductName, ROUND(Sales, 2) AS Sales
FROM ranked
WHERE rn <= 3
ORDER BY Region, rn;

`GROSS MARGIN`

SELECT
    ProductCategory,
    COUNT(*)                                              AS Transactions,
    ROUND(SUM(SalesAmount), 2)                            AS Sales,
    ROUND(SUM(SalesAmount - CostAmount), 2)               AS GrossProfit,
    ROUND(
        SUM(SalesAmount - CostAmount) * 100.0
        / NULLIF(SUM(SalesAmount), 0)
    , 2)                                                  AS Margin_Pct,
    ROUND(
        SUM(TransactionType='Return') * 100.0 / COUNT(*)
    , 2)                                                  AS Return_Rate_Pct
FROM stg.SalesClean
GROUP BY ProductCategory
ORDER BY Sales DESC;

`RFM-segmentation`

WITH customer_agg AS (
    SELECT
        CustomerID,
        MAX(OrderDate)          AS LastOrderDate,
        COUNT(DISTINCT OrderID) AS Frequency,
        SUM(SalesAmount)        AS Monetary
    FROM stg.SalesClean
    WHERE TransactionType = 'Sale'
    GROUP BY CustomerID
),
rfm AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY LastOrderDate DESC) AS R_Score,
        NTILE(5) OVER (ORDER BY Frequency DESC)     AS F_Score,
        NTILE(5) OVER (ORDER BY Monetary DESC)      AS M_Score
    FROM customer_agg
)
SELECT
    CustomerID,
    LastOrderDate,
    Frequency,
    ROUND(Monetary, 2) AS Monetary,
    R_Score, F_Score, M_Score,
    CASE
        WHEN R_Score >= 4 AND F_Score >= 4 AND M_Score >= 4 THEN 'Champions'
        WHEN R_Score >= 3 AND F_Score >= 3                  THEN 'Loyal'
        WHEN R_Score <= 2 AND F_Score >= 3                  THEN 'At Risk'
        WHEN R_Score <= 2 AND F_Score <= 2                  THEN 'Lost'
        ELSE 'Others'
    END AS Segment
FROM rfm
ORDER BY Monetary DESC;

WITH customer_agg AS (
    SELECT
        CustomerID,
        MAX(OrderDate)          AS LastOrderDate,
        COUNT(DISTINCT OrderID) AS Frequency,
        SUM(SalesAmount)        AS Monetary
    FROM stg.SalesClean
    WHERE TransactionType = 'Sale'
    GROUP BY CustomerID
),
rfm AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY LastOrderDate DESC) AS R_Score,
        NTILE(5) OVER (ORDER BY Frequency DESC)     AS F_Score,
        NTILE(5) OVER (ORDER BY Monetary DESC)      AS M_Score
    FROM customer_agg
),
segmented AS (
    SELECT *,
        CASE
            WHEN R_Score >= 4 AND F_Score >= 4 AND M_Score >= 4 THEN 'Champions'
            WHEN R_Score >= 3 AND F_Score >= 3                  THEN 'Loyal'
            WHEN R_Score <= 2 AND F_Score >= 3                  THEN 'At Risk'
            WHEN R_Score <= 2 AND F_Score <= 2                  THEN 'Lost'
            ELSE 'Others'
        END AS Segment
    FROM rfm
)
SELECT
    Segment,
    COUNT(*)                          AS Customers,
    ROUND(SUM(Monetary), 2)           AS TotalRevenue,
    ROUND(AVG(Monetary), 2)           AS AvgRevenuePerCustomer,
    ROUND(SUM(Monetary) * 100.0 / SUM(SUM(Monetary)) OVER (), 2) AS PctOfRevenue
FROM segmented
GROUP BY Segment
ORDER BY TotalRevenue DESC;

`COHORT retention`

WITH first_order AS (
    SELECT
        CustomerID,
        MIN(STR_TO_DATE(CONCAT(YEAR(OrderDate),'-',LPAD(MONTH(OrderDate),2,'0'),'-01'), '%Y-%m-%d')) AS CohortMonth
    FROM stg.SalesClean
    GROUP BY CustomerID
),
orders_with_cohort AS (
    SELECT
        s.CustomerID,
        fo.CohortMonth,
        STR_TO_DATE(CONCAT(YEAR(s.OrderDate),'-',LPAD(MONTH(s.OrderDate),2,'0'),'-01'), '%Y-%m-%d') AS OrderMonth
    FROM stg.SalesClean s
    JOIN first_order fo ON fo.CustomerID = s.CustomerID
)
SELECT
    CohortMonth,
    TIMESTAMPDIFF(MONTH, CohortMonth, OrderMonth) AS MonthOffset,
    COUNT(DISTINCT CustomerID) AS ActiveCustomers
FROM orders_with_cohort
GROUP BY CohortMonth, TIMESTAMPDIFF(MONTH, CohortMonth, OrderMonth)
ORDER BY CohortMonth, MonthOffset;

`PARETO`

WITH customer_sales AS (
    SELECT CustomerID, SUM(SalesAmount) AS Sales
    FROM stg.SalesClean
    WHERE TransactionType = 'Sale'
    GROUP BY CustomerID
),
ranked AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY Sales DESC) AS Quintile
    FROM customer_sales
)
SELECT
    Quintile,
    COUNT(*) AS Customers,
    ROUND(SUM(Sales), 2) AS TotalSales,
    ROUND(SUM(Sales) * 100.0 / SUM(SUM(Sales)) OVER (), 2) AS PctOfTotal
FROM ranked
GROUP BY Quintile
ORDER BY Quintile;

`REGIONS`

SELECT
    Region,
    SUM(TransactionType='Return') AS Returns,
    ROUND(SUM(TransactionType='Return') * 100.0 / COUNT(*), 2) AS ReturnRatePct
FROM stg.SalesClean
GROUP BY Region
ORDER BY ReturnRatePct DESC;

`CATEGORIES`

SELECT
    ProductCategory,
    SUM(TransactionType='Return') AS Returns,
    ROUND(SUM(TransactionType='Return') * 100.0 / COUNT(*), 2) AS ReturnRatePct,
    ROUND(SUM(CASE WHEN TransactionType='Return' THEN SalesAmount END), 2) AS ReturnedAmount
FROM stg.SalesClean
GROUP BY ProductCategory
ORDER BY ReturnRatePct DESC;