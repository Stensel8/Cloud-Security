# Week 7

Als afsluiting: een frameworkadvies voor SaxIT (7.1), een verdieping op NIST (7.2), een praktisch AVG-advies (7.3), en de AWS Academy-assessment (7.4).

## 7.1 Welk security framework voor SaxIT?

| Framework | Kerneigenschap | Scope |
| --- | --- | --- |
| **ISO/IEC 27001** | ISMS: verplicht proces van risicobeoordeling, beleid, audits. Certificeerbaar. | Hele organisatie, niet technologie-specifiek |
| **NIST CSF** | Vijf functies (Identify/Protect/Detect/Respond/Recover) met profiles/tiers voor volwassenheid. Niet certificeerbaar, wel breed herkend. | Hele organisatie, technologie-neutraal |
| **CIS Controls + Benchmarks** | 18 concrete technische maatregelen, met configuratie-benchmarks per platform (ook gebruikt in mijn DevOps Security-vak voor Kubernetes/Ubuntu) | Technisch/operationeel |
| **AVG/GDPR** | Wettelijke verplichting rond persoonsgegevens: rechtmatigheid, meldplicht, rechten van betrokkenen | Verplicht zodra er persoonsgegevens verwerkt worden (zie 7.3) |
| **SOC 2** (niet in de slides) | Auditrapport van vijf trust service criteria, veelgevraagd door SaaS-klanten in de VS | Vooral voor een SaaS-aanbieder als SaxIT die B2B-klanten moet overtuigen |

**Advies:** **NIST CSF** als overkoepelend kader, **CIS Controls/Benchmarks** voor de technische invulling. NIST geeft structuur die ook richting niet-technisch management werkt, CIS maakt het toetsbaar op de infra uit dit vak. ISO 27001 pas zodra klanten certificering eisen, zwaarder dan nodig in deze fase. **SOC 2** op de roadmap zodra SaxIT internationale/Amerikaanse SaaS-klanten wil overtuigen (daar vaak een harde eis, ISO 27001 is in Europa gangbaarder).

**Stappenplan:**

1. **Maand 1:** NIST CSF current profile opstellen (zie 7.2). Weken 1-6 zijn daar al grotendeels bewijs voor.
2. **Maand 2:** prioriteiten op de grootste gaps (geen centrale logging vóór week 6, nog geen TLS), target profile vaststellen.
3. **Maand 3-4:** CIS Benchmarks toepassen op productie (Linux/container-hardening) als Protect-invulling.
4. **Maand 5:** Detect/Respond-processen vastleggen (incident response plan 5.1 als startpunt), testen met tabletop-oefening.
5. **Doorlopend:** profiles jaarlijks herijken, ISO 27001/SOC 2 heroverwegen zodra klanten erom vragen.

Bronnen: [7 cybersecurity frameworks (BitSight)](https://www.bitsight.com/blog/7-cybersecurity-frameworks-to-reduce-cyber-risk), [NIST Cybersecurity Framework 2.0](https://www.nist.gov/cyberframework), [ISO/IEC 27001](https://www.iso.org/standard/27001), [CIS Controls](https://www.cisecurity.org/controls/v8), [SOC 2 (AICPA)](https://www.aicpa-cima.com/resources/landing/system-and-organization-controls-soc-suite-of-services).

## 7.2 NIST Cybersecurity Framework: de vijf functies voor SaxIT

| Functie | Betekenis | Voorbeelden |
| --- | --- | --- |
| **Identify** | Weten wat je hebt en welke risico's daarbij horen | Asset-inventaris + dataclassificatie (4.1); risicoanalyse per tier (tooling: AWS Config) |
| **Protect** | Een incident voorkomen/beperken | IAM least privilege i.p.v. gedeelde wachtwoorden (week 2); segmentatie (week 3) + S3-encryptie met eigen sleutel (4.3, tooling: KMS) |
| **Detect** | Een incident tijdig opmerken | GuardDuty/CloudWatch (6.2); IsolationForest-anomaliedetectie (6.5) structureel op de Kinesis-stream (6.1) |
| **Respond** | Gestructureerd reageren | Incident response plan met RACI (5.1); automatisch indammen via Lambda bij een GuardDuty-melding |
| **Recover** | Terug naar normaal, en ervan leren | Immutable infra: server vervangen via `tofu apply` i.p.v. handmatig opschonen (3.3); lessons learned na elk incident |

**Current profile van SaxIT:** sterk op **Protect** (least privilege, segmentatie, encryptie staan er), net begonnen met **Detect** (pas vanaf week 6). **Identify** deels (classificatie wel, volledige asset-inventaris niet). **Respond** heeft een plan op papier maar nog niets geoefend. **Recover** leunt op immutable infra, nooit in de praktijk getest. Kortom: fundamenten staan, operationaliseren (Detect/Respond echt oefenen) is de volgende stap.

Bronnen: [NIST Cybersecurity Framework 2.0: de vijf functies](https://www.nist.gov/cyberframework), [NIST CSF Profiles](https://www.nist.gov/cyberframework/profiles).

## 7.3 AVG: rechten van klanten praktisch inrichten

SaxIT bewaart klantgegevens in het CMDB en moet dus kunnen voldoen aan de AVG-rechten van betrokkenen: inzage, rectificatie, verwijdering, beperking, dataportabiliteit, bezwaar. Dat moet binnen een maand, met mogelijke verlenging.

Praktisch advies:

- Eén centraal verzoekenregister met automatische termijnbewaking, zodat niets blijft liggen.
- Dataclassificatie als basis (4.1): persoonsgegevens zijn al getagd ("Intern"/"Geheim"), dus snel te vinden welke objecten bij welke klant horen.
- Een gegevensregister van waar persoonsgegevens precies staan, RDS en S3. Zonder dat overzicht is een verwijderverzoek niet volledig uit te voeren.
- Verwijdering end-to-end testen, inclusief back-ups: een record dat nog drie maanden in een back-up staat is voor de AVG niet echt verwijderd.
- Logging van wie een verzoek afhandelde (CloudTrail/applicatielogging, 4.4/6.1), want accountability is zelf ook een AVG-verplichting.
- Een datalek van persoonsgegevens (rij 3 in 5.1's incidententabel) heeft een eigen meldplicht aan de AP binnen 72 uur. Hoort als apart stappenplan in het incident response plan.

Bronnen: [Rechten van betrokkenen (Autoriteit Persoonsgegevens)](https://www.autoriteitpersoonsgegevens.nl/onderwerpen/avg-nieuwe-europese-privacywetgeving/rechten-van-betrokkenen), [Data protection (Europese Commissie)](https://commission.europa.eu/law/law-topic/data-protection/data-protection-explained_en).

## 7.4 AWS Academy Cloud Security Foundations: course assessment

**Course Assessment: 100/100.** Volledig cijferoverzicht (ook Knowledge Checks per module en de labs): [`images/aws-academy-grades-overzicht.pdf`](images/aws-academy-grades-overzicht.pdf).

Let op: de rij "Labs" in dat overzicht blijft `- / 100` staan, ook voor labs die ik wél heb doorlopen - de losse lab-sandbox (Vocareum) en het Canvas-cijferboek syncen niet betrouwbaar, een bekend euvel in deze AWS Academy-module (zie ook week 2.2). Per lab staat het eigenlijke bewijs daarom bij de betreffende weekopdracht (2.2, 4.5, 6.3).
