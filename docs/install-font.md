# Com instal·lar una typografia a Linux

Les tipografies són super divertides, però sempre que n'haig d'instal·lar una haig de recordar com punyetes es feia, per això escric aquest document.

Com tot a linux, es pot instal·lar localment o a nivell de sistema. Com que les typografies no fan mal a ningú, jo normalment les instal·lo a nivell de sistema - i com que omarchy té la seva font a nivell d'usuari, tampoc passa res - però probablement es pot fer a nivell usuari.

Aleshores, la utilitat que gestiona les fonts és (`fontconfig`)[https://en.wikipedia.org/wiki/Fontconfig] que té dues comandes rellevants:
- `fc-list` enumera totes les fonts instal·lades al sistema.
- `fc-cache` cerca totes les carpetes que normalment contenen les fonts.

Posem el cas que volem instal·lar la font per defecte de _LaTeX_, _New Computer Modern_:

## 1. Descarrega
La podem baixar del (CTAN)[https://ctan.org/pkg/newcomputermodern] _Comprehensive TeX Archive Network_. No fer-ho d'un lloc amb "reputació" ens pot dur a versions antigues de tipografia.
El document contidrà arxius `.tff` (_True Type Font_ el _legacy format_) o `.otf` (_Open Type Font_), que conté tota la definició de la tipografia.

## 2. Camins

La utilitat `fontconfig` té un fitxer XML on té definits tots els camins que ha de mirar. Aquest fitxer es troba a `/etc/fonts/fonts.conf`. Allà s'hi especifiquen tots els camins a nivell de sistema (`/usr/share/fonts/` i `/usr/local/share/fonts/`) i els de nivell d'usuari (`$XGD_DATA_PATH/fonts`) que la utilitat cercarà noves fonts.

Un cop descomprimit el fitxer amb la tipografia, la movem a qualsevol dels directoris dits, sempre millor els de nivell d'usuari que els de sistema.

## 3. Reload.

Executar `fc-cache` per recarregar totes les carpetes. Amb `fc-list | grep <nomdelafont> ` t'hauria d'apareixer exactament el camí on es troben les fonts.
