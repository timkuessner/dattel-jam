# Dattel Jam – Farming-System

## Steuerung
- **5**: Hacke
- **6**: Karottensamen
- **7**: Eimer
- **E**: Kontextaktion

## Ackerboden-Autotiling
Bearbeiteter Boden wird nicht mehr als horizontale/vertikale Einzelvariante behandelt.
Jede Zelle berechnet ihre vier direkten Nachbarn (oben, rechts, unten, links) als 4-Bit-Maske.
Dadurch existieren alle **16 möglichen Verbindungstypen**:

- Einzelstück
- 4 Endstücke
- 2 Geraden
- 4 Ecken
- 4 T-Stücke
- Kreuzung

Beim Hacken werden die neue Zelle und alle vier Nachbarn sofort neu berechnet. Dadurch verbinden sich Felder korrekt in jeder Form.

Die Visuals liegen in `assets/Tilemap/soil_autotile.png` als 4x4-Sheet mit 16 echten 16x16-Pixel-Tiles.
