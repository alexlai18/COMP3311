-- COMP3311 22T3 Assignment 1
--
-- Fill in the gaps ("...") below with your code
-- You can add any auxiliary views/function that you like
-- The code in this file *MUST* load into an empty database in one pass
-- It will be tested as follows:
-- createdb test; psql test -f ass1.dump; psql test -f ass1.sql
-- Make sure it can load without error under these conditions


-- Q1: new breweries in Sydney in 2020

create or replace view Q1(brewery,suburb)
as
	SELECT b.NAME as brewery, l.TOWN as suburb
	FROM BREWERIES b
		JOIN LOCATIONS l on (l.ID = b.LOCATED_IN)
	WHERE b.FOUNDED = 2020 AND l.METRO = 'Sydney'
;

-- Q2: beers whose name is same as their style

create or replace view Q2(beer,brewery)
as
	SELECT br.NAME as beer, brw.NAME as brewery
	FROM STYLES s, BREWED_BY bby
		JOIN BEERS br on (br.ID = bby.BEER)
		JOIN BREWERIES brw on (brw.ID = bby.BREWERY)
	WHERE br.STYLE = s.ID AND s.NAME = br.NAME
;

-- Q3: original Californian craft brewery
create or replace view california(brewery, founded)
as
	SELECT DISTINCT brw.NAME as brewery, brw.FOUNDED as founded
	FROM BREWERIES brw
		JOIN LOCATIONS l on (l.ID = brw.LOCATED_IN)
	WHERE l.region = 'California'
	ORDER BY brw.FOUNDED
;

create or replace view Q3(brewery,founded)
as
	SELECT DISTINCT c.BREWERY as brewery, c.FOUNDED as founded
	FROM CALIFORNIA c
	WHERE c.FOUNDED = (SELECT MIN(FOUNDED) FROM CALIFORNIA)
;

-- Q4: all IPA variations, and how many times each occurs

create or replace view Q4(style,count)
as
	SELECT DISTINCT s.NAME as style, COUNT(s.NAME) as count
	FROM BEERS br
		JOIN STYLES s on (s.ID = br.STYLE)
	WHERE br.STYLE = s.ID AND s.NAME LIKE '%IPA%'
	GROUP BY 1
	ORDER BY STYLE
;

-- Q5: all Californian breweries, showing precise location

create or replace view Q5(brewery,location)
as
	SELECT DISTINCT brw.NAME as brewery, l.TOWN as location
		FROM BREWERIES brw
		JOIN LOCATIONS l ON (brw.LOCATED_IN = l.ID)
		WHERE l.REGION = 'California' AND l.TOWN IS NOT NULL
	UNION
	SELECT DISTINCT brw.NAME, l.METRO
		FROM BREWERIES brw
		JOIN LOCATIONS l ON (brw.LOCATED_IN = l.ID)
		WHERE l.REGION = 'California' AND l.TOWN IS NULL AND l.METRO IS NOT NULL
	ORDER BY BREWERY
;

-- Q6: strongest barrel-aged beer

create or replace view abv_list(abv)
as 
	SELECT DISTINCT br.ABV
		FROM BREWED_BY bby
			JOIN BEERS br on (br.ID = bby.BEER)
			JOIN BREWERIES brw on (brw.ID = bby.BREWERY)
		WHERE (br.NOTES LIKE '%barrel%' OR br.NOTES LIKE '%aged%')
		GROUP BY br.ABV
;


create or replace view Q6(beer,brewery,abv)
as
	SELECT DISTINCT br.NAME as beer, brw.NAME as brewery, br.ABV as abv
	FROM BREWED_BY bby
		JOIN BEERS br on (br.ID = bby.BEER)
		JOIN BREWERIES brw on (brw.ID = bby.BREWERY)
	WHERE br.ABV IN (SELECT MAX(ABV) FROM ABV_LIST)
;


-- Q7: most popular hop

create or replace view Q7(hop)
as
	SELECT DISTINCT i.NAME AS hop
	FROM CONTAINS c
		JOIN BEERS br on (br.ID = c.BEER)
		JOIN INGREDIENTS i on (i.ID = c.INGREDIENT)
	WHERE i.NAME IN
		(SELECT i.NAME
		FROM CONTAINS c
			JOIN BEERS br on (br.ID = c.BEER)
			JOIN INGREDIENTS i on (i.ID = c.INGREDIENT)
		WHERE i.ITYPE = 'hop'
		GROUP BY i.NAME
		ORDER BY COUNT(i.NAME) DESC
		LIMIT 1
		)
;

-- Q8: breweries that don't make IPA or Lager or Stout (any variation thereof)

create or replace view Q8(brewery)
as
	SELECT DISTINCT brw.NAME as brewery
	FROM BREWERIES brw
	EXCEPT
		(SELECT DISTINCT brw2.NAME
		FROM STYLES s, BREWED_BY bby
			JOIN BEERS br ON (br.ID = bby.BEER)
			JOIN BREWERIES brw2 ON (brw2.ID = bby.BREWERY)
		WHERE br.STYLE = s.ID AND (s.NAME LIKE '%IPA%'
									OR s.NAME LIKE '%Lager%' 
									OR s.NAME LIKE '%Stout%'))
	ORDER BY BREWERY
;

-- Q9: most commonly used grain in Hazy IPAs

create or replace view grain_mode(count)
as
	SELECT COUNT(i.NAME) as count
	FROM STYLES s
		JOIN BEERS br ON (br.STYLE = s.ID)
		JOIN CONTAINS c ON (c.BEER = br.ID)
		JOIN INGREDIENTS i on (i.ID = c.INGREDIENT)
	WHERE s.NAME LIKE 'Hazy IPA' AND i.ITYPE = 'grain'
	GROUP BY i.NAME
	ORDER BY COUNT(*) DESC
	LIMIT 1
;

create or replace view Q9(grain)
as
	SELECT i.NAME as grain
	FROM STYLES s
		JOIN BEERS br ON (br.STYLE = s.ID)
		JOIN CONTAINS c ON (c.BEER = br.ID)
		JOIN INGREDIENTS i on (i.ID = c.INGREDIENT)
	WHERE s.NAME LIKE 'Hazy IPA' AND i.ITYPE = 'grain'
	GROUP BY i.NAME
	HAVING COUNT(i.NAME) = (SELECT * FROM grain_mode)
;

-- Q10: ingredients not used in any beer

create or replace view Q10(unused)
as
	SELECT i.NAME as unused
	FROM INGREDIENTS i
	EXCEPT(SELECT DISTINCT i2.NAME
			FROM CONTAINS c
				JOIN INGREDIENTS i2 on (i2.ID = c.INGREDIENT)
				JOIN BEERS br on (br.ID = c.BEER)
	)
;

-- Q11: min/max abv for a given country

drop type if exists ABVrange cascade;
create type ABVrange as (minABV float, maxABV float);

create or replace function
	Q11(_country text) returns ABVrange
as $$
declare 
	min_abv float;
	max_abv float;
	abv float;
	val float;
begin
	val = (SELECT br.ABV
				FROM BREWED_BY bby
					JOIN BEERS br on (br.ID = bby.BEER)
					JOIN BREWERIES brw on (brw.ID = bby.BREWERY)
					JOIN LOCATIONS l on (brw.LOCATED_IN = l.ID)
				WHERE l.COUNTRY = _country
				LIMIT 1);
	IF val IS NULL THEN
		max_abv := 0;
		min_abv := 0;
	ELSE
		max_abv = val;
		min_abv = val;
	END IF;

	-- wouldn't run if table is empty (no country exists)
	FOR abv in
		SELECT br.ABV
			FROM BREWED_BY bby
				JOIN BEERS br on (br.ID = bby.BEER)
				JOIN BREWERIES brw on (brw.ID = bby.BREWERY)
				JOIN LOCATIONS l on (brw.LOCATED_IN = l.ID)
			WHERE l.COUNTRY = _country
		LOOP
			IF (abv < min_abv) THEN
				min_abv := abv;
			END IF;

			IF (abv > max_abv) THEN
				max_abv := abv;
			END IF;
		END LOOP;
		RETURN (min_abv, max_abv);
END;
$$
language plpgsql;

-- Q12: details of beers

drop type if exists BeerData cascade;
create type BeerData as (beer text, brewer text, info text);

create or replace function
	Q12(partial_name text) returns setof BeerData
as $$
declare
	beers text;
	breweries text;
	ingredients text;
	beer_info BeerData;
	beer record;
	brewery record;
	hop record;
	grain record;
	extra record;
	top_hop text;
	top_grain text;
	top_extra text;
begin
	-- Finding the beer
	FOR beer in
		SELECT br.NAME as NAME, br.ID as ID
			FROM BEERS br
			WHERE UPPER(br.NAME) LIKE UPPER('%' || partial_name || '%')
			GROUP BY ID
		LOOP
		beers := beer.NAME;
		breweries := '';
		ingredients := NULL;

		-- Finding breweries
		breweries := breweries || (SELECT brw.NAME as NAME
			FROM BREWED_BY bby
				JOIN BREWERIES brw on (brw.ID = bby.BREWERY)
			WHERE bby.BEER = beer.ID
			ORDER BY brw.name
			LIMIT 1);

		FOR brewery in 
			SELECT brw.NAME as NAME
			FROM BREWED_BY bby
				JOIN BREWERIES brw on (brw.ID = bby.BREWERY)
			WHERE bby.BEER = beer.ID
			ORDER BY brw.name
			OFFSET 1
		LOOP
			-- forming the string
			breweries := breweries || ' + ';
			breweries := breweries || brewery.NAME;
		END LOOP;

		-- Checking if ingredients null
		IF (SELECT i.NAME as NAME
			FROM CONTAINS c
				JOIN BEERS br on (br.ID = c.BEER)
				JOIN INGREDIENTS i on (i.ID = c.INGREDIENT)
			WHERE br.ID = beer.ID
			ORDER BY i.NAME
			LIMIT 1) IS NOT NULL THEN
			ingredients := '';
		END IF;

		-- Starting off list
		-- Finding hops
		top_hop := (SELECT i.NAME as NAME
			FROM CONTAINS c
				JOIN BEERS br on (br.ID = c.BEER)
				JOIN INGREDIENTS i on (i.ID = c.INGREDIENT)
			WHERE br.ID = beer.ID AND i.itype = 'hop'
			ORDER BY i.NAME
			LIMIT 1);
		-- Finding grain
		top_grain := (SELECT i.NAME AS NAME
			FROM CONTAINS c
				JOIN BEERS br on (br.ID = c.BEER)
				JOIN INGREDIENTS i on (i.ID = c.INGREDIENT)
			WHERE br.ID = beer.ID AND i.itype = 'grain'
			ORDER BY i.NAME
			LIMIT 1);
		-- Finding extras
		top_extra := (SELECT i.NAME AS NAME
			FROM CONTAINS c
				JOIN BEERS br on (br.ID = c.BEER)
				JOIN INGREDIENTS i on (i.ID = c.INGREDIENT)
			WHERE br.ID = beer.ID AND i.itype = 'adjunct'
			ORDER BY i.NAME
			LIMIT 1);

		IF top_hop IS NOT NULL THEN
			ingredients := ingredients || 'Hops: ';
			ingredients := ingredients || top_hop;
			FOR hop in
				SELECT i.NAME as NAME
				FROM CONTAINS c
					JOIN BEERS br on (br.ID = c.BEER)
					JOIN INGREDIENTS i on (i.ID = c.INGREDIENT)
				WHERE br.ID = beer.ID AND i.itype = 'hop'
				ORDER BY i.NAME
				OFFSET 1 ROWS
			LOOP
			ingredients := ingredients || ',' || hop.NAME;
			END LOOP;
		END IF;


		IF top_grain IS NOT NULL AND top_hop IS NOT NULL THEN
			ingredients := ingredients || E'\n';
		END IF;
		
		IF top_grain IS NOT NULL THEN
			ingredients := ingredients || 'Grain: ';
			ingredients := ingredients || top_grain;
			FOR grain in
				SELECT i.NAME AS NAME
				FROM CONTAINS c
					JOIN BEERS br on (br.ID = c.BEER)
					JOIN INGREDIENTS i on (i.ID = c.INGREDIENT)
				WHERE br.ID = beer.ID AND i.itype = 'grain'
				ORDER BY i.NAME
				OFFSET 1 ROWS
			LOOP
			ingredients := ingredients || ',' || grain.NAME;
			END LOOP;
		END IF;

		IF top_extra IS NOT NULL AND (top_grain IS NOT NULL or top_hop IS NOT NULL) THEN
			ingredients := ingredients || E'\n';
		END IF;

		IF top_extra IS NOT NULL THEN
			ingredients := ingredients || 'Extras: ';
			ingredients := ingredients || top_extra;
			FOR extra in
				SELECT i.NAME AS NAME
				FROM CONTAINS c
					JOIN BEERS br on (br.ID = c.BEER)
					JOIN INGREDIENTS i on (i.ID = c.INGREDIENT)
				WHERE br.ID = beer.ID AND i.itype = 'adjunct'
				ORDER BY i.NAME
				OFFSET 1 ROWS
			LOOP
			ingredients := ingredients || ',' || extra.NAME;
			END LOOP;
		END IF;

		beer_info.beer = beers;
		beer_info.brewer = breweries;
		beer_info.info = ingredients;
		return next beer_info;
	END LOOP;
END;
$$
language plpgsql;
