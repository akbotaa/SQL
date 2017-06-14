--Q1. Count the number of tuples

SELECT COUNT(*) FROM Authorship;

  count  
---------
 8806789
(1 row)

SELECT COUNT(*) FROM Article;

  count  
---------
 1373035
(1 row)

SELECT COUNT(*) FROM Inproceedings;

  count  
---------
 1712660
(1 row)



--Q2a. Add a column “Area” in the Inproceedings table.

ALTER TABLE Inproceedings ADD COLUMN area VARCHAR(10) DEFAULT UNKNOWN;



--Q2b. Populate the column “Area” following the table below. If there is no match, then set it to “UNKNOWN”.

UPDATE Inproceedings
SET area = Database
WHERE booktitle IN (SIGMOD Conference, VLDB, ICDE, PODS);
--UPDATE 10207

UPDATE Inproceedings
SET area = Theory
WHERE booktitle IN (STOC, FOCS, SODA, ICALP);
--UPDATE 10505

UPDATE Inproceedings
SET area=Systems
WHERE booktitle IN (SIGCOMM, ISCA, HPCA, PLDI);
--UPDATE 4664

UPDATE Inproceedings
SET area=ML-AI 
WHERE booktitle IN (ICML, NIPS, AAAI, IJCAI);
--UPDATE 20539



--Q3a. Find the number of papers in each area above.

SELECT COUNT(*)
FROM Inproceedings
WHERE area='Database';

 count 
-------
 10207
(1 row)


SELECT COUNT(*)
FROM Inproceedings
WHERE area='Theory';

 count 
-------
 10505
(1 row)

SELECT COUNT(*)
FROM Inproceedings
WHERE area='Systems';

 count 
-------
  4664
(1 row)

SELECT COUNT(*)
FROM Inproceedings
WHERE area='ML-AI';

 count 
-------
 20539
(1 row)



--Q3b. Find the top-20 authors who published the most number of “Database” papers.

SELECT author
FROM Inproceedings I, Authorship A
WHERE I.pubkey=A.pubkey AND area='Database'
GROUP BY author
ORDER BY COUNT(*) DESC
LIMIT 20;

        author        
----------------------
 Divesh Srivastava
 Surajit Chaudhuri
 Jiawei Han
 Jeffrey F. Naughton
 Philip S. Yu
 Hector Garcia-Molina
 H. V. Jagadish
 Raghu Ramakrishnan
 Michael Stonebraker
 Beng Chin Ooi
 Rakesh Agrawal
 Nick Koudas
 Michael J. Carey
 David J. DeWitt
 Kian-Lee Tan
 Christos Faloutsos
 Gerhard Weikum
 Serge Abiteboul
 Michael J. Franklin
 Divyakant Agrawal
(20 rows)



--Q3c. Find the number of authors who published in exactly two of the four areas (do not consider “UNKNOWN”).

SELECT COUNT(*) AS numb_of_authors
FROM (
		SELECT COUNT(*)
		FROM Inproceedings I, Authorship A
		WHERE I.pubkey=A.pubkey AND area!='UNKNOWN'
		GROUP BY author
		HAVING COUNT(DISTINCT area)=2
	) TMP;
	
 numb_of_authors 
-----------------
            2765
(1 row)



--Q3d. Find the number of authors who wrote more journal papers than conference papers (irrespective of research areas).

SELECT COUNT(*)
FROM (
		SELECT author, COUNT(*) AS journ_count 
		FROM Article R, Authorship A 
		WHERE R.pubkey=A.pubkey
		GROUP BY author
	) J 
		
	LEFT OUTER JOIN (
		
		SELECT author, COUNT(*) AS conf_count 
		FROM Inproceedings I, Authorship A 
		WHERE I.pubkey=A.pubkey
		GROUP BY author
	) C
	
ON J.author=C.author
WHERE J.journ_count > C.conf_count OR J.conf_count IS NULL;

 count  
--------
 665387
(1 row)



--Q3e. Among the authors who have published at least one “Database” paper (in any year), find the top-5 authors who published the maximum number of papers (journal OR conference) since the year 2000.

SELECT author
FROM (
		(SELECT DISTINCT author 
		FROM Inproceedings I, Authorship A 
		WHERE I.pubkey=A.pubkey AND area='Database'
		) S
	
		NATURAL JOIN
	
		(SELECT author, COUNT(*) AS paper_count
		FROM (
			(SELECT author, I.pubkey AS paper 
			FROM Inproceedings I, Authorship A 
			WHERE I.pubkey=A.pubkey AND year>=2000)
		
			UNION
		
			(SELECT author, R.pubkey AS paper 
			FROM Article R, Authorship A 
			WHERE R.pubkey=A.pubkey AND year>=2000)
			) A
			
		GROUP BY author
		) B

 	)C
ORDER BY paper_count DESC
LIMIT 5;

  author   
-----------
 Wei Wang
 Wei Zhang
 Yang Yang
 Jing Li
 Tao Li
(5 rows)



--Q4a. Plot a linegraph with two lines, one for the number of journal papers and the other for the number of conference paper in every decade starting from 1950.


COPY(
	SELECT *
	FROM (
		SELECT COUNT(*) AS conf_count, decade_st
		FROM	(
					SELECT pubkey, floor(year/10)*10 AS decade_st
					FROM Inproceedings
					WHERE year>=1950
				) Conf
		GROUP BY decade_st
		ORDER BY decade_st
		) C 
	
		NATURAL JOIN 
	
		(SELECT COUNT(*) AS journ_count, decade_st
		FROM 	(
					SELECT pubkey, floor(year/10)*10 AS decade_st
					FROM Article
					WHERE year>=1950
				) Journ
				
	GROUP BY decade_st
	ORDER BY decade_st) J) TO '/Users/akbota/Documents/q4a.csv' DELIMITER ',' CSV HEADER;
		
		
		

--Q4b. Plot a barchart showing how the average number of collaborators varied in each decade starting from 1950 in each of the four areas.


COPY
(
	-- find decade for each paper
	WITH PaperDecade AS
	(	
        SELECT pubkey, year/10*10 AS decade
        FROM Article
		
        UNION
		
        SELECT pubkey, year/10*10 AS decade
        FROM Inproceedings
	),
	
	-- add decade to every Authorship entry
	AuthorshipDec AS
	(
		SELECT A.author, A.pubkey, B.decade
		FROM Authorship A, PaperDecade B
		WHERE A.pubkey = B.pubkey
	),
	
	-- for every author find the number of his/her collaborators in every decade
	NumbCollabDec AS
	(
		SELECT A.author, B.decade, COUNT(DISTINCT B.author) AS numcollab
		FROM Authorship A, AuthorshipDec B
		WHERE A.pubkey = B.pubkey
		AND A.author != B.author
		GROUP BY A.author, B.decade
	),
	
	-- for every area and every decade find authors that have published conference papers
	AreaDecAuthor AS
	(
		SELECT DISTINCT A.area, A.year/10*10 AS decade, B.author
		FROM Inproceedings A, Authorship B
	    WHERE A.area != ‘UNKNOWN’
		AND A.pubkey = B.pubkey
	)
	
	--------------------------------------------------------------------------------------
	--final step: for every decade and every area find the average number of collaborators
	
	SELECT A.decade, B.area, AVG(A.numcollab) AS avgCollab
	FROM NumCollabDec A, AreaDecAuthor B
	WHERE A.author = B.author AND A.decade = B.decade
	GROUP BY A.decade, B.area
	ORDER BY A.decade ASC, B.area ASC
	
) TO '/Users/akbota/Documents/q4b.csv' DELIMITER ',' CSV HEADER;



