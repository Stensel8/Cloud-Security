# Week 4: Data protection

Data protection gaat over het beschermen van gegevens, waar ze ook staan. In de Security Pillar begint AWS daarbij met classificeren: eerst wordt bepaald hoe gevoelig de data is, en op basis daarvan worden de maatregelen gekozen. Daarna volgen encryptie bij opslag (at rest) en onderweg (in transit) [(Amazon Web Services, z.d.-a)](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/data-protection.html).

Voor S3 biedt AWS verschillende vormen van encryptie aan de serverkant. Bij SSE-S3 beheert AWS de sleutel volledig zelf. Bij SSE-KMS staat de sleutel in AWS Key Management Service (KMS), met een eigen toegangsbeleid [(Amazon Web Services, z.d.-d)](https://docs.aws.amazon.com/AmazonS3/latest/userguide/serv-side-encryption.html). In KMS kan ook eigen sleutelmateriaal worden geïmporteerd: bring your own key (BYOK). De klant blijft dan verantwoordelijk voor dat materiaal [(Amazon Web Services, z.d.-b)](https://docs.aws.amazon.com/kms/latest/developerguide/importing-keys.html).

Voor SaxIT geldt daarnaast de AVG. Artikel 32 verplicht passende technische en organisatorische maatregelen om persoonsgegevens te beveiligen, en noemt versleuteling daarbij met zoveel woorden [(Europees Parlement en Raad van de Europese Unie, 2016)](https://eur-lex.europa.eu/legal-content/NL/TXT/?uri=CELEX:32016R0679).

Deze week bestaat uit zes opdrachten. Paragraaf 4.1 beschrijft de classificatie van de data van SaxIT, en paragraaf 4.2 het aanmaken van een S3-bucket per classificatie. Paragraaf 4.3 gaat over een eigen sleutel voor de geheime bucket, en paragraaf 4.4 over logging en alerting. Paragraaf 4.5 gaat over een lab uit AWS Academy, en paragraaf 4.6 bevat een advies over de AVG en encryptie.

## 4.1 Dataclassificatie

Voor SaxIT gebruik ik drie classificaties:

| Classificatie | Voorbeelden | Waarom |
| --- | --- | --- |
| Openbaar | Persberichten, marketingmateriaal | Mag naar buiten. Een lek doet geen schade, maar de inhoud moet wel kloppen. |
| Intern | Personeelsplanning, interne processen | Niet bedoeld voor klanten of het publiek. Een lek is geen ramp, maar wel schadelijk voor de reputatie. |
| Geheim | Klantgegevens in de CMDB, inloggegevens, persoonsgegevens | Valt onder de AVG. Een lek is een datalek dat gemeld moet worden. |

In AWS gebruik ik de Engelse namen, omdat bucketnamen en tags in het Engels zijn: openbaar wordt `public`, intern wordt `internal` en geheim wordt `confidential`. Per classificatie horen er andere maatregelen bij:

| Maatregel | Openbaar | Intern | Geheim |
| --- | --- | --- | --- |
| Encryptie onderweg | HTTPS aanbevolen | HTTPS verplicht | HTTPS verplicht, alleen interne routes |
| Encryptie bij opslag | SSE-S3 | SSE-S3 | SSE-KMS met een eigen sleutel (4.3) |
| Toegang | Lezen voor de hele organisatie | Lezen en schrijven voor medewerkers | Alleen bepaalde rollen, least privilege (week 2) |
| Logging | CloudTrail management events | Ook CloudWatch-metrics | CloudTrail data events en een melding bij elke download (4.4) |
| Datalekpreventie | Niet nodig | Af en toe scannen met Macie (6.2) | Vast scannen met Macie, en uploads met de verkeerde tag weigeren (4.2) |

## 4.2 Drie buckets, één per classificatie

Voor deze opdracht heb ik per classificatie een eigen bucket gemaakt in S3, de opslagdienst van AWS. Zo kan elke bucket zijn eigen encryptie en toegangsregels krijgen.

Eerst stonden de buckets als resources in `opentofu/data-protection.tf`. Dat werkte niet in het Learner Lab: OpenTofu leest bij een bucket ook de instellingen voor object lock uit, en die leesactie is in het Learner Lab geblokkeerd. De bucket werd wel aangemaakt, maar OpenTofu zag hem als mislukt, en elke volgende `apply` liep op dezelfde fout vast. Hoe het met OpenTofu toch kan, staat in [setup/README.md](../setup/README.md#wat-welniet-mag-in-de-learner-lab).

Daarom maak ik de buckets nu aan met het bash-script [`scripts/data-protection-setup.sh`](scripts/data-protection-setup.sh), dat deze leesactie niet doet. Alleen de KMS-sleutel uit 4.3 staat nog in [`opentofu/data-protection.tf`](../opentofu/data-protection.tf). Het script maakt drie buckets aan, `saxit-data-public`, `saxit-data-internal` en `saxit-data-confidential`, en stelt voor elke bucket het volgende in:

- **Standaardencryptie:** SSE-S3 voor public en internal, en SSE-KMS met de eigen sleutel voor confidential.
- **Een bucket policy:** alleen HTTPS is toegestaan, en uploads zonder de juiste encryptie of zonder de tag die bij de bucket hoort, worden geweigerd.
- **Block Public Access:** staat volledig aan. "Public" betekent hier dat de hele organisatie het mag lezen, niet dat het op internet staat.

Door de regel voor de tag kan een geheim bestand niet per ongeluk in de verkeerde bucket terechtkomen. Een tag wordt meegegeven bij het uploaden [(Amazon Web Services, z.d.-f)](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-tagging.html). Dit is de regel, waarbij `$classification` per bucket wordt ingevuld:

```json
{"Sid":"DenyWrongClassificationTag","Effect":"Deny","Principal":"*","Action":"s3:PutObject","Resource":"$arn/*","Condition":{"StringNotEquals":{"s3:RequestObjectTag/classification":"$classification"}}}
```

![Uitvoer van data-protection-setup.sh: drie buckets met hun policies en encryptie](images/data-protection-script-output.png)

![De S3-console met de drie classificatiebuckets, de bucket voor de CloudTrail-logs en die voor de OpenTofu-state](images/s3-buckets-overzicht.png)

Voor de demo staan er drie bestanden met nepdata in [`demo-files/`](demo-files/), één per classificatie. Om de regel voor de tag te testen, heb ik een bestand met de tag `classification=confidential` naar de public-bucket geüpload. S3 weigert dat:

![Een upload met de tag classification=confidential naar de public-bucket](images/upload-verkeerde-tag.png)

![De upload mislukt met Access denied](images/upload-access-denied.png)

Een gebruiker beperken tot bepaalde buckets gaat met een IAM-policy die alleen die buckets als resource noemt, op dezelfde manier als de rol in 2.1. Dat kan ik in het Learner Lab niet laten zien, om dezelfde reden als in 2.1.

## 4.3 Bring your own key (BYOK) voor de geheime bucket

De geheime bucket gebruikt een KMS-sleutel met sleutelmateriaal dat ik zelf heb gemaakt, in plaats van een sleutel van AWS. In OpenTofu is dat een `aws_kms_external_key`: een sleutel zonder materiaal, waarin het materiaal daarna zelf wordt geïmporteerd. Volgens de documentatie van AWS bestaat dat uit de volgende stappen [(Amazon Web Services, z.d.-e)](https://docs.aws.amazon.com/kms/latest/developerguide/importing-keys-encrypt-key-material.html):

1. Lokaal 256 bits sleutelmateriaal aanmaken met OpenSSL.
2. Bij AWS een wrapping key en een import-token opvragen voor de sleutel.
3. Het sleutelmateriaal versleutelen met die wrapping key, zodat het nooit onversleuteld naar AWS gaat.
4. Het versleutelde materiaal importeren in KMS.
5. Het onversleutelde materiaal lokaal wissen.

Het script uit 4.2 zoekt de sleutel op via de alias `alias/saxit-confidential-byok` en stelt hem in als standaardencryptie voor de geheime bucket. Bij de precieze opties van de `aws kms`- en `openssl`-commando's heb ik hulp gehad van Claude.

![De terminal tijdens het importeren: parameters opvragen, het materiaal versleutelen en importeren](images/kms-import-terminal.png)

![De sleutel saxit-confidential-byok staat in KMS op Enabled](images/kms-key-enabled.png)

![De geheime bucket gebruikt standaard SSE-KMS met de sleutel saxit-confidential-byok](images/confidential-bucket-encryptie.png)

## 4.4 Logging en alerting op de geheime bucket

Voor de logging en alerting gebruik ik drie diensten van AWS. CloudTrail legt vast welke acties er in het account worden uitgevoerd. EventBridge kan op zulke acties reageren, en SNS verstuurt berichten, bijvoorbeeld per e-mail. Het script uit 4.2 zet deze onderdelen op:

- **Een CloudTrail-trail**, `saxit-confidential-bucket-trail`, die elke actie op bestanden in de geheime bucket logt (data events), naar een aparte bucket voor logs.
- **Een EventBridge-regel**, `saxit-confidential-object-read`, die reageert op elke download (`GetObject`) uit de geheime bucket en een bericht stuurt naar een SNS-topic. Dat topic stuurt bij elke download een e-mail.
- **Een CloudWatch-dashboard**, `saxit-s3-classification`, met het aantal bestanden en de grootte per classificatie.

![De bevestiging van het mail-abonnement op het SNS-topic](images/sns-subscription-confirmed.png)

Om de keten te testen, heb ik het demobestand met klantgegevens naar de geheime bucket geüpload en daarna weer gedownload.

![Het bestand confidential-customer-data.txt is geüpload naar de geheime bucket](images/upload-confidential-succeeded.png)

![Het bestand wordt weer gedownload](images/download-confidential-object.png)

Kort daarna kwam de alert-mail binnen, nog voordat het logbestand van CloudTrail in de bucket stond. In de mail staat het volledige CloudTrail-event, met de bucket, het bestand en de actie:

![De alert-mail met het CloudTrail-event: GetObject op confidential-customer-data.txt in de geheime bucket](images/cloudtrail-alert-mail.png)

Het CloudWatch-dashboard bleef leeg. S3 publiceert de opslagmetrics maar één keer per dag [(Amazon Web Services, z.d.-c)](https://docs.aws.amazon.com/AmazonS3/latest/userguide/cloudwatch-monitoring.html), en de buckets waren die dag pas aangemaakt. De widgets en bucketnamen staan wel goed ingesteld.

![Het dashboard saxit-s3-classification nog zonder gegevens](images/cloudwatch-dashboard-no-data.png)

## 4.5 AWS Academy: Lab 5.1 en de knowledge check

Voor deze opdracht heb ik lab 5.1 in AWS Academy doorlopen. Voor de knowledge check van module 5 haalde ik 100 van de 100 punten. Het cijferoverzicht staat bij [week 7.4](../week-7/README.md). Ook bij dit lab staat in het overzicht `- / 100`, om dezelfde reden als in 2.2.

## 4.6 Advies: AVG en encryptie op de S3-buckets

### Relatie met de AVG

De klantgegevens in de CMDB zijn persoonsgegevens, waardoor artikel 32 van de AVG van toepassing is. De maatregelen van deze week sluiten daarop aan. De classificatie (4.1) bepaalt welke data extra bescherming nodig heeft. Encryptie met een eigen sleutel (4.2 en 4.3) is de technische maatregel die de AVG noemt. De logging (4.4) laat zien wie wanneer bij welke data was. Dat helpt als er toch een datalek is: zo'n lek moet binnen 72 uur worden gemeld, en dan moet SaxIT weten wat er is gelekt (zie 5.1 en 7.3).

### Vormen van encryptie in S3

S3 biedt vier vormen van encryptie aan de serverkant, van minder naar meer controle voor SaxIT:

- **SSE-S3:** AWS beheert de sleutel volledig. Dat is het eenvoudigst, maar SaxIT heeft geen zicht op de sleutel.
- **SSE-KMS:** de sleutel staat in KMS, en SaxIT bepaalt wie hem mag gebruiken.
- **SSE-KMS met eigen sleutelmateriaal (BYOK):** hetzelfde als SSE-KMS, maar SaxIT heeft het materiaal zelf gemaakt en kan het ook weer verwijderen. Zolang het materiaal niet opnieuw wordt geïmporteerd, is de data dan niet meer te ontsleutelen.
- **SSE-C:** de klant geeft bij elk verzoek zelf de sleutel mee. Dat geeft de meeste controle, maar ook het meeste risico: wie de sleutel kwijtraakt, raakt de data kwijt.

### Advies

Mijn advies is SSE-S3 voor openbare en interne data, en SSE-KMS met eigen sleutelmateriaal voor de geheime data. Zo houdt SaxIT zelf de controle over de sleutel voor de gevoeligste gegevens.

Daarbij hoort één aanvulling op wat ik in 4.3 deed. Na het importeren heb ik het onversleutelde materiaal gewist. In productie moet SaxIT een kopie veilig buiten AWS bewaren, bijvoorbeeld offline in een kluis. AWS raadt dat ook aan, zodat de sleutel kan worden hersteld als er iets misgaat [(Amazon Web Services, z.d.-b)](https://docs.aws.amazon.com/kms/latest/developerguide/importing-keys.html).

## Bronnen

Amazon Web Services. (z.d.-a). *Data protection*. Security Pillar: AWS Well-Architected Framework. https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/data-protection.html

Amazon Web Services. (z.d.-b). *Importing key material for AWS KMS keys*. AWS Key Management Service Developer Guide. https://docs.aws.amazon.com/kms/latest/developerguide/importing-keys.html

Amazon Web Services. (z.d.-c). *Monitoring metrics with Amazon CloudWatch*. Amazon S3 User Guide. https://docs.aws.amazon.com/AmazonS3/latest/userguide/cloudwatch-monitoring.html

Amazon Web Services. (z.d.-d). *Protecting data with server-side encryption*. Amazon S3 User Guide. https://docs.aws.amazon.com/AmazonS3/latest/userguide/serv-side-encryption.html

Amazon Web Services. (z.d.-e). *Step 3: Encrypt the key material*. AWS Key Management Service Developer Guide. https://docs.aws.amazon.com/kms/latest/developerguide/importing-keys-encrypt-key-material.html

Amazon Web Services. (z.d.-f). *Tagging your objects*. Amazon S3 User Guide. https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-tagging.html

Europees Parlement en Raad van de Europese Unie. (2016). *Verordening (EU) 2016/679 van het Europees Parlement en de Raad van 27 april 2016 betreffende de bescherming van natuurlijke personen in verband met de verwerking van persoonsgegevens en betreffende het vrije verkeer van die gegevens en tot intrekking van Richtlijn 95/46/EG (algemene verordening gegevensbescherming)*. Publicatieblad van de Europese Unie, L 119. https://eur-lex.europa.eu/legal-content/NL/TXT/?uri=CELEX:32016R0679
