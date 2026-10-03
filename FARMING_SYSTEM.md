# Dattel Jam – Farming-System

## Steuerung
- **Inventar-Slot anklicken**: Hacke, Karottensamen oder Eimer auswählen.
- Ein zweiter Klick auf denselben ausgewählten Gegenstand legt ihn wieder ab.
- **E**: Kontextaktion mit dem ausgewählten Gegenstand.
- Die alten festen Tasten **5 / 6 / 7** werden nicht mehr benutzt.

## Bepflanzbare Gras-Tiles
Die Hacke funktioniert auf beiden im Projekt verwendeten Gras-Varianten:
- normales grünes Gras
- grünes Gras mit dunkelgrünen Blättern/Grashalmen

Diese beiden Grasvarianten werden sowohl aus dem Town- als auch aus dem Water-Tileset erkannt.

## Ackerboden-Autotiling
Bearbeiteter Boden wird nicht mehr als horizontale/vertikale Einzelvariante behandelt.
Jede Zelle berechnet ihre vier direkten Nachbarn (oben, rechts, unten, links) als 4-Bit-Maske.
Dadurch existieren alle **16 möglichen Verbindungstypen**.

Beim Hacken werden die neue Zelle und alle vier Nachbarn sofort neu berechnet. Dadurch verbinden sich Felder korrekt in jeder Form.

Die Visuals liegen in `assets/Tilemap/soil_autotile.png` als 4x4-Sheet mit 16 echten 16x16-Pixel-Tiles.
