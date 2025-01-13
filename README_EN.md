# InternetMovieDatabase-ETL

[Slovak version](https://github.com/AndreyTrusov/InternetMovieDatabase-ETL/blob/main/README.md)

This repository contains an **implementation of the ETL process** in Snowflake for analyzing data from the IMDb dataset. The project analyzes the **relationships** between movies, actors, and audience ratings. The resulting data model allows for **multidimensional analysis** of the relationships between films.

---
## **1. Introduction and description of source data**
The aim of the semester project is to analyze data related to films, filmmakers and audience ratings. This analysis allows to identify trends in cinema, the most popular films and the relationships between filmmakers.
The source data comes from the IMDb dataset. The dataset contains six main tables:
- `movie`
- `ratings`
- `names`
- `director_mapping`
- `role_mapping`
- `genre`
  
The purpose of the ETL process was to prepare, transform and make this data available for multidimensional analysis.

---
### **1.1 Data architecture**

### **ERD diagram**
The raw data are laid out in a relational model, which is shown in an **entity-relational diagram (ERD)**:

<p align="center">
  <img src="https://github.com/user-attachments/assets/d778f8c2-0630-459e-ac5d-feaf759dc7a3" alt="ERD Schema">
  <br>
  <em>Image 1 Entity-relational schema of the Internet Movie Database</em>
</p>

---
## **2. Dimensional model**

A **star schema** model has been proposed for effective analysis where the central point is the fact table **`fact_movies`**, which is linked to the following dimensions::

- **`dim_time`**: Contains time information about the release date of the film (day, month, year), including a numeric time identifier.
- **`dim_movie`**: Includes detailed information about the films (title, length, languages, production company).
- **`dim_person`**: Includes information about the people (actors and directors) including their name, height, date of birth and movies they are known for.
- **`dim_genre`**: Includes information on the genre classification of films.
- **`dim_location`**: Includes geographical data on the countries where the films were produced.

The structure of the **star model** is shown in the diagram **below**. The diagram shows the links between the fact table and the dimensions, which simplifies the understanding and implementation of the model.

<p align="center">
  <img src="https://github.com/user-attachments/assets/55fc0f61-1a83-40ee-81d6-680cbaad2083" alt="Star Schema">
  <br>
  <em>Image 2 Star schema for Internet Movie Database</em>
</p>

---
## **3. ETL process in Snowflake**

The ETL process consisted of three main phases: `Extract', `Transform' and `Load'. This process was implemented in Snowflake in order to prepare the source data from the staging layer into a multidimensional model suitable for analysis and visualization.

---
### **3.1 Extract**

The **data** from the source dataset was formatted by phpMyAdmin into `.csv` format, then **uploaded** to Snowflake via an internal stage repository called `my_stage`. A **stage in Snowflake** serves as a temporary storage for importing or exporting data. The creation of a stage was provided by the command:

#### Code example:


```sql
-- Creating a database
CREATE DATABASE IMDb_DB;

-- Creating a schema for a staging table
CREATE SCHEMA IMDb_DB.staging;

USE SCHEMA IMDb_DB.staging;

CREATE OR REPLACE STAGE my_stage;

-- Creating a movie table (staging)
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
```
Files containing data on films, directors, actors, genres and ratings were then **uploaded to Stage**. The data was imported into the staging tables using the COPY INTO command. A similar command was used for each table:

```sql
-- Copy to staging database
COPY INTO movie_staging
FROM @my_stage/movie.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);
```

In the case of inconsistent records, the parameter `ON_ERROR = 'CONTINUE'` was used to ensure that the process continued without interrupting on errors.

---
### **3.2 Transfor**

At this stage, the **data** from the stage tables are **cleaned, transformed** and enriched to support efficient analysis. The main objective is to prepare dimension tables and a fact table to **enable detailed analysis** of the film-related data.

#### Dimensional Tables

`dim_time`: This dimension table contains time information, specifically date, year, month, and day. It is used to analyze temporal aspects in the data, such as yearly, monthly or daily trends.

```sql
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
```

`dim_movie`: This dimension table stores information about movies such as title, duration, languages, production company and other details to help categorize movies and manage related data.

```sql
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
```

`dim_person`: This table contains information about the people involved in the making of the films, such as name, height, date of birth and known films they have appeared in. It helps to link actors, directors and other filmmakers to films.

```sql
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
```

`dim_genre`: This dimension table contains a list of film genres. Each genre has its own unique name, which allows you to efficiently categorize movies by their genre classification.

```sql
CREATE TABLE dim_genre (
    genre_id INT IDENTITY(1,1) PRIMARY KEY,
    genre_name VARCHAR(20) UNIQUE
);

INSERT INTO dim_genre (genre_name)
SELECT DISTINCT genre
FROM genre_staging;
```

`dim_location`: This dimension table contains information about locations, specifically landscapes, that are associated with films or their filming. Each country is listed as a unique entry in the database, allowing you to track the geographical aspects of the films.

```sql
CREATE TABLE dim_location (
    location_id INT IDENTITY(1,1) PRIMARY KEY,
    country VARCHAR(250) UNIQUE
);

INSERT INTO dim_location (country)
SELECT DISTINCT country 
FROM movie_staging 
WHERE country IS NOT NULL;
```

`fact_movies`: This fact sheet contains combined information on films, people, genres, times, locations, and other metrics. It consists of keys from different dimensions (movies, people, genres, time and location)

```sql
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
```

---
### **3.3 Load**
After the dimensions were successfully created, the **data were loaded into the final structure**. Finally, the staging tables were removed to **optimize storage** utilization. This step is crucial for maintaining the clarity and efficiency of the database environment:

```sql
DROP TABLE IF EXISTS movie_staging;
DROP TABLE IF EXISTS names_staging;
DROP TABLE IF EXISTS director_mapping_staging;
DROP TABLE IF EXISTS role_mapping_staging;
DROP TABLE IF EXISTS ratings_staging;
DROP TABLE IF EXISTS genre_staging;
```

The ETL Snowflake process **allowed** the processing of disordered **data from different sources** into a **multidimensional model** of the star. This process involved cleaning, transforming and enriching information about movies, actors and other important aspects. The resulting **data model enables detailed analysis** of audience preferences, movie ratings, and other metrics, and serves as the basis for visualizations and reports that are invaluable to film industry executives and analysts.

---
## **4 Data visualisation**

The Dashboard includes **`7 visualizations`** that provide a basic overview of key metrics and trends related to movies, users and their ratings. These visualizations **answer important questions** and enable a better understanding of user behavior, preferences, and interactions with content. Each visualization is designed to provide valuable information for analysis and decision-making.

### **Graph 1: Top 10 films by average rating and total votes**

Which films are highly rated and watched? / Helps identify the most successful films for marketing and content acquisition strategies.

```sql
SELECT 
    m.title,
    AVG(f.avg_rating) as average_rating,
    SUM(f.total_votes) as total_votes
FROM fact_movies f
JOIN dim_movie m ON f.movie_id = m.movie_id
GROUP BY m.title
ORDER BY average_rating DESC, total_votes DESC
LIMIT 10;
```

<img width="836" alt="image" src="https://github.com/user-attachments/assets/75ca2267-79a9-4af0-9742-c708c9b770d4" />

---
### **Graph 2: Most productive actors/directors by number of films**

Who are our most productive talents and how are their films doing? / Useful when scouting talent and deciding on partnerships.

```sql
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
```

<img width="836" alt="image" src="https://github.com/user-attachments/assets/c7c50a8f-2041-4c73-94de-f27c47938fb0" />

---
### **Graph 3: Most productive actors/directors by number of films**

Which genres are most successful with audiences? / Decisions about investment in content acquisition and production.

```sql
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
```

<img width="849" alt="image" src="https://github.com/user-attachments/assets/a3ba6d49-31a6-416b-ad95-e557f4f561ee" />

---
### **Graph 4: Distribution of films in each rating group**

What is our typical level of film quality? / Helps to understand quality standards and determine rating thresholds.

```sql
SELECT 
    FLOOR(avg_rating) as rating_bucket,
    COUNT(*) as number_of_movies
FROM fact_movies
WHERE avg_rating IS NOT NULL
GROUP BY FLOOR(avg_rating)
ORDER BY rating_bucket;
```

<img width="830" alt="image" src="https://github.com/user-attachments/assets/71452587-e1ef-4750-891c-9c7414565403" />

---
### **Graph 5: Film duration distribution (30-minute blocks)**

What are the most common film lengths? / Helps optimize the length of content according to audience preferences

```sql
SELECT 
    FLOOR(duration/30) * 30 as duration_bucket,
    COUNT(*) as number_of_movies
FROM dim_movie
WHERE duration IS NOT NULL
GROUP BY FLOOR(duration/30)
ORDER BY duration_bucket;
```

<img width="830" alt="image" src="https://github.com/user-attachments/assets/d41bb232-e79f-4c99-b84f-49fba694b878" />

---
### **Graph 6: ROI analysis by manufacturing company**

Which manufacturing companies deliver the best return on investment? / Helps identify potential manufacturing partners and investment opportunities.

```sql
SELECT 
    m.production_company,
    COUNT(DISTINCT f.movie_id) as movies_produced,
    AVG(TRY_TO_DECIMAL(REGEXP_REPLACE(f.worldwide_gross_income, '[$,]', ''), 18, 2)) as avg_revenue,
    AVG(f.avg_rating) as avg_rating,
    AVG(f.total_votes) as avg_engagement
FROM fact_movies f
JOIN dim_movie m ON f.movie_id = m.movie_id
WHERE m.production_company IS NOT NULL
GROUP BY m.production_company
HAVING COUNT(DISTINCT f.movie_id) >= 3
ORDER BY avg_revenue DESC
LIMIT 10;
```

![image](https://github.com/user-attachments/assets/f37524ac-3507-46d2-8fc3-ade855e7f84c)

---
### **Graph 7: Seasonal performance analysis**

When is the best time to release films? / Optimizes release scheduling for maximum revenue

```sql
SELECT 
    t.month,
    COUNT(DISTINCT f.movie_id) as releases
FROM fact_movies f
JOIN dim_time t ON f.time_id = t.time_id
GROUP BY t.month;
```

![image](https://github.com/user-attachments/assets/94d17a20-7021-4029-a83d-3ea0d3ac6a68)

---
### **Graph 8: Language market performance**

Which language markets are the most profitable? / Driving international market expansion and localisation efforts

```sql
SELECT 
    m.languages,
    COUNT(DISTINCT f.movie_id) as movie_count,
FROM fact_movies f
JOIN dim_movie m ON f.movie_id = m.movie_id
WHERE m.languages IS NOT NULL
GROUP BY m.languages;
```

![image](https://github.com/user-attachments/assets/bd0f1e69-8f26-49fd-9e15-c33edfc6aad0)


