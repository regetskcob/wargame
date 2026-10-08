# App Store und TestFlight

Alles, was App Store Connect für Wargame braucht. Die Ordner folgen dem
Aufbau von `fastlane deliver`, die Dateien lassen sich aber genauso von Hand
in App Store Connect einfügen.

| Feld in App Store Connect | Datei |
| --- | --- |
| Name (max. 30) | `metadata/de-DE/name.txt` |
| Untertitel (max. 30) | `metadata/de-DE/subtitle.txt` |
| Werbetext (max. 170) | `metadata/de-DE/promotional_text.txt` |
| Beschreibung (max. 4000) | `metadata/de-DE/description.txt` |
| Schlüsselwörter (max. 100) | `metadata/de-DE/keywords.txt` |
| Neuerungen | `metadata/de-DE/release_notes.txt` |
| Support- und Marketing-URL | `metadata/de-DE/support_url.txt`, `marketing_url.txt` |
| Datenschutz-URL | `metadata/de-DE/privacy_url.txt` |
| Copyright, Kategorien | `metadata/copyright.txt`, `metadata/primary_*.txt` |
| Hinweise für die Prüfung | `metadata/review_notes.txt` |
| TestFlight: Beschreibung, Testhinweise | `metadata/de-DE/testflight.txt` |
| App-Icon 1024 × 1024, ohne Alpha | `icon/AppIcon-1024.png` |
| iPhone 6,9" (1320 × 2868) | `screenshots/de-DE/iphone-*.png` |
| iPad 13" (2752 × 2064) | `screenshots/de-DE/ipad-*.png` |

Apple skaliert die 6,9"- und 13"-Screenshots für alle kleineren Geräte, mehr
Größen braucht es nicht. Der Name „Wargame“ allein ist im App Store sehr
wahrscheinlich vergeben, deshalb „Wargame – Panzergefecht“. Die
Schlüsselwörter enthalten bewusst keine geschützten Namen wie Bundeswehr oder
Leopard, das verbietet Apple (Richtlinie 2.3.7).

## Screenshots neu erzeugen

Rohaufnahmen aus dem Simulator (iPhone 17 Pro Max, iPad Pro 13" quer) in
einen Ordner legen, die Namen stehen in `SHOTS` in `../tool/compose.py`:

```sh
pip3 install --user pillow
python3 store/tool/compose.py <ordner-mit-rohaufnahmen>
```

## Angaben in App Store Connect

**Datenschutz (App Privacy):** Kein Tracking. Erhoben und mit der Person
verknüpft, nur für die App-Funktion:

- Kontaktinformationen → E-Mail-Adresse (nur wer sein Konto sichert)
- Kennungen → Benutzer-ID (anonyme Kennung des Gastkontos)
- Nutzerinhalte → Gameplay-Inhalte (Rufname, Fahrzeug, Spielstände)
- Nutzungsdaten → Produktinteraktion (Statistiken, Runden, Wertung)

**Altersfreigabe:** Comic- oder Fantasy-Gewalt „häufig/intensiv“ (Panzer
werden zerstört, Infanterie wird überrollt), sonst überall „keine“. Ergibt
voraussichtlich 12+.

**Exportkontrolle:** In der `Info.plist` steht bereits
`ITSAppUsesNonExemptEncryption = false`, die Frage entfällt.

**Kategorie:** Spiele, Unterkategorien Action und Strategie.

## Vor der Einreichung offen

1. **Migration 0010 einspielen:** `supabase db push` legt die Funktion
   `delete_account` an. Ohne sie bricht „Konto löschen“ mit einer Meldung ab.
2. **Web-Deploy abwarten:** Erst danach ist die Datenschutz-URL
   `https://www.regetskcob.de/wargame/datenschutz/` erreichbar.
3. **Signieren:** Apple-ID in Xcode anmelden, Team unter Signing &
   Capabilities wählen, dann `flutter build ipa` und über Xcode oder
   Transporter hochladen.

In der App Privacy bleibt alles wie oben: Die Kamera liest nur QR-Codes auf
dem Gerät, dabei wird nichts erhoben.
