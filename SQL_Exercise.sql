-- ==================================== --
-- PART ONE: Evaluate data imperfection
-- ==================================== --
-- Exercise 1 --
-- Try to identify a maximum of issues on metadata design :
-- You can write down here your comments as well as your queries that 
-- helped you to identify those issues

use movies;

DESC metadata;
select * from metadata;

-- datatype INT expected for num_critic_for_reviews field
-- datatype INT expected for duration field
-- datatype INT expected for actor_3_facebook_likes field 
-- datatype INT expected for gross field
-- datatype INT expected for num_voted_users field
-- datatype INT expected for facenumber_in_poster field
-- datatype INT expected for num_user_for_reviews field
-- datatype INT expected for budget field
-- datatype YEAR could be used for the title_year field
-- datatype INT expected for movie_facebook_likes field

-- order of fields was poorly placed. 
-- (eg. actor_1_facebook_likes should be next to actor_1_name)


-- Exercise 2 --
-- Try to evaluate with different queries the number of corrupted rows. 
-- We need to evaluate how much rows will be eventually eliminated by the cleaning. 
-- If the table is too corrupted, maybe the better is abandoned the analysis.

select * from metadata
where duration = '' or upper(duration) REGEXP '^-?[A-Z ]+$';
-- 15 empty values

select count(*) from metadata
where num_voted_users not REGEXP '^-?[0-9]+$';
-- 69 non numerical values

select * from metadata
where actor_3_name REGEXP '^-?[0-9 ]+$';
-- 67 rows of numerical values found in actor_3_name

select * from metadata
where facenumber_in_poster not REGEXP '^-?[0-9]+$' and facenumber_in_poster != '';
-- 59 rows of non numerical values

select * from metadata
where plot_keywords REGEXP '^-?[0-9 ]+$';
-- 63 rows of numerical values

select * from metadata
where movie_imdb_link NOT REGEXP "^(http://www.imdb.com/)[\.A-Za-z0-9\-]+";
-- 69 rows where value is not imdb link

select num_user_for_reviews from metadata
where num_user_for_reviews REGEXP '^-?[A-Za-z]+' ;
-- 66 rows of non numerical data

select count(*) from metadata
where language REGEXP '^-?[0-9]+$';
-- 59 rows of numerical values

select distinct(country) from metadata;

select * from metadata
where country REGEXP '^-?[0-9]+$' 
or country like '%http%' 
or country in ('New Line','Official site','English','Mandarin','Romanian','Spanish',
'Italian','Hindi','German')
;
-- 68 rows that is not a country

select distinct(content_rating) from metadata;

select content_rating from metadata
where content_rating not in ('PG','PG-13','G','R','TV-14','TV-PG','TV-MA','TV-G','Not Rated',
'Unrated','Approved','TV-Y','NC-17','X','TV-Y7','GP','Passed','M','') ;
-- 68 rows that is not a content rating

select budget from metadata
where budget not REGEXP '^-?[0-9]+$'
and budget != '';
-- 63 non numerical rows

select title_year from metadata
where title_year NOT REGEXP '^[0-9]{4}'
and title_year != '';
-- 7 rows where title_year is not a year value

select count(imdb_score) from metadata
where imdb_score > 10;
-- 61 rows of false score
-- imdb score should not be > 10


-- ==================================== --
-- PART TWO: Make ambitious table junction
-- ==================================== --
-- The database “movies” contains two kind of ratings. 
-- One “rating” is in the table “ratings” and is link to a “movieId”. The other, “imdb_score”, is in the “metadata” table. 
-- What we want here is to make an ambitious junction between the two table and get, per movie, the two kind of ratings available in this database.
-- Why ambitious? 
-- Because as you can see there is no common key or even common attribute between the two tables. 
-- In fact, there is no perfectly identic attributes but there is one eventually common value : the movie title.
-- Here, the issue here is how formate/clean your table’s data so you could make a proper join.
-- ====== --
-- Step 1:
-- What is the difference between the two attributes metadata.movie_title and movies.title?
-- Only comment here

-- movies.title contains title and year of a movie
-- metadata.movie_title contains only title of a movie

-- ====== --
-- Step 2:
-- How to cut out some unwanted pieces of a string ? 
-- Use the function SUBSTR() but you will also need another function : CHAR_LENGTH().
-- From the movies table, 
-- Try to get a query returning the movie.title, considering only the correct title of each movie.

select SUBSTR(title, -6, 6) from movies
where SUBSTR(title, -5, 4) REGEXP '[0-9]{4}';
-- testing substr function, 10 rows missing

select title from movies
where SUBSTR(title, -5, 4) NOT REGEXP '[0-9]{4}';
-- examining the 10 missing rows

select title from movies
where SUBSTR(title, -1, 1) = ' ';
-- examining problem with missing rows

SELECT SUBSTR(title,1,char_length(title)-6) FROM movies
WHERE SUBSTR(title, -5, 4) REGEXP '[0-9]{4}';
-- testing char_length function

select
case
	when SUBSTR(title, -5, 4) REGEXP '[0-9]{4}' then SUBSTR(title,1,char_length(title)-6)
    when SUBSTR(title, -1, 1) = ' ' then SUBSTR(title,1,char_length(title)-7)
    when SUBSTR(title, -2, 1) = '-' then SUBSTR(title,1,char_length(title)-7)
    else title
end as clean_title
from movies;

-- And then also include the aggregation of the average rating for each movie
-- joining the ratings table

select movies.movieId,
case
	when SUBSTR(title, -5, 4) REGEXP '[0-9]{4}' then SUBSTR(title,1,char_length(title)-6)
    when SUBSTR(title, -1, 1) = ' ' then SUBSTR(title,1,char_length(title)-7)
    when SUBSTR(title, -2, 1) = '-' then SUBSTR(title,1,char_length(title)-7)
    else title
end as clean_title, avg(ratings.rating)
from movies
left join ratings on movies.movieId = ratings.movieId
group by movies.movieId, movies.title
;

-- ====== --
-- Step 3:
-- Now that we have a good request for cleaned and aggregated version of movies/ratings, 
-- you need to also have a clean request from metadata.
-- Make a query returning aggregated metadata.imdb_score for each metadata.movie_title.
-- excluding the corrupted rows (69 rows to exclude in total)

SELECT count(*) FROM metadata; 
-- 5043 rows

SELECT movie_title FROM metadata
WHERE movie_imdb_link IN (
                    SELECT movie_imdb_link FROM metadata 
                    WHERE movie_imdb_link REGEXP "^(http://www.imdb.com/)[\.A-Za-z0-9\-]+"
                   );
-- 69 rows excluded (5043-4974)

SELECT movie_title, avg(imdb_score) FROM metadata
WHERE movie_imdb_link IN (
                    SELECT movie_imdb_link FROM metadata 
                    WHERE movie_imdb_link REGEXP "^(http://www.imdb.com/)[\.A-Za-z0-9\-]+"
                   )
group by movie_title;


-- ====== --
-- Step 4:
-- It is time to make a JOIN! Try to make a request merging the result of Step 2 and Step 3. 
-- You need to use your previous as two subqueries and join on the movie title.
-- What is happening ? What is the result ? This request can take time to return.

select * 
from (select movies.movieId,
		case
			when SUBSTR(title, -5, 4) REGEXP '[0-9]{4}' then SUBSTR(title,1,char_length(title)-6)
			when SUBSTR(title, -1, 1) = ' ' then SUBSTR(title,1,char_length(title)-7)
			when SUBSTR(title, -2, 1) = '-' then SUBSTR(title,1,char_length(title)-7)
			else title
		end as clean_title, avg(ratings.rating)
		from movies
		left join ratings on movies.movieId = ratings.movieId
		group by movies.movieId, movies.title) t1
join (SELECT movie_title, avg(imdb_score) FROM metadata
			WHERE movie_imdb_link IN (
								SELECT movie_imdb_link FROM metadata 
								WHERE movie_imdb_link REGEXP "^(http://www.imdb.com/)[\.A-Za-z0-9\-]+"
							   )
			group by movie_title) t2
on t1.clean_title = t2.movie_title
-- where t1.clean_title like '%King Kong%'
;

-- some rows from metadata are duplicated after joining. 
-- For example, there are 3 versions of King Kong (movieId 41569, 2367, 2366) from movies table
-- metadata only has 1 record of King Kong from year 2005
-- 1 record of King Kong from metadata joins to all 3 records of King Kong from movies 


-- ====== --
-- Step 5:
-- There is a possibility that your previous query doesn't work for apparently no reasons, 
-- despite of the join condition being respected on some rows 
-- (check by yourself on a specific film of your choice by adding a simple WHERE condition).
-- Try to find out what could go wrong 
-- And try to query a workable join
-- Tip: Think about spaces or blanks 

select * 
from (select movies.movieId,
		case
			when SUBSTR(title, -5, 4) REGEXP '[0-9]{4}' then SUBSTR(title,1,char_length(title)-6)
			when SUBSTR(title, -1, 1) = ' ' then SUBSTR(title,1,char_length(title)-7)
			when SUBSTR(title, -2, 1) = '-' then SUBSTR(title,1,char_length(title)-7)
			else title
		end as clean_title, 
		case 
			when SUBSTR(title, -5, 4) REGEXP '[0-9]{4}' then SUBSTR(title, -5, 4)
			when SUBSTR(title, -6, 4) REGEXP '[0-9]{4}' then SUBSTR(title, -6, 4)
		end as movie_year,
		-- There are movies with the same title (different movieId) in movies table
		-- We will need movie year as well to join the right version in metadata.movie_title
		avg(ratings.rating)
		from movies
		left join ratings on movies.movieId = ratings.movieId
		group by movies.movieId, movies.title, movie_year) t1
join (SELECT movie_title, title_year, avg(imdb_score) FROM metadata
			WHERE movie_imdb_link IN (
								SELECT movie_imdb_link FROM metadata 
								WHERE movie_imdb_link REGEXP "^(http://www.imdb.com/)[\.A-Za-z0-9\-]+"
							   )
			group by movie_title, title_year) t2
on t1.clean_title = t2.movie_title
and t1.movie_year = t2.title_year
;

-- For final version of the output, 
-- Also include the count of ratings used to compute the average.

select * 
from (select movies.movieId,
		case
			when SUBSTR(title, -5, 4) REGEXP '[0-9]{4}' then SUBSTR(title,1,char_length(title)-6)
			when SUBSTR(title, -1, 1) = ' ' then SUBSTR(title,1,char_length(title)-7)
			when SUBSTR(title, -2, 1) = '-' then SUBSTR(title,1,char_length(title)-7)
			else title
		end as clean_title, 
		case 
			when SUBSTR(title, -5, 4) REGEXP '[0-9]{4}' then SUBSTR(title, -5, 4)
			when SUBSTR(title, -6, 4) REGEXP '[0-9]{4}' then SUBSTR(title, -6, 4)
		end as movie_year, 
		avg(ratings.rating), count(ratings.rating)
		from movies
		left join ratings on movies.movieId = ratings.movieId
		group by movies.movieId, movies.title, movie_year) t1
join (SELECT movie_title, title_year, avg(imdb_score), count(imdb_score) FROM metadata
			WHERE movie_imdb_link IN (
								SELECT movie_imdb_link FROM metadata 
								WHERE movie_imdb_link REGEXP "^(http://www.imdb.com/)[\.A-Za-z0-9\-]+"
							   )
			group by movie_title, title_year) t2
on t1.clean_title = t2.movie_title
and t1.movie_year = t2.title_year
;

-- Congratulations !!
