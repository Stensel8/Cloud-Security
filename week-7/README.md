# Week 7

Als afsluiting: een frameworkadvies voor SaxIT (7.1), een verdieping op NIST (7.2), een praktisch AVG-advies (7.3), en de AWS Academy-assessment (7.4).

## 7.1 Welk security framework voor SaxIT?

| Framework | Kerneigenschap | Scope |
| --- | --- | --- |
| **ISO/IEC 27001** | Een managementsysteem voor informatiebeveiliging (ISMS): verplicht proces van risicobeoordeling, beleid, interne audits, continue verbetering. Certificeerbaar door een externe partij. | Hele organisatie, niet technologie-specifiek |
| **NIST Cybersecurity Framework (CSF)** | Vijf functies (Identify, Protect, Detect, Respond, Recover) met "profiles" en "tiers" om de huidige en gewenste volwassenheid te beschrijven. Niet certificeerbaar, wel breed herkend. | Hele organisatie, technologie-neutraal, veel gebruikt als gemeenschappelijke taal tussen techniek en management |
| **CIS Controls (+ Benchmarks)** | 18 prioriteitsgeordende, concrete technische maatregelen, met specifieke configuratie-benchmarks per besturingssysteem/platform (zoals ik in mijn andere vak, DevOps Security, gebruikte voor Kubernetes/Ubuntu-hardening) | Vooral technisch/operationeel, minder geschikt als enig organisatiebreed kader |
| **AVG/GDPR** | Geen security framework in de klassieke zin, maar een wettelijke verplichting rond persoonsgegevens: rechtmatigheid, dataminimalisatie, meldplicht datalekken, rechten van betrokkenen | Verplicht zodra er persoonsgegevens verwerkt worden (zie 7.3), ongeacht welk ander framework gekozen wordt |
| **SOC 2 (niet in de slides)** | Een auditrapport (geen certificering) van een externe accountant over vijf "trust service criteria" (security, availability, processing integrity, confidentiality, privacy), veelgevraagd door SaaS-klanten in de VS/internationaal als bewijs dat een leverancier security serieus neemt | Vooral relevant voor een SaaS-aanbieder zoals SaxIT die B2B-klanten moet overtuigen, minder voor interne IT |

**Mijn advies aan SaxIT:** het **NIST Cybersecurity Framework** als overkoepelend kader, aangevuld met de **CIS Controls/Benchmarks** voor de technische invulling. Reden: SaxIT lanceert een nieuw CMDB-product als SaaS en moet zowel intern structuur aanbrengen (NIST geeft de vijf functies en het volwassenheidsniveau, makkelijk uit te leggen aan niet-technisch management) als concreet, toetsbaar beleid hebben op de infrastructuur die ik in dit vak heb gebouwd (CIS Benchmarks voor Linux, Kubernetes/containers, AWS). ISO 27001 zou ik pas adviseren zodra klanten een formele certificering eisen. Dat is namelijk zwaarder (audit, documentatieverplichtingen) dan SaxIT in deze fase nodig heeft, en NIST dekt het proceskader al goeddeels af zonder die formele verplichting. **SOC 2** zou ik als secundair doel op de roadmap zetten zodra SaxIT internationale of Amerikaanse SaaS-klanten wil overtuigen: dat rapport is in die markt vaak een harde eis bij een leverancierskeuze, terwijl ISO 27001 in Europa gangbaarder is.

**Stappenplan en planning:**

1. **Maand 1:** NIST CSF "current profile" opstellen, dus vaststellen waar SaxIT nu staat per functie (zie 7.2). De uitwerkingen van dit vak (weken 1-6) zijn daar al een flink deel van het bewijs voor.
2. **Maand 2:** Prioriteiten bepalen op basis van de grootste gaps (bijvoorbeeld: nog geen centrale logging vóór week 6, nog geen TLS, zie week 5.3) en een "target profile" vaststellen.
3. **Maand 3–4:** CIS Benchmarks toepassen op de productie-infrastructuur (Linux-hardening, container-hardening) als technische invulling van de "Protect"-functie.
4. **Maand 5:** Detect/Respond-processen vastleggen (het incident response plan uit week 5.1 is hier het startpunt) en testen met een tabletop-oefening.
5. **Doorlopend:** jaarlijks de profiles herijken, en heroverwegen of ISO 27001-certificering of SOC 2 nodig is zodra klanten daarom vragen.

Bronnen: [7 cybersecurity frameworks (BitSight)](https://www.bitsight.com/blog/7-cybersecurity-frameworks-to-reduce-cyber-risk), [NIST Cybersecurity Framework 2.0](https://www.nist.gov/cyberframework), [ISO/IEC 27001](https://www.iso.org/standard/27001), [CIS Controls](https://www.cisecurity.org/controls/v8), [SOC 2 (AICPA)](https://www.aicpa-cima.com/resources/landing/system-and-organization-controls-soc-suite-of-services).

## 7.2 NIST Cybersecurity Framework: de vijf functies voor SaxIT

| Functie | Betekenis | Voorbeeld 1 (met tooling) | Voorbeeld 2 (met tooling) |
| --- | --- | --- | --- |
| **Identify** | Weten wat je hebt en welke risico's daarbij horen | Asset-inventaris van alle AWS-resources en dataclassificatie (week 4.1: Openbaar/Intern/Geheim) | Risicoanalyse per tier van de 3-tier omgeving (tooling: AWS Config voor een continu actuele inventaris van resources) |
| **Protect** | Maatregelen om een incident te voorkomen of te beperken | IAM least privilege en instance profiles i.p.v. gedeelde wachtwoorden (week 2) (tooling: AWS IAM Access Analyzer) | Netwerksegmentatie met security groups (week 3) en S3-encryptie met eigen sleutel (week 4.3) (tooling: AWS KMS) |
| **Detect** | Een incident (of de voortekenen ervan) tijdig opmerken | GuardDuty en CloudWatch-alarmen (week 6.2) | Log-analyse op anomalieën, zoals de IsolationForest-aanpak in week 6.5, structureel toegepast op de Kinesis-stream (week 6.1) |
| **Respond** | Gestructureerd reageren zodra een incident is vastgesteld | Het incident response plan met RACI en procesdiagram (week 5.1) | Geautomatiseerd indammen: bijvoorbeeld een Lambda-functie die bij een GuardDuty-melding automatisch een security group aanpast |
| **Recover** | Terug naar normale bedrijfsvoering, en ervan leren | Immutable infrastructure: een gecompromitteerde server vervangen via `terraform apply` in plaats van handmatig opschonen (week 3.3) | Evaluatie/"lessons learned" na elk incident, met het plan uit 5.1 bijwerken (tooling: een simpel incidentenregister/ticketsysteem) |

**Current NIST profile van SaxIT** (op basis van wat er in dit vak tot nu toe staat): SaxIT scoort relatief sterk op **Protect** (least privilege, segmentatie en encryptie zijn concreet uitgewerkt) en begint net met **Detect** (pas vanaf week 6 komen GuardDuty/CloudWatch/Kinesis in beeld). **Identify** is deels gedaan (dataclassificatie) maar mist nog een volledige asset-inventaris buiten deze ene proefopstelling. **Respond** heeft nu een plan op papier (week 5.1) maar nog geen geautomatiseerde of geoefende uitvoering. **Recover** leunt sterk op immutable infrastructure, wat een sterk startpunt is, maar is nooit in de praktijk getest (geen "gameday"/oefenincident gedaan). Kortom: SaxIT's huidige profile is "fundamenten staan, operationalisering (Detect/Respond in de praktijk oefenen) is de volgende stap".

Bronnen: [NIST Cybersecurity Framework 2.0: de vijf functies](https://www.nist.gov/cyberframework), [NIST CSF Profiles](https://www.nist.gov/cyberframework/profiles).

## 7.3 AVG: rechten van klanten praktisch inrichten

SaxIT bewaart klantgegevens in het CMDB-systeem en moet dus kunnen voldoen aan de AVG-rechten van betrokkenen: inzage, rectificatie, verwijdering ("recht om vergeten te worden"), beperking van verwerking, dataportabiliteit en bezwaar. Allemaal binnen een redelijke termijn (de AVG noemt een maand, met mogelijke verlenging).

Praktisch advies, gekoppeld aan wat er in dit vak al staat:

- **Eén centraal verzoekenregister/ticketsysteem** waar elk AVG-verzoek (inzage, verwijdering, etc.) binnenkomt, met een automatische termijnbewaking, zodat niets blijft liggen tot na de wettelijke termijn.
- **Dataclassificatie als basis** (week 4.1): omdat persoonsgegevens al apart geclassificeerd en getagd zijn ("Intern"/"Geheim"), is het technisch haalbaar om bij een verzoek snel te vinden wélke objecten in welke S3-buckets bij een specifieke klant/gebruiker horen, in plaats van alles handmatig te moeten doorzoeken.
- **Een "data map"/gegevensregister** van waar persoonsgegevens precies staan: de RDS-database (klantdata van het CMDB zelf) én de S3-buckets (gekoppelde documenten). Zonder zo'n overzicht is het onmogelijk om een verwijderverzoek volledig uit te voeren.
- **Verwijdering end-to-end testen**, inclusief back-ups: een "verwijderd" record dat nog drie maanden in een back-up staat, is voor de AVG nog niet echt verwijderd. SaxIT moet een bewaartermijnbeleid voor back-ups vaststellen dat hiermee rekening houdt.
- **Logging van wie een verzoek heeft afgehandeld** (CloudTrail/applicatielogging, zie week 4.4 en 6.1): aantoonbaarheid (accountability) is zelf ook een AVG-verplichting, niet alleen het uitvoeren van het verzoek.
- Dit sluit aan op het incident response plan uit 5.1: een datalek van persoonsgegevens (rij 3 in de incidententabel) heeft onder de AVG een eigen meldplicht aan de Autoriteit Persoonsgegevens binnen 72 uur. Dat hoort als apart stappenplan in het incident response plan te staan, gekoppeld aan de classificatie uit week 4.

Bronnen: [Rechten van betrokkenen (Autoriteit Persoonsgegevens)](https://www.autoriteitpersoonsgegevens.nl/themas/basis-avg/rechten-van-betrokkenen), [Data protection (Europese Commissie)](https://commission.europa.eu/law/law-topic/data-protection/data-protection-explained_en).

## 7.4 AWS Academy Cloud Security Foundations: course assessment

**Nog te doen:** zelf af te ronden in de AWS Academy-leeromgeving, bewijsscherm hier plakken.
