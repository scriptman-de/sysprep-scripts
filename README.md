# sysprep-scripts
Scripts für das Windows 10 offline servicing

## Ordner im Verzeichnis
* __ISO__: Hier sind alle unveränderten ISOs der Betriebssysteme wie sie original aus den Downloadportalen heruntergeladen wurden.
* __WIM__: Hier sind alle unveränderten Grundimages der einzelnen Betriebssysteme gespeichert. Folgende Punkte sind zu beachten:
  * Die Bezeichnung ist immer: ``*Edition*-*Release*-base.wim`` (edu-1903-base.wim) __ACHTUNG:__ Das Script bis 1809 erwartet ``win10edu-1809-base.wim``

  * Das erste Image ist die Basisversion aus der install.wim des Originaldatenträgers. Das zweite Image ist die erste Anpassung (AppX entfernt, etc.)

## WIM-Dateien
Die wim-Dateien sind die vom Skript angepassten Images. Die Benamung erfolgt nach dem Muster ``*Edition*-*Release*-*Erstellungsdatum*[-*Erweiterte-Kennung*].wim`` (edu-1903-20190901[-full|-audit].wim)

Die Datei ``install-full.wim`` ist für die Verwendung auf dem Installations-USB-Stick vorgesehen. In ihr werden alle funktionierenden Vollinstallationen (im Sysprep) gespeichert.