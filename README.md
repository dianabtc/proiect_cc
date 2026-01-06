# proiect_cc

USER: creeaza & vede rezervarile proprii
ADMIN: gestioneaza sali + vede/anuleaza orice rezervare

Business logic:

1. Gestionare sali (Event Halls)
creare sala (ADMIN)
editare sala (ADMIN)
stergere sala (ADMIN)
listare sali (PUBLIC)

2. Verificare disponibilitate (availability)
O rezervare este valida DOAR daca:
- nu exista o alta rezervare activa care se suprapune pe acelasi interval orar

3. Creare rezervari (USER)

4. Autorizare pe roluri
Rol	Drepturi
USER	creeaza rezervari, vede doar rezervarile proprii
ADMIN	vede toate rezervarile, gestioneaza sali

5. Anulare rezervare
USER - poate anula doar rezervarile lui
ADMIN - poate anula orice rezervare