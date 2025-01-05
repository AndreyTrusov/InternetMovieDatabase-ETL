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
Navrhnutý bol **hviezdicový model (star schema)**, pre efektívnu analýzu kde centrálny bod predstavuje faktová tabuľka **`fact_ratings`**, ktorá je prepojená s nasledujúcimi dimenziami:

- **`dim_movies`**: Obsahuje podrobné informácie o filmoch (názov, rok vydania, dĺžka, krajina pôvodu, príjmy, produkčná spoločnosť, jazyky).
- **`dim_directors`**: Obsahuje údaje o režiséroch filmov, vrátane ich mena, roku narodenia a výšky.
- **`dim_roles`**: Obsahuje informácie o hercoch a ich úlohách, vrátane mena, roku narodenia a výšky.
- **`dim_genre`**: Zahrňuje informácie o žánrovom zaradení filmov.
- **`dim_date`**: Obsahuje časové údaje (deň, mesiac, rok) vrátane textového aj číselného formátu.

Štruktúra hviezdicového modelu je znázornená na diagrame nižšie. Diagram ukazuje prepojenia medzi faktovou tabuľkou a dimenziami, čo zjednodušuje pochopenie a implementáciu modelu.
<p align="center">
  <img src="https://github.com/user-attachments/assets/310c2379-f491-4770-a987-9c5035bf622f" alt="Star Schema">
  <br>
  <em>Obrázok 2 Schéma hviezdy pre Internet Movie Database</em>
</p>

---
## **3. ETL proces v Snowflake**
ETL proces pozostával z troch hlavných fáz: `extrahovanie` (Extract), `transformácia` (Transform) a `načítanie` (Load). Tento proces bol implementovaný v Snowflake s cieľom pripraviť zdrojové dáta zo staging vrstvy do viacdimenzionálneho modelu vhodného na analýzu a vizualizáciu.

---
### **3.1 Extract (Extrahovanie dát)**
Dáta zo zdrojového datasetu (formát `.csv`) boli najprv nahraté do Snowflake prostredníctvom interného stage úložiska s názvom `my_stage`. Stage v Snowflake slúži ako dočasné úložisko na import alebo export dát. Vytvorenie stage bolo zabezpečené príkazom:

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
```
Do stage boli následne nahraté súbory obsahujúce údaje o filmoch, režiséroch, hercoch, žánroch a hodnoteniach. Dáta boli importované do staging tabuliek pomocou príkazu COPY INTO. Pre každú tabuľku sa použil podobný príkaz:

```sql
COPY INTO movies_staging
FROM @my_stage/movies.csv
FILE_FORMAT = (TYPE = 'CSV' SKIP_HEADER = 1);
```

V prípade nekonzistentných záznamov bol použitý parameter `ON_ERROR = 'CONTINUE'`, ktorý zabezpečil pokračovanie procesu bez prerušenia pri chybách.












