# InternetMovieDatabase-ETL
Tento repozitár obsahuje implementáciu ETL procesu v Snowflake pre analýzu dát z IMDb datasetu. Projekt analyzuje vzťahy medzi filmami, hercami, režisérmi a hodnoteniami divákov. Výsledný dátový model umožňuje multidimenzionálnu analýzu vzťahov medzi filmami.

---
## **1. Úvod a popis zdrojových dát**
Cieľom semestrálneho projektu je analyzovať dáta týkajúce sa filmov, tvorcov a diváckych hodnotení. Táto analýza umožňuje identifikovať trendy v kinematografii, najpopulárnejšie filmy a vzťahy medzi tvorcami.
Zdrojové dáta pochádzajú z IMDb datasetu. Dataset obsahuje šesť hlavných tabuliek:
- `movie`
- `ratings`
- `names`
- `director_mapping`
- `role_mapping`
- `genre`
  
Účelom ETL procesu bolo tieto dáta pripraviť, transformovať a sprístupniť pre viacdimenzionálnu analýzu.

---
### **1.1 Dátová architektúra**

### **ERD diagram**
Surové dáta sú usporiadané v relačnom modeli, ktorý je znázornený na **entitno-relačnom diagrame (ERD)**:

<p align="center">
  <img src="https://github.com/user-attachments/assets/d778f8c2-0630-459e-ac5d-feaf759dc7a3" alt="ERD Schema">
  <br>
  <em>Obrázok 1 Entitno-relačná schéma Internet Movie Database</em>
</p>

---
## **2. Dimenzionálny model**
Dimenzionálny model
Navrhnutý bol **hviezdicový model (star schema)**, pre efektívnu analýzu kde centrálny bod predstavuje faktová tabuľka **`fact_movies`**, ktorá je prepojená s nasledujúcimi dimenziami:

- **`dim_time`**: Obsahuje časové údaje o dátume vydania filmu (deň, mesiac, rok) vrátane numerického identifikátora času.
- **`dim_movie`**: Obsahuje podrobné informácie o filmoch (názov, dĺžka, jazyky, produkčná spoločnosť).
- **`dim_person`**: Obsahuje údaje o osobách (hercoch a režiséroch) vrátane ich mena, výšky, dátumu narodenia a známych filmov.
- **`dim_genre`**: Zahrňuje informácie o žánrovom zaradení filmov.
- **`dim_location`**: Obsahuje geografické údaje o krajinách, kde boli filmy produkované.

Štruktúra hviezdicového modelu je znázornená na diagrame nižšie. Diagram ukazuje prepojenia medzi faktovou tabuľkou a dimenziami, čo zjednodušuje pochopenie a implementáciu modelu.

<p align="center">
  <img src="https://github.com/user-attachments/assets/55fc0f61-1a83-40ee-81d6-680cbaad2083" alt="Star Schema">
  <br>
  <em>Obrázok 2 Schéma hviezdy pre Internet Movie Database</em>
</p>

---
## **3. ETL proces v Snowflake**
ETL proces pozostával z troch hlavných fáz: `extrahovanie` (Extract), `transformácia` (Transform) a `načítanie` (Load). Tento proces bol implementovaný v Snowflake s cieľom pripraviť zdrojové dáta zo staging vrstvy do viacdimenzionálneho modelu vhodného na analýzu a vizualizáciu.

---
### **3.1 Extract (Extrahovanie dát)**
Dáta zo zdrojového datasetu boli vyformotovane pomocou phpMyAdmin do formatu `.csv`, potom boli nahraté do Snowflake prostredníctvom interného stage úložiska s názvom `my_stage`. Stage v Snowflake slúži ako dočasné úložisko na import alebo export dát. Vytvorenie stage bolo zabezpečené príkazom:

#### Príklad kódu:


```sql
-- Vytvorenie databázy
CREATE DATABASE IMDb_DB;

-- Vytvorenie schémy pre staging tabuľky
CREATE SCHEMA IMDb_DB.staging;

USE SCHEMA IMDb_DB.staging;

CREATE OR REPLACE STAGE my_stage;

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
```
Do stage boli následne nahraté súbory obsahujúce údaje o filmoch, režiséroch, hercoch, žánroch a hodnoteniach. Dáta boli importované do staging tabuliek pomocou príkazu COPY INTO. Pre každú tabuľku sa použil podobný príkaz:

```sql
-- Kopírovanie do staging databázy
COPY INTO movie_staging
FROM @my_stage/movie.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);
```

V prípade nekonzistentných záznamov bol použitý parameter `ON_ERROR = 'CONTINUE'`, ktorý zabezpečil pokračovanie procesu bez prerušenia pri chybách.

---
### **3.2 Transfor (Transformácia dát pre filmové dáta)**

V tejto fáze sa údaje z tabuliek etapy čistia, transformujú a obohacujú, aby sa podporila efektívna analýza. Hlavným cieľom je pripraviť tabuľky dimenzií a tabuľku faktov, ktoré umožňujú podrobnú analýzu údajov týkajúcich sa filmu.

#### Dimensional Tables

`dim_time`: Táto tabuľka dimenzie obsahuje informácie o čase, konkrétne dátum, rok, mesiac a deň. Slúži na analýzu časových aspektov v dátach, ako sú ročné, mesačné alebo denný vývoj.

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

`dim_movie`: Táto tabuľka dimenzie uchováva informácie o filmoch, ako je názov, dĺžka trvania, jazyky, produkčná spoločnosť a ďalšie detaily, ktoré pomáhajú kategorizovať filmy a spravovať súvisiacie dáta.

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

`dim_person`: Táto tabuľka obsahuje údaje o osobách, ktoré sa podieľajú na tvorbe filmov, ako je meno, výška, dátum narodenia a známe filmy, v ktorých vystupovali. Pomáha spájať hercov, režisérov a iných tvorcov s filmami.

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

`dim_genre`: Táto tabuľka dimenzie obsahuje zoznam filmových žánrov. Každý žáner má svoj unikátny názov, čo umožňuje efektívne kategorizovať filmy podľa ich žánrového zaradenia.

```sql
CREATE TABLE dim_genre (
    genre_id INT IDENTITY(1,1) PRIMARY KEY,
    genre_name VARCHAR(20) UNIQUE
);

INSERT INTO dim_genre (genre_name)
SELECT DISTINCT genre
FROM genre_staging;
```

`dim_location`: Táto tabuľka dimenzie obsahuje informácie o lokalitách, konkrétne krajiny, ktoré sú spojené s filmami alebo ich natáčaním. Každá krajina je uvedená ako unikátny záznam v databáze, čo umožňuje sledovať geografické aspekty filmov.

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

`fact_movies`: Táto tabuľka faktov obsahuje kombinované informácie o filmoch, osobách, žánroch, časoch, lokalitách a ďalších metrikách. Skladá sa z kľúčov z rôznych dimenzií (filmy, osoby, žánre, čas a lokalita)

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
### **3.3 Load (Načítanie dát)**
Po úspešnom vytvorení dimenzií boli dáta nahraté do finálnej štruktúry. Na záver boli staging tabuľky odstránené, aby sa optimalizovalo využitie úložiska. Tento krok je kľúčový pre udržanie prehľadnosti a efektivity databázového prostredia:

```sql
DROP TABLE IF EXISTS movie_staging;
DROP TABLE IF EXISTS names_staging;
DROP TABLE IF EXISTS director_mapping_staging;
DROP TABLE IF EXISTS role_mapping_staging;
DROP TABLE IF EXISTS ratings_staging;
DROP TABLE IF EXISTS genre_staging;
```

Proces ETL Snowflake umožnil spracovanie neusporiadanych údajov z rôznych zdrojov do multidimenzionálneho modelu hviezdy. Tento proces zahŕňal čistenie, transformáciu a obohatenie informácií o filmoch, hercoch a ďalších dôležitých aspektoch. Výsledný dátový model umožňuje podrobnú analýzu preferencií divákov, hodnotenia filmov a ďalších metrík a slúži ako základ pre vizualizácie a správy, ktoré sú neoceniteľné pre manažérov a analytikov filmového priemyslu.

---
## **4 Vizualizácia dát**

Dashboard obsahuje `5 vizualizácií`, ktoré poskytujú základný prehľad o kľúčových metrikách a trendoch týkajúcich sa filmov, používateľov a ich hodnotení. Tieto vizualizácie odpovedajú na dôležité otázky a umožňujú lepšie pochopiť správanie používateľov, ich preferencie a interakcie s obsahom. Každá vizualizácia je navrhnutá tak, aby poskytovala hodnotné informácie pre analýzu a rozhodovanie.

### **Graf 1: 10 najlepších filmov podľa priemerného hodnotenia a celkového počtu hlasov**

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






