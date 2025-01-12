-- Vytvorenie databázy
CREATE DATABASE IMDb_DB;

-- Vytvorenie schémy pre staging tabuľky
CREATE SCHEMA IMDb_DB.staging;

USE SCHEMA IMDb_DB.staging;

-- Vytvorenie tabuľky movie (staging)
CREATE TABLE movie_staging (
    id VARCHAR(10) PRIMARY KEY,
    title VARCHAR(200),
    year INT,
    date_published DATE,
    duration INT,
    country VARCHAR(250),
    worlwide_gross_income VARCHAR(30),
    languages VARCHAR(200),
    production_company VARCHAR(200)
);

-- Vytvorenie tabuľky names (staging)
CREATE TABLE names_staging (
    id VARCHAR(10) PRIMARY KEY,
    name VARCHAR(100),
    height INT DEFAULT 0,
    date_of_birth DATE,
    known_for_movies VARCHAR(100)
);

-- Vytvorenie tabuľky director_mapping (staging)
CREATE TABLE director_mapping_staging (
    movie_id VARCHAR(10),
    name_id VARCHAR(10),
    PRIMARY KEY (movie_id, name_id),
    FOREIGN KEY (movie_id) REFERENCES movie_staging(id),
    FOREIGN KEY (name_id) REFERENCES names_staging(id)
);

-- Vytvorenie tabuľky role_mapping (staging)
CREATE TABLE role_mapping_staging (
    movie_id VARCHAR(10),
    name_id VARCHAR(10),
    category VARCHAR(10),
    PRIMARY KEY (movie_id, name_id),
    FOREIGN KEY (movie_id) REFERENCES movie_staging(id),
    FOREIGN KEY (name_id) REFERENCES names_staging(id)
);

-- Vytvorenie tabuľky ratings (staging)
CREATE TABLE ratings_staging (
    movie_id VARCHAR(10) PRIMARY KEY,
    avg_rating DECIMAL(3,1),
    total_votes INT,
    median_rating INT,
    FOREIGN KEY (movie_id) REFERENCES movie_staging(id)
);

-- Vytvorenie tabuľky genre (staging)
CREATE TABLE genre_staging (
    movie_id VARCHAR(10),
    genre VARCHAR(20),
    PRIMARY KEY (movie_id, genre),
    FOREIGN KEY (movie_id) REFERENCES movie_staging(id)
);

COPY INTO movie_staging
FROM @my_stage/movie.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO names_staging
FROM @my_stage/names.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1)
ON_ERROR = 'CONTINUE';

COPY INTO director_mapping_staging
FROM @my_stage/director_mapping.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO role_mapping_staging
FROM @my_stage/role_mapping.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO ratings_staging
FROM @my_stage/ratings.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1 ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE);

COPY INTO genre_staging
FROM @my_stage/genre.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);


SELECT * FROM role_mapping_staging;

--- ELT - (T)ransform

CREATE TABLE dim_time (
    time_id INT PRIMARY KEY,
    full_date DATE,
    year INT,
    month INT,
    day INT
);

INSERT INTO dim_time (time_id, full_date, year, month, day)
SELECT 
    DISTINCT
    CAST(TO_CHAR(date_published, 'YYYYMMDD') AS INT) as time_id,
    date_published as full_date,
    EXTRACT(YEAR FROM date_published) as year,
    EXTRACT(MONTH FROM date_published) as month,
    EXTRACT(DAY FROM date_published) as day
FROM movie_staging
WHERE date_published IS NOT NULL;

CREATE TABLE dim_movie (
    movie_id VARCHAR(10) PRIMARY KEY,
    title VARCHAR(200),
    duration INT,
    languages VARCHAR(200),
    production_company VARCHAR(200)
);

INSERT INTO dim_movie (movie_id, title, duration, languages, production_company)
SELECT 
    id,
    title,
    duration,
    languages,
    production_company
FROM movie_staging;

CREATE TABLE dim_person (
    person_id VARCHAR(10) PRIMARY KEY,
    name VARCHAR(100),
    height INT,
    date_of_birth DATE,
    known_for_movies VARCHAR(100)
);

INSERT INTO dim_person (person_id, name, height, date_of_birth, known_for_movies)
SELECT 
    id,
    name,
    COALESCE(height, 0),
    date_of_birth,
    known_for_movies
FROM names_staging;

CREATE TABLE dim_genre (
    genre_id INT IDENTITY(1,1) PRIMARY KEY,
    genre_name VARCHAR(20) UNIQUE
);

INSERT INTO dim_genre (genre_name)
SELECT DISTINCT genre
FROM genre_staging;

CREATE TABLE dim_location (
    location_id INT IDENTITY(1,1) PRIMARY KEY,
    country VARCHAR(250) UNIQUE
);

INSERT INTO dim_location (country)
SELECT DISTINCT country 
FROM movie_staging 
WHERE country IS NOT NULL;

CREATE TABLE fact_movies (
    movie_id VARCHAR(10),
    person_id VARCHAR(10),
    genre_id INT,
    time_id INT,
    location_id INT,
    role_category VARCHAR(10),
    avg_rating DECIMAL(3,1),
    total_votes INT,
    median_rating INT,
    worldwide_gross_income VARCHAR(30),
    PRIMARY KEY (movie_id, person_id, genre_id),
    FOREIGN KEY (movie_id) REFERENCES dim_movie(movie_id),
    FOREIGN KEY (person_id) REFERENCES dim_person(person_id),
    FOREIGN KEY (genre_id) REFERENCES dim_genre(genre_id),
    FOREIGN KEY (time_id) REFERENCES dim_time(time_id),
    FOREIGN KEY (location_id) REFERENCES dim_location(location_id)
);

INSERT INTO fact_movies (
    movie_id, person_id, genre_id, time_id, location_id,
    role_category, avg_rating, total_votes, median_rating, worldwide_gross_income
)
SELECT DISTINCT
    m.id,
    COALESCE(d.name_id, r.name_id) as person_id,
    g.genre_id,
    TO_NUMBER(TO_CHAR(m.date_published, 'YYYYMMDD')) as time_id,
    l.location_id,
    r.category,
    rt.avg_rating,
    rt.total_votes,
    rt.median_rating,
    m.worlwide_gross_income
FROM movie_staging m
INNER JOIN director_mapping_staging d ON m.id = d.movie_id
INNER JOIN role_mapping_staging r ON m.id = r.movie_id
INNER JOIN genre_staging gs ON m.id = gs.movie_id
INNER JOIN dim_genre g ON gs.genre = g.genre_name
LEFT JOIN dim_location l ON m.country = l.country
LEFT JOIN ratings_staging rt ON m.id = rt.movie_id
WHERE m.id IS NOT NULL 
  AND COALESCE(d.name_id, r.name_id) IS NOT NULL 
  AND g.genre_id IS NOT NULL;


DROP TABLE IF EXISTS movie_staging;
DROP TABLE IF EXISTS names_staging;
DROP TABLE IF EXISTS director_mapping_staging;
DROP TABLE IF EXISTS role_mapping_staging;
DROP TABLE IF EXISTS ratings_staging;
DROP TABLE IF EXISTS genre_staging;

-- Top 10 Movies by Average Rating and Total Votes
SELECT 
    m.title,
    AVG(f.avg_rating) as average_rating,
    SUM(f.total_votes) as total_votes
FROM fact_movies f
JOIN dim_movie m ON f.movie_id = m.movie_id
GROUP BY m.title
ORDER BY average_rating DESC, total_votes DESC
LIMIT 10;

-- Most Prolific Actors/Directors by Number of Movies
SELECT 
    p.name,
    f.role_category,
    COUNT(DISTINCT f.movie_id) as number_of_movies,
    AVG(f.avg_rating) as average_movie_rating
FROM fact_movies f
JOIN dim_person p ON f.person_id = p.person_id
GROUP BY p.name, f.role_category
ORDER BY number_of_movies DESC
LIMIT 10;

-- Najlepšie žánre podľa priemerného hodnotenia
SELECT 
    g.genre_name,
    COUNT(DISTINCT f.movie_id) as number_of_movies,
    AVG(f.avg_rating) as average_rating,
    SUM(f.total_votes) as total_votes
FROM fact_movies f
JOIN dim_genre g ON f.genre_id = g.genre_id
GROUP BY g.genre_name
ORDER BY average_rating DESC
LIMIT 10;

-- Rating Distribution
SELECT 
    FLOOR(avg_rating) as rating_bucket,
    COUNT(*) as number_of_movies
FROM fact_movies
WHERE avg_rating IS NOT NULL
GROUP BY FLOOR(avg_rating)
ORDER BY rating_bucket;


-- Movie Duration Distribution
SELECT 
    FLOOR(duration/30) * 30 as duration_bucket,
    COUNT(*) as number_of_movies
FROM dim_movie
WHERE duration IS NOT NULL
GROUP BY FLOOR(duration/30)
ORDER BY duration_bucket;




