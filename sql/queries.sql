-- queries.sql | Ironhack Project 1 | World Bank, EU-27, 2019–2024
-- Purpose: SQL analyses for the four presentation research questions.
-- Tables: countries(country_code, country_name, region),
--         indicators(indicator_code, indicator_name, description, unit),
--         observations(country_code, indicator_code, year, value).

/* Research questions:
1. Which European countries recovered their pre-pandemic GDP levels by 2024? (Establish what happened to economic output after the pandemic and how recovery differed across countries.)
    Visualisation: indexed GDP line chart, with 2019 = 100.
2. Was higher inflation in 2022 associated with weaker GDP growth in 2023? (Move from the pandemic recovery to the subsequent inflation shock. Explore whether countries experiencing higher inflation subsequently recorded weaker economic growth.)
    Visualisation: scatter plot with correlation analysis
3. Was the reduction in inflation between 2022 and 2024 associated with rising unemployment? (Examine whether disinflation coincided with changes in labour-market conditions.)
    Visualization: scatter plot of inflation and unemployment changes, both in percentage points.
4. Did European economies become more similar or more divergent between 2019 and 2024? (Examine whether economic differences between countries widened during the two shocks and subsequently narrowed.)
     Visualization:annual cross-country dispersion of the three indicators.*/

	
/* -First, need to create GDP index with base 2019=100 as a baseline. The growth rate for 2020 updates the 2019 baseline, and so on through 2024
  - This is a VIEW: it does not replace or change the underlying observations.*/

PRAGMA foreign_keys = ON;

DROP VIEW IF EXISTS gdp_index_2019

CREATE VIEW gdp_index_2019 AS
WITH RECURSIVE gdp_series AS (
    SELECT
        country_code,
        2019 AS year,
        100.0 AS gdp_index
    FROM countries

    UNION ALL

    SELECT
        g.country_code,
        g.year + 1,
        CASE
            WHEN g.gdp_index IS NULL OR o.value IS NULL
                THEN NULL
            ELSE g.gdp_index * (1 + o.value / 100.0)
        END
    FROM gdp_series AS g
    LEFT JOIN observations AS o
        ON g.country_code = o.country_code
        AND o.indicator_code = 'NY.GDP.MKTP.KD.ZG'
        AND o.year = g.year + 1
    WHERE g.year < 2024
)
SELECT
    c.country_name,
    g.country_code,
    g.year,
    g.gdp_index
FROM gdp_series AS g
JOIN countries AS c
    ON g.country_code = c.country_code;

/*Query 1: Which European countries recovered their pre-pandemic GDP levels by 2024? 
 - Methodology: I listed each country's reconstructed real GDP index in every year from 2019 through 2024.
 - Findings: a) Spain recorded the largest contraction, with a GDP index of 89.06 in 2020, followed by Greece (90.80) and Italy (91.13).
			b) By 2024, all but one country had returned to, or exceeded their 2019 GDP levels. Finland was the only exception, with an index of 99.95.
			c) Recovery trajectories differed substantially. Ireland recorded the highest 2024 GDP index (133.93), followed by Malta (131.92) and Cyprus (126.26).
			d) Germany's GDP index stood at just 100.04 in 2024, indicating almost no growth.
*/
  -- QUERY 1: GDP recovery trajectories
Select 
	country_name,
	year,
	ROUND(gdp_index, 2) AS gdp_index
FROM gdp_index_2019
ORDER BY country_name, year = 2024;


/* QUERY 2: Recovery status and first recovery year.
 - Methodology: Classified countries by whether their 2024 GDP index reached their 2019 GDP level. As most countries (not all) experienced a decline in 2020,
                it finds the first year from 2021 through 2024 in which they reached the baseline. (A country may reach 100 and subsequently fall below it again.)
 - Findings: a)  2 countries (Ireland and Lithuania) did not experience economic contraction in 2020
			b)  Of the 25 countries that experienced a GDP contraction in 2020, 17 had already returned to their pre-pandemic GDP levels in 2021. The remaining eight first recovered in 2022.
			c)  It sems that The depth of the pandemic contraction did not determine recovery speed. Croatia contracted 8.31% in 2020, but recovered the next year
				While Finland experienced a smaller contraction of 2.49% and initially recovered in 2021, but subsequently fell below its 2019 level.
				Germany recovered in 2022, but but ended 2024 at just 100.04
-- Limitation: GDP indices measure changes in aggregate real output relative to 2019, not GDP per capita or changes in living standards.
*/
-- QUERY 2: Recovery status
WITH recovery AS (
    SELECT
        country_name,
        MAX(CASE WHEN year = 2020
            THEN gdp_index END) AS gdp_2020,
        MAX(CASE WHEN year = 2024
            THEN gdp_index END) AS gdp_2024,
        MIN(CASE
            WHEN year BETWEEN 2021 AND 2024
                 AND gdp_index >= 100
            THEN year
        END) AS first_year_at_baseline
    FROM gdp_index_2019
    GROUP BY country_name
)
SELECT
    country_name,
    ROUND(gdp_2020, 2) AS gdp_2020,
    ROUND(gdp_2024, 2) AS gdp_2024,
    CASE
        WHEN gdp_2024 IS NULL THEN 'Incomplete data'
        WHEN gdp_2020 >= 100
            THEN 'No contraction in 2020'
        WHEN gdp_2024 >= 100
            THEN 'Recovered by 2024'
        ELSE 'Below 2019 level in 2024'
    END AS recovery_status,
    CASE
        WHEN gdp_2020 < 100
        THEN first_year_at_baseline
    END AS first_recovery_year
FROM recovery
ORDER BY gdp_2024 DESC;

/* QUERY 3 -- Research question 2: Inflation in 2022 and GDP growth in 2023
 - Methodology: compare 2022 inflation with growth in 2023
 - Findings: a) There seems to be an apparent negative relationship between inflation in 2022 and GDP growth in 2023.
			Needs a bivariate comparison (Pearson and/or Spearman correlation) to identify if there is statistical correlation.
			b) Countries with similar inflation rates experienced substantially different economic outcomes: Estonia recorded 19.40% inflation and -2.74% GDP
			growth, while Lithuania recorded 19.71% inflation and positive GDP growth of 0.74%.
- Limitation: This is a cross-country correlation analysis. It does not establish that inflation caused subsequent changes in economic growth.
*/
-- QUERY 3: Inflation and GDP growth
SELECT
    c.country_name,
    inf.value AS inflation_2022,
    gdp.value AS gdp_growth_2023
FROM observations AS inf
JOIN observations AS gdp
    ON inf.country_code = gdp.country_code
JOIN countries AS c
    ON inf.country_code = c.country_code
WHERE inf.indicator_code = 'FP.CPI.TOTL.ZG'
    AND inf.year = 2022
    AND gdp.indicator_code = 'NY.GDP.MKTP.KD.ZG'
    AND gdp.year = 2023
    AND inf.value IS NOT NULL
    AND gdp.value IS NOT NULL
ORDER BY inflation_2022 DESC;


/*QUERY 4 -- Research question 2: Comparing subsequent growth in high and low inflation countries (supplement comparison)
	- Methodology: Split the exact sample used in Query 3 by the unweighted mean 2022 inflation, then computes group averages.
	- Findings: a) The ten countries with above-average inflation in 2022 recorded average GDP growth of 0.63% in 2023. The other 17 countries recorded 1.33%.
				difference of GDP 0.70% points, while the inflation difference was 7.38% on average
				b) Countries with lower inflation initially appear to have experienced stronger subsequent growth.
	- Limitations: a) look for outliers countries to see if any affect the unwheighted mean of the sample
					b) according to Query 3, there seems to be no causation between inflation and economic growth.
	*/
-- QUERY 4: GDP growth by inflation group
WITH paired AS (
    SELECT
        inf.country_code,
        inf.value AS inflation_2022,
        gdp.value AS gdp_growth_2023
    FROM observations AS inf
    JOIN observations AS gdp
        ON inf.country_code = gdp.country_code
    WHERE inf.indicator_code = 'FP.CPI.TOTL.ZG'
        AND inf.year = 2022
        AND gdp.indicator_code = 'NY.GDP.MKTP.KD.ZG'
        AND gdp.year = 2023
        AND inf.value IS NOT NULL
        AND gdp.value IS NOT NULL
),
classified AS (
    SELECT
        *,
        CASE
            WHEN inflation_2022 > (
                SELECT AVG(inflation_2022)
                FROM paired
            )
            THEN 'Above-average inflation'
            ELSE 'At or below-average inflation'
        END AS inflation_group
    FROM paired
)
SELECT
    inflation_group,
    COUNT(*) AS country_count,
    ROUND(AVG(inflation_2022), 2) AS avg_inflation,
    ROUND(AVG(gdp_growth_2023), 2) AS avg_gdp_growth
FROM classified
GROUP BY inflation_group
HAVING COUNT(*) >= 2;

/*QUERY 5 -- Research Question 3: Disinflation and unemployment: Was the reduction in inflation between 2022 and 2024 associated with rising unemployment?
	- Methodology: Calculated the change in inflation and the change in unemployment for the same country between 2022 and 2024. Both in percentage points. 
	Includes all countries in pairs.
	- Findings: a) Inflation declined in all 27 countries. However, unemployment increased in 16 countries and decreased in 10 countries. Poland only did not experience change in unemployment
				b) Lithuania experienced the largest reduction in inflation (-18.99%), accompanied by a 0.90% increase in unemployment.
				c) Estonia recorded the largest increase in unemployment (+2.03%), while Greece recorded the largest decrease (-2.41%).
	- Limitations: a) Need to perform bivariate analysis (Pearson and Spearman) to see if there is siginificant statistical analysis
					b)Cross-country correlations do not establish causation or isolate the effects of monetary policy and other economic developments.
*/
-- QUERY 5: Inflation and unemployment
SELECT
    c.country_name,
    ROUND(i24.value - i22.value, 2)
        AS inflation_change_pp,
    ROUND(u24.value - u22.value, 2)
        AS unemployment_change_pp
FROM countries AS c
JOIN observations AS i22
    ON c.country_code = i22.country_code
JOIN observations AS i24
    ON c.country_code = i24.country_code
JOIN observations AS u22
    ON c.country_code = u22.country_code
JOIN observations AS u24
    ON c.country_code = u24.country_code
WHERE i22.indicator_code = 'FP.CPI.TOTL.ZG'
    AND i22.year = 2022
    AND i24.indicator_code = 'FP.CPI.TOTL.ZG'
    AND i24.year = 2024
    AND u22.indicator_code = 'SL.UEM.TOTL.ZS'
    AND u22.year = 2022
    AND u24.indicator_code = 'SL.UEM.TOTL.ZS'
    AND u24.year = 2024
    AND i22.value IS NOT NULL
    AND i24.value IS NOT NULL
    AND u22.value IS NOT NULL
    AND u24.value IS NOT NULL
ORDER BY inflation_change_pp;

/* Query 6 -- Research question 4: Did European economies become more similar or more divergent between 2019 and 2024?
	Methodology: For each indicator and year, I calculated the country count, unweighted country mean, range, and sample variance. 
				For each INDICATOR, I used only countries with a non-NULL observations, so the composition of that indicator's sample is constant across the chart.
				Different indicators may have different complete-country samples.
	Further analysis : In pandas, need to take sqrt(sample_variance) to get standard deviation. Then plot each indicator separately. This tests dispersion of economic rates,
						not convergence of GDP levels or living standards.
	Findings: a) GDP growth dispersion increased sharply during the COVID-19 shock. Sample variance rose from 1.99 in 2019 to 12.63 in 2020, while the range increased from 5.45 to 18.09%.
			  b) GDP-growth dispersion subsequently declined, reaching a variance of 2.61 in 2024. This was close to, although still above, the 2019 level.
			  c) Inflation showed an even stronger temporary divergence. Variance increased from 1.00 in 2019 to 16.93 in 2022, during the inflation shock. 
			  By 2024 it had fallen to 1.07, almost returning to its pre-shock level.
			  d)Unemployment followed a different pattern: Its variance declined steadily from 10.67 in 2019 to 4.70 in 2024, a reduction of about 56%.
			  The unemployment range also fell from 15.03 to 8.80 percentage points.
			  -- Limitation: Dispersion in annual GDP growth, inflation and unemployment does not measure convergence in GDP levels, income or living standards.
*/
-- QUERY 6: Economic dispersion
WITH complete_countries AS (
    SELECT
        country_code,
        indicator_code
    FROM observations
    WHERE year BETWEEN 2019 AND 2024
        AND value IS NOT NULL
    GROUP BY country_code, indicator_code
    HAVING COUNT(DISTINCT year) = 6
),
annual_stats AS (
    SELECT
        o.indicator_code,
        o.year,
        COUNT(*) AS country_count,
        AVG(o.value) AS mean_value,
        MIN(o.value) AS min_value,
        MAX(o.value) AS max_value,
        SUM(o.value) AS total,
        SUM(o.value * o.value) AS sum_squares
    FROM observations AS o
    JOIN complete_countries AS cc
        ON o.country_code = cc.country_code
        AND o.indicator_code = cc.indicator_code
    WHERE o.year BETWEEN 2019 AND 2024
    GROUP BY o.indicator_code, o.year
    HAVING COUNT(*) >= 2
)
SELECT
    i.indicator_name,
    a.year,
    a.country_count,
    ROUND(a.mean_value, 2) AS mean_value,
    ROUND(a.max_value - a.min_value, 2) AS range_pp,
    ROUND(        (a.sum_squares - a.total * a.total / a.country_count) / (a.country_count - 1), 4) 
		AS sample_variance
FROM annual_stats AS a
JOIN indicators AS i
    ON a.indicator_code = i.indicator_code
ORDER BY i.indicator_name, a.year;
	