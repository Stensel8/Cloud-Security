# Week 7: Security frameworks en de AVG

Een security framework is een vaste set afspraken en maatregelen waarmee een organisatie haar beveiliging inricht en kan laten zien waar ze staat. De bekendste zijn ISO/IEC 27001, het NIST Cybersecurity Framework en de CIS Controls. Ze verschillen vooral in hoe concreet ze zijn, en of je er een certificaat voor kunt halen.

Het NIST Cybersecurity Framework (CSF) 2.0 deelt security in zes functies in: govern, identify, protect, detect, respond en recover [(National Institute of Standards and Technology, 2024)](https://csrc.nist.gov/pubs/cswp/29/the-nist-cybersecurity-framework-csf-20/final). In de eerdere versie waren het er vijf. Govern is er in 2.0 bij gekomen, en gaat over de strategie, het beleid en de rollen rond security.

Deze week bestaat uit vier opdrachten. Paragraaf 7.1 bevat een advies aan SaxIT over een framework. Paragraaf 7.2 werkt de functies van NIST uit voor SaxIT, en paragraaf 7.3 bevat een advies over de rechten van klanten onder de AVG. Paragraaf 7.4 gaat over de afsluitende toets van AWS Academy.

## 7.1 Welk security framework voor SaxIT?

| Framework | Wat het is | Voor wie |
| --- | --- | --- |
| ISO/IEC 27001 | Eisen voor een managementsysteem voor informatiebeveiliging: risico's beoordelen, beleid maken, en regelmatig controleren en verbeteren. Je kunt er een certificaat voor halen [(International Organization for Standardization, 2022)](https://www.iso.org/standard/27001). | De hele organisatie, los van de technologie |
| NIST CSF 2.0 | Zes functies, met profielen om te beschrijven waar je nu staat en waar je naartoe wilt. Geen certificaat, maar wel breed bekend. | De hele organisatie, los van de technologie |
| CIS Controls | 18 concrete technische maatregelen, op volgorde van belang [(Center for Internet Security, z.d.)](https://www.cisecurity.org/controls/v8-1). Daarnaast zijn er CIS Benchmarks met instellingen per platform, die ik ook bij DevOps Security gebruik voor Kubernetes en Ubuntu. | Techniek en beheer |
| CSA Cloud Controls Matrix | 197 maatregelen in 17 domeinen, speciaal voor cloudomgevingen [(Cloud Security Alliance, z.d.)](https://cloudsecurityalliance.org/research/cloud-controls-matrix). | Cloudaanbieders en hun klanten |
| AVG | De wet voor persoonsgegevens: een grondslag hebben, datalekken melden, en de rechten van betrokkenen respecteren | Verplicht zodra je persoonsgegevens verwerkt (7.3) |
| SOC 2 | Een auditrapport over de beveiliging van een dienstverlener, op basis van de Trust Services Criteria van de AICPA [(AICPA & CIMA, z.d.)](https://www.aicpa-cima.com/resources/landing/system-and-organization-controls-soc-suite-of-services). | SaaS-aanbieders die zakelijke klanten moeten overtuigen |

Mijn advies aan SaxIT is om het NIST CSF als overkoepelend kader te gebruiken, en de CIS Controls en Benchmarks voor de technische invulling. NIST geeft structuur en is ook goed uit te leggen aan management. CIS maakt het toetsbaar op de infrastructuur van dit vak. Omdat SaxIT een cloudplatform aanbiedt, is de Cloud Controls Matrix een goede aanvulling om de cloudkant te controleren.

ISO 27001 raad ik pas aan als klanten om een certificaat vragen, omdat het voor deze fase zwaarder is dan nodig. SOC 2 komt pas in beeld als klanten om zo'n auditrapport vragen.

Een stappenplan:

1. **Maand 1:** het huidige profiel opstellen volgens NIST (zie 7.2). Het werk uit week 1 tot en met 6 is daarvoor al grotendeels het bewijs.
2. **Maand 2:** de grootste gaten kiezen, zoals het ontbreken van HTTPS, en het doelprofiel vaststellen.
3. **Maand 3 en 4:** de CIS Benchmarks toepassen op productie, zoals het hardenen van Linux en de containers.
4. **Maand 5:** de processen voor detectie en respons vastleggen, met het incident response plan uit 5.1 als begin, en ze oefenen met een tabletop-oefening.
5. **Daarna:** de profielen elk jaar opnieuw bekijken, en ISO 27001 of SOC 2 opnieuw overwegen als klanten erom vragen.

## 7.2 NIST Cybersecurity Framework: de functies voor SaxIT

| Functie | Betekenis | Voorbeelden bij SaxIT |
| --- | --- | --- |
| Govern | Strategie, beleid en rollen rond security vastleggen | Wie is waarvoor verantwoordelijk (1.2), de RACI uit 5.1, de keuze voor een framework (7.1) |
| Identify | Weten wat je hebt en welke risico's daarbij horen | Dataclassificatie (4.1), een overzicht van alle resources, bijvoorbeeld met AWS Config |
| Protect | Een incident voorkomen of de schade beperken | Least privilege met IAM-rollen (week 2), segmentatie (week 3), encryptie met een eigen sleutel (4.3) |
| Detect | Een incident op tijd opmerken | GuardDuty en CloudWatch (6.2), anomaliedetectie (6.5) op de logs uit Kinesis (6.1) |
| Respond | Gestructureerd reageren op een incident | Het incident response plan met RACI (5.1), automatisch indammen met een Lambda-functie bij een melding van GuardDuty |
| Recover | Terug naar normaal, en ervan leren | Servers vervangen via de pipeline in plaats van met de hand opruimen (3.3), een evaluatie na elk incident |

Het huidige profiel van SaxIT ziet er zo uit. Protect is het sterkst: least privilege, segmentatie en encryptie zijn er. Detect is net begonnen, pas in week 6. Identify is er deels: de data is geclassificeerd, maar er is nog geen volledig overzicht van alle resources. Govern is er ook deels, met de verdeling van verantwoordelijkheden uit 1.2 en 5.1, maar nog zonder vastgelegd beleid. Respond heeft een plan op papier dat nog niet is geoefend. En Recover leunt op het opnieuw uitrollen van de infrastructuur, wat nog niet is getest bij een echt incident.

De basis staat dus. De volgende stap is de processen voor detectie en respons echt in gebruik nemen en oefenen.

## 7.3 AVG: rechten van klanten praktisch inrichten

SaxIT bewaart klantgegevens in de CMDB en moet daarom de rechten van betrokkenen uit de AVG kunnen waarmaken. Dat zijn onder andere het recht op inzage, rectificatie, verwijdering, beperking van de verwerking, overdracht van gegevens en bezwaar. Op een verzoek moet SaxIT binnen een maand reageren. Bij ingewikkelde of veel verzoeken mag dat met twee maanden worden verlengd [(Europees Parlement en Raad van de Europese Unie, 2016)](https://eur-lex.europa.eu/legal-content/NL/TXT/?uri=CELEX:32016R0679).

Mijn advies om dat praktisch in te richten:

- Houd alle verzoeken bij in één register dat de termijnen bewaakt, zodat er niets blijft liggen.
- Gebruik de dataclassificatie uit 4.1. Persoonsgegevens zijn al als geheim getagd, dus het is snel te vinden welke bestanden bij welke klant horen.
- Leg vast waar alle persoonsgegevens precies staan, in RDS en in S3. Zonder dat overzicht kan een verwijderverzoek niet volledig worden uitgevoerd.
- Test het verwijderen van begin tot eind, inclusief de back-ups. Een record dat nog drie maanden in een back-up staat, is niet echt verwijderd.
- Log wie een verzoek heeft afgehandeld, met CloudTrail en logging in de applicatie (4.4 en 6.1). Ook kunnen aantonen dat je je aan de regels houdt, is een plicht onder de AVG.
- Neem in het incident response plan een apart stappenplan op voor een datalek met persoonsgegevens (rij 3 in de incidententabel van 5.1). Zo'n lek moet binnen 72 uur worden gemeld bij de Autoriteit Persoonsgegevens.

## 7.4 AWS Academy: course assessment

Voor de afsluitende course assessment van AWS Academy Cloud Security Foundations haalde ik 100 van de 100 punten. Het volledige cijferoverzicht, met de knowledge checks per module, staat in [`images/aws-academy-grades-overzicht.pdf`](images/aws-academy-grades-overzicht.pdf).

In dat overzicht staat bij de labs `- / 100`, ook bij labs die ik wel heb doorlopen. De lab-omgeving en het cijferboek lopen niet altijd gelijk (zie 2.2). Het bewijs per lab staat daarom bij de opdracht van die week: 2.2, 4.5 en 6.3.

## Bronnen

AICPA & CIMA. (z.d.). *System and Organization Controls: SOC suite of services*. https://www.aicpa-cima.com/resources/landing/system-and-organization-controls-soc-suite-of-services

Center for Internet Security. (z.d.). *CIS Critical Security Controls version 8.1*. https://www.cisecurity.org/controls/v8-1

Cloud Security Alliance. (z.d.). *Cloud Controls Matrix*. https://cloudsecurityalliance.org/research/cloud-controls-matrix

Europees Parlement en Raad van de Europese Unie. (2016). *Verordening (EU) 2016/679 van het Europees Parlement en de Raad van 27 april 2016 betreffende de bescherming van natuurlijke personen in verband met de verwerking van persoonsgegevens en betreffende het vrije verkeer van die gegevens en tot intrekking van Richtlijn 95/46/EG (algemene verordening gegevensbescherming)*. Publicatieblad van de Europese Unie, L 119. https://eur-lex.europa.eu/legal-content/NL/TXT/?uri=CELEX:32016R0679

International Organization for Standardization. (2022). *ISO/IEC 27001:2022 Information security, cybersecurity and privacy protection: Information security management systems: Requirements*. https://www.iso.org/standard/27001

National Institute of Standards and Technology. (2024). *The NIST Cybersecurity Framework (CSF) 2.0* (NIST Cybersecurity White Paper 29). https://csrc.nist.gov/pubs/cswp/29/the-nist-cybersecurity-framework-csf-20/final
