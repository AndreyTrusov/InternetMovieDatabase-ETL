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
## **2 Dimenzionálny model**
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












