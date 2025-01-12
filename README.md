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

-- Vytvorenie tabuľky names (staging)
CREATE TABLE names_staging (
    id VARCHAR(10) PRIMARY KEY,
    name VARCHAR(100),
    height INT,
    date_of_birth DATE,
    known_for_movies VARCHAR(100)
);

-- Kopírovanie do staging databázy
COPY INTO movie_staging
FROM @my_stage/movie.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

```
Do stage boli následne nahraté súbory obsahujúce údaje o filmoch, režiséroch, hercoch, žánroch a hodnoteniach. Dáta boli importované do staging tabuliek pomocou príkazu COPY INTO. Pre každú tabuľku sa použil podobný príkaz:

```sql
COPY INTO movies_staging
FROM @my_stage/movies.csv
FILE_FORMAT = (TYPE = 'CSV' SKIP_HEADER = 1);
```

V prípade nekonzistentných záznamov bol použitý parameter `ON_ERROR = 'CONTINUE'`, ktorý zabezpečil pokračovanie procesu bez prerušenia pri chybách.

---
### **3.2 Transfor (Transformácia dát pre filmové dáta)**

V tejto fáze sa údaje z tabuliek etapy čistia, transformujú a obohacujú, aby sa podporila efektívna analýza. Hlavným cieľom je pripraviť tabuľky dimenzií a tabuľku faktov, ktoré umožňujú podrobnú analýzu údajov týkajúcich sa filmu.

#### Dimensional Tables

`dim_roles`: Táto dimenzia obsahuje informácie o filmových rolách vrátane mena herca alebo herečky, ich roku narodenia (získaného z dátumu narodenia) a výšky. Pozoruhodná transformácia zahŕňa spracovanie chýbajúcich dátumov narodenia alebo výšky. Roliam sa priradia jedinečné ID pomocou funkcie ROW_NUMBER(), usporiadané podľa movie_id a name_id z tabuľky role_mapping_staging. Tým sa zabezpečí, že každá rola je spojená s konkrétnymi filmami a hercami.

```sql
CREATE OR REPLACE TABLE dim_roles AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY rm.movie_id, rm.name_id) AS role_id,
    n.name,
    CASE 
        WHEN n.date_of_birth = 'NULL' OR n.date_of_birth IS NULL THEN NULL
        ELSE EXTRACT(YEAR FROM TO_DATE(n.date_of_birth, 'YYYY-MM-DD'))
    END AS birth_year,
    CASE 
        WHEN n.height = 'NULL' THEN NULL
        ELSE CAST(n.height AS INT)
    END AS height
FROM role_mapping_staging rm
JOIN names_staging n ON rm.name_id = n.id;
```

`dim_directors`: Podobne ako dim_roles, táto dimenzia obsahuje údaje o riaditeľoch, pričom spája ich mená, roky narodenia a výšky s jedinečnými ID priradenými prostredníctvom funkcie ROW_NUMBER(). 

```sql
CREATE OR REPLACE TABLE dim_directors AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY dm.movie_id, dm.name_id) AS director_id,
    n.name,
    CASE 
        WHEN n.date_of_birth = 'NULL' OR n.date_of_birth IS NULL THEN NULL
        ELSE EXTRACT(YEAR FROM TO_DATE(n.date_of_birth, 'YYYY-MM-DD'))
    END AS birth_year,
    CASE 
        WHEN n.height = 'NULL' THEN NULL
        ELSE CAST(n.height AS INT)
    END AS height
FROM director_mapping_staging dm
JOIN names_staging n ON dm.name_id = n.id;
```

`dim_genre`: Táto dimenzia obsahuje informácie o filmových žánroch. Každému žánru je priradené jedinečné ID. Táto transformácia je jednoduchšia, zoskupuje žánre podľa ich názvu a používa funkciu ROW_NUMBER() na jedinečnú identifikáciu.

```sql
CREATE OR REPLACE TABLE dim_genre AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY gs.genre) AS genre_id,
    gs.genre AS genre_name
FROM genre_staging gs
GROUP BY gs.genre;
```

`dim_date`: Táto dimenzia poskytuje podrobné informácie týkajúce sa dátumu pre hodnotenia filmov vrátane dňa, týždňa, mesiaca a roka. Transformuje časovú značku na podrobnejšie zložky, ako sú názvy dní, dní v týždni a mesiacov v číselnom aj reťazcovom formáte. 

```sql
CREATE OR REPLACE TABLE dim_date AS
SELECT
    ROW_NUMBER() OVER (ORDER BY CAST(timestamp AS DATE)) AS date_id,
    CAST(timestamp AS DATE) AS date,                    
    DATE_PART(day, timestamp) AS day,                   
    DATE_PART(dow, timestamp) + 1 AS dayOfWeek,        
    CASE DATE_PART(dow, timestamp) + 1
        WHEN 1 THEN 'Pondelok'
        WHEN 2 THEN 'Utorok'
        WHEN 3 THEN 'Streda'
        WHEN 4 THEN 'Štvrtok'
        WHEN 5 THEN 'Piatok'
        WHEN 6 THEN 'Sobota'
        WHEN 7 THEN 'Nedeľa'
    END AS dayOfWeekAsString,
    DATE_PART(month, timestamp) AS month,              
    CASE DATE_PART(month, timestamp)
        WHEN 1 THEN 'Január'
        WHEN 2 THEN 'Február'
        WHEN 3 THEN 'Marec'
        WHEN 4 THEN 'Apríl'
        WHEN 5 THEN 'Máj'
        WHEN 6 THEN 'Jún'
        WHEN 7 THEN 'Júl'
        WHEN 8 THEN 'August'
        WHEN 9 THEN 'September'
        WHEN 10 THEN 'Október'
        WHEN 11 THEN 'November'
        WHEN 12 THEN 'December'
    END AS monthAsString,
    DATE_PART(year, timestamp) AS year,                
    DATE_PART(week, timestamp) AS week,               
    DATE_PART(quarter, timestamp) AS quarter           
FROM RATINGS_STAGING
GROUP BY CAST(timestamp AS DATE), 
         DATE_PART(day, timestamp), 
         DATE_PART(dow, timestamp), 
         DATE_PART(month, timestamp), 
         DATE_PART(year, timestamp), 
         DATE_PART(week, timestamp), 
         DATE_PART(quarter, timestamp);
```

`dim_movies`: Táto tabuľka dimenzie obsahuje základné informácie o filmoch, ako je ich názov, rok vydania, trvanie, krajina, jazyk, celosvetový hrubý príjem a produkčná spoločnosť.

```sql
CREATE TABLE dim_movies (
    movie_id VARCHAR(20) PRIMARY KEY,
    title VARCHAR(200),
    release_year NUMBER(38,0),
    duration NUMBER(38,0),
    country VARCHAR(250),
    language VARCHAR(200),
    worldwide_gross_income VARCHAR(30),
    production_company VARCHAR(200)
);

INSERT INTO dim_movies
SELECT 
    ms.id AS movie_id,
    ms.title AS title,
    ms.year AS release_year,
    ms.duration AS duration,
    ms.country AS country,
    ms.languages AS language,
    ms.worlwide_gross_income AS worldwide_gross_income,
    ms.production_company AS production_company
FROM movie_staging ms;
```

---
### **3.3 Load (Načítanie dát)**
Po úspešnom vytvorení dimenzií pre filmy, roly, režisérov a ďalšie atribúty boli dáta nahraté do finálnej štruktúry. Na záver boli staging tabuľky odstránené, aby sa optimalizovalo využitie úložiska. Tento krok je kľúčový pre udržanie prehľadnosti a efektivity databázového prostredia:

```sql
DROP TABLE IF EXISTS role_mapping_staging;
DROP TABLE IF EXISTS director_mapping_staging;
DROP TABLE IF EXISTS genre_staging;
DROP TABLE IF EXISTS movie_staging;
DROP TABLE IF EXISTS names_staging;
DROP TABLE IF EXISTS ratings_staging;
```

Proces ETL Snowflake umožnil spracovanie neusporiadanych údajov z rôznych zdrojov do multidimenzionálneho modelu hviezdy. Tento proces zahŕňal čistenie, transformáciu a obohatenie informácií o filmoch, hercoch, režiséroch a ďalších dôležitých aspektoch. Výsledný dátový model umožňuje podrobnú analýzu preferencií divákov, hodnotenia filmov a ďalších metrík a slúži ako základ pre vizualizácie a správy, ktoré sú neoceniteľné pre manažérov a analytikov filmového priemyslu.

---
## **4 Vizualizácia dát**

Dashboard obsahuje `5 vizualizácií`, ktoré poskytujú základný prehľad o kľúčových metrikách a trendoch týkajúcich sa filmov, používateľov a ich hodnotení. Tieto vizualizácie odpovedajú na dôležité otázky a umožňujú lepšie pochopiť správanie používateľov, ich preferencie a interakcie s obsahom. Každá vizualizácia je navrhnutá tak, aby poskytovala hodnotné informácie pre analýzu a rozhodovanie.






