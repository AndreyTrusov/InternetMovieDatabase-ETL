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
  <em>Obrázok 1 Entitno-relačná schéma AmazonBooks</em>
</p>

---
