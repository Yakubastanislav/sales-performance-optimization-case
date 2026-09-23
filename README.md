# sales-performance-optimization-case
An end-to-end Business Analysis &amp; BI project diagnosing a customer retention drop for Vertex Supply Co. Built with MySQL, Power BI, Excel and MS Visio.
1. Business Context & Problem

The Problem: Sales growth has decelerated to 2% YoY, and the customer repeat purchase rate (RPR) in key states (California and Texas) has dropped from 35% to 25% over the last 12 months.

The Goal: Identify the root causes of the decline (service quality, logistics, or product issues), build interactive reporting, and deliver an actionable customer retention strategy.

Technology Stack: MySQL, MS Excel (statistical analysis), MS Power BI, MS Visio.

2. Project Architecture & File Connections

1). Initiation & Requirements:
docs/Business Analysis Mandate.docx — Project charter, scope boundaries, and stakeholder map (influence/interest matrix).
docs/Requirements.docx — Functional requirements (FR-01 to FR-09), non-functional requirements (NFRs), and User Stories with acceptance criteria.

2). Process Modeling:
docs/As-Is.To-Be.vsdx — MS Visio process flows mapping the transition from manual complaint handling to an automated classification system with trigger-based MS Teams alerts.

3). Data Processing & Analytics:
sql/analysis.sql — SQL script for data cleaning (creating the stg.SalesClean view), YoY/MoM trend analysis, RFM segmentation, cohort retention, and Pareto analysis.
excel/Sales.Orders.Hipothesis.Risk.xlsx — Calculation model containing raw data, statistical hypothesis tests, the project risk matrix, and the User Acceptance Testing (UAT) tracker.

4). Visualization & Reporting:
pbi/PBI Report.pbix — Interactive Power BI dashboard enabling 3-click drill-downs from macro-level sales KPIs to individual customer complaints.
presentation/BA Presentation.pptx — Executive slide deck summarizing findings, insights, and strategic recommendations for the Sales Director.

