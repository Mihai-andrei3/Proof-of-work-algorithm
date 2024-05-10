Nume: Ghita Mihai-Andrei
Grupă: 332CC

# # Tema 2 - Implementarea CUDA a algoritmului de consens Proof of Work din cadrul Bitcoin

## Organizare
***
### 1.Ce am invatat din aceasta tema:
* Am invatat despre structura unui blockchain si cum comunica nodurile intre ele
* Am aprofunat cunostintele legate de programarea pe GPU, folosind Cuda 


### 2. Explicatii solutie:
* Am pornit de la varianta de cod pentru CPU, si am adaptat pasii pentru gasirea nonce-ului la programarea pe GPU, unde principala diferenta a fost paralelizarea for-ului, astfel incat fiecare thread sa contina un nonce. 
* Pentru un speed-up mai mare am ales sa verific mai intai daca a fost gasit un nonce, folosindu-ma de un flag global, iar in caz afirmativ se iese din functie fara a mai calcula hash-ul. Acest lucru a scazut timpul de rulare de la o secunda si putin la aproximativ 0.14s (media a 10 rulari).
* Astfel, fata de timpul de rulare pe CPU am obtinut un timp de executie de 14 ori mai rapid
***
### Implementare

* Toate cerintele temei au fost implementate
* Dificulatile principale au venit la lucrul cu pointerii, deoarece n am mai lucrat de mult in C si la alegerea parametrilor pentru functia findNonce(), astfel incat sa pot sa retin rezultatele si sa am toate variabilele necesare pe GPU.
***
### Resurse utilizate

Laboratoarele de ASC de CUDA, in special laboratorul 4.
