# Week 4

Dataclassificatie en S3-buckets per classificatie (4.1–4.2), een eigen (BYOK) KMS-sleutel voor de geheime bucket (4.3), logging en alerting op die bucket (4.4), de AWS Academy-labstof (4.5), en een advies over AVG en encryptie (4.6).

## 4.1 Dataclassificatie

| Classificatie | Voorbeelden (voor SaxIT's CMDB) | Motivatie |
| --- | --- | --- |
| **Openbaar** | Persberichten, marketingmateriaal, publieke productdocumentatie | Bedoeld om naar buiten te gaan; schade bij lekken is er niet, wel moet de integriteit gewaarborgd zijn (niemand mag het ongemerkt aanpassen) |
| **Intern** | Personeelsplanningen, interne processen, niet-gevoelige bedrijfsinformatie | Niet bedoeld voor klanten of publiek, maar een lek is geen ramp; wel reputatieschade of concurrentienadeel mogelijk |
| **Geheim** | Klantgegevens in het CMDB (contactpersonen, asset-inventarissen van klanten), inloggegevens, persoonsgegevens | Direct onder de AVG (zie 7.3), bedrijfsgevoelige informatie van klanten zelf; een lek is een meldingsplichtig datalek en kan klanten direct schaden |

Per categorie, concrete maatregelen in de cloudomgeving:

| Maatregel | Openbaar | Intern | Geheim |
| --- | --- | --- | --- |
| Encryptie in transit | HTTPS (aanbevolen, niet verplicht) | HTTPS verplicht | HTTPS verplicht + alleen interne routes |
| Encryptie at rest | SSE-S3 (standaard AES-256) | SSE-S3 (standaard AES-256) | SSE-KMS met eigen (BYOK) sleutel (4.3) |
| Toegangsbeheer (IAM) | Read voor hele organisatie | Read/write voor medewerkers, geen externe toegang | Alleen specifieke rollen/applicatiecomponenten, least privilege (zie week 2) |
| Logging en monitoring | Basis (CloudTrail management events) | CloudTrail + CloudWatch-metrics | CloudTrail **data events** op object-niveau + EventBridge-alert per download (4.4) |
| Data Loss Prevention (DLP) | Niet nodig | Macie periodiek (week 6.2) om te checken dat er geen gevoelige data in beland is | Macie structureel, plus de classificatie-tag-policy (4.2) die verkeerd geclassificeerde uploads blokkeert |

## 4.2 Drie buckets, één per classificatie

In [`opentofu/data-protection.tf`](../opentofu/data-protection.tf) staan drie buckets (`saxit-data-openbaar-*`, `saxit-data-intern-*`, `saxit-data-geheim-*`), elk met:

- **Standaardencryptie verplicht**: SSE-S3 voor openbaar/intern, SSE-KMS met de eigen sleutel uit 4.3 voor geheim.
- **Een bucket policy die twee dingen afdwingt**: (1) een upload zonder de juiste `x-amz-server-side-encryption`-header wordt geweigerd, en (2) een object zonder de `classificatie`-tag die bij déze bucket hoort, wordt ook geweigerd. Zo kan een geheim bestand niet per ongeluk (of expres) als "openbaar" getagd in de verkeerde bucket belanden.
- **Block Public Access volledig aan**: "Openbaar" is hier een classificatie van het dóel van de data binnen SaxIT (voor iedereen binnen de organisatie leesbaar), geen publiek-op-internet bucket.

```hcl
statement {
  sid    = "DenyWrongClassificationTag"
  effect = "Deny"
  actions   = ["s3:PutObject"]
  resources = ["${each.value.bucket_arn}/*"]
  condition {
    test     = "StringNotEquals"
    variable = "s3:RequestObjectTag/classificatie"
    values   = [each.value.classificatie]
  }
}
```

**Lab-eigenaardigheid bij `tofu apply`:** de buckets worden gewoon aangemaakt, maar OpenTofu/de AWS-provider geeft er een rode foutmelding bij ("reading ... object lock configuration: AccessDenied"). Dat komt door een Service Control Policy op organisatieniveau die `s3:GetBucketObjectLockConfiguration` blokkeert — een legacy/computed attribuut dat de provider automatisch probeert uit te lezen na het aanmaken, los van wat er in deze `.tf`-bestanden staat. De bucket en alle resources die ervan afhangen (policy, encryptie, public-access-block) werken gewoon; alleen die ene leesactie faalt, bij elke `plan`/`apply` opnieuw. Zie de tabel in [setup/README.md](../setup/README.md#wat-welniet-mag-in-de-learner-lab).

Drie demobestanden staan al klaar in [`demo-files/`](demo-files/): [`openbaar-persbericht.txt`](demo-files/openbaar-persbericht.txt), [`intern-personeelsplanning.txt`](demo-files/intern-personeelsplanning.txt) en [`geheim-klantgegevens.txt`](demo-files/geheim-klantgegevens.txt) (met nepdata, geen echte klantgegevens). Die upload ik met de bijbehorende tag:

```bash
aws s3api put-object --bucket saxit-data-openbaar-<suffix> --key openbaar-persbericht.txt \
  --body demo-files/openbaar-persbericht.txt --tagging "classificatie=openbaar" --server-side-encryption AES256

aws s3api put-object --bucket saxit-data-geheim-<suffix> --key geheim-klantgegevens.txt \
  --body demo-files/geheim-klantgegevens.txt --tagging "classificatie=geheim" --server-side-encryption aws:kms --ssekms-key-id <kms-key-id>
```

**Hoe zorg ik dat een specifieke gebruiker alleen in bepaalde buckets mag schrijven?** Via een IAM-policy die, net als bij de RDS-rol in week 2.1, precies één of twee bucket-ARN's als `Resource` heeft in plaats van `*`. Bijvoorbeeld een rol voor de supportmedewerkers die alleen `s3:PutObject`/`s3:GetObject` mag op `saxit-data-intern-*`, en expliciet geen rechten op `saxit-data-geheim-*`. Dit kan ik in de Learner Lab niet aantonen (zelfde IAM-beperking als in week 2.1), maar het principe is identiek aan wat ik daar al heb uitgewerkt.

**Nog te doen (bewijs):** `tofu apply`, screenshots van de drie buckets met hun encryptie-instelling, en een mislukte upload-poging (verkeerde tag of geen encryptie) die door de policy geweigerd wordt.

## 4.3 Bring your own key (BYOK) voor de geheime bucket

Voor de geheime bucket gebruik ik een KMS-sleutel met eigen, zelf gegenereerd keymateriaal (`aws_kms_external_key` in OpenTofu, origin `EXTERNAL`) in plaats van een door AWS beheerde sleutel. Het keymateriaal zelf genereer ik lokaal, nooit in de AWS-console:

```bash
# 1. Eigen 256-bit AES-sleutelmateriaal genereren met OpenSSL
openssl rand -out plaintext-key.bin 32

# 2. Wrapping-key en import-token bij AWS opvragen voor deze KMS-sleutel
aws kms get-parameters-for-import \
  --key-id <key-id-van-de-aws_kms_external_key> \
  --wrapping-algorithm RSAES_OAEP_SHA_256 \
  --wrapping-key-spec RSA_2048

# 3. Het eigen keymateriaal versleutelen met die wrapping-key (nooit onversleuteld versturen)
openssl pkeyutl -encrypt -in plaintext-key.bin -out encrypted-key-material.bin \
  -pubin -inkey wrapping-key.pem -pkeyopt rsa_padding_mode:oaep -pkeyopt rsa_oaep_md:sha256

# 4. Het versleutelde materiaal importeren
aws kms import-key-material \
  --key-id <key-id> \
  --encrypted-key-material fileb://encrypted-key-material.bin \
  --import-token fileb://import-token.bin \
  --expiration-model KEY_MATERIAL_DOES_NOT_EXPIRE

# 5. Het lokale plaintext-sleutelmateriaal direct veilig wissen
shred -u plaintext-key.bin
```

Daarna verwijst de `aws_s3_bucket_server_side_encryption_configuration` van de geheime bucket naar deze sleutel (`kms_master_key_id = aws_kms_external_key.geheim_byok.arn`), zie [`opentofu/data-protection.tf`](../opentofu/data-protection.tf).

**Nog te doen (bewijs):** screenshot van de KMS-sleutel in de AWS-console met status "Imported key material", en van de encryptie-instelling van de geheime bucket die naar die sleutel wijst.

## 4.4 Logging en alerting op de geheime bucket

In [`opentofu/data-protection.tf`](../opentofu/data-protection.tf):

- Een **CloudTrail-trail** die specifiek **data events** (object-niveau, niet alleen management-events) logt voor de geheime bucket: elke `GetObject`, `PutObject`, etc. op dat ene bucket.
- Een **EventBridge-rule** die matcht op `GetObject`-events via CloudTrail voor die bucket, en die doorstuurt naar een **SNS-topic** met een e-mail-abonnement. Dus een e-mail bij elke download van een geheim object.
- Een **CloudWatch-dashboard** (`saxit-s3-classificatie`) met het aantal objecten en de bucketgrootte per classificatie, zodat in één oogopslag te zien is hoeveel data er in elke categorie zit.

```hcl
resource "aws_cloudwatch_event_rule" "geheim_object_read" {
  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventName         = ["GetObject"]
      requestParameters = { bucketName = [aws_s3_bucket.geheim.id] }
    }
  })
}
```

**Als Eventbridge een IAM-foutmelding geeft** (te weinig rechten, net als bij de IAM-rol in week 2.1): de rule zelf staat dan nog steeds correct in OpenTofu/de console, alleen de uiteindelijke koppeling met het SNS-target kan in de Learner Lab stuklopen op `iam:PassRole`/`events:PutTargets`-rechten. In dat geval laat ik met een screenshot van de EventBridge-rule-configuratie zien hóe ik de rule zou instellen, ook al werkt de laatste schakel niet in deze beperkte omgeving. Vergelijkbaar met wat ik in 2.1 ook al moest doen.

**Nog te doen (bewijs):** een download van een object uit de geheime bucket, een screenshot van de bijbehorende regel in het CloudTrail-logbestand, een screenshot van de ontvangen e-mail-alert (of van de EventBridge-configuratie als die laatste stap vastloopt op rechten), en een screenshot van het CloudWatch-dashboard.

## 4.5 AWS Academy Cloud Security Foundations: Lab 5.1

**Nog te doen:** zelf af te ronden in de AWS Academy-leeromgeving, bewijsscherm hier plakken.

## 4.6 Advies: AVG en encryptie op de S3-buckets

**Relatie met de AVG.** De AVG verplicht een organisatie die persoonsgegevens verwerkt (SaxIT's klantgegevens in het CMDB, zie 4.1) om "passende technische en organisatorische maatregelen" te nemen (artikel 32 AVG), en noemt pseudonimisering en encryptie daarbij expliciet als voorbeeld. Dataclassificatie (4.1) is de eerste stap: zonder te weten wélke data persoonsgegevens zijn, kan SaxIT niet aantonen dat er passende maatregelen zijn genomen. Encryptie at rest (4.2) en een eigen sleutel voor de gevoeligste categorie (4.3) zijn daar de technische invulling van; de logging en alerting (4.4) ondersteunen zowel de meldplicht datalekken (binnen 72 uur weten wát er gelekt is, zie ook week 5.1 en 7.3) als de aantoonbaarheidsplicht (accountability) van de AVG: SaxIT moet kunnen laten zien wie wanneer bij welke data is geweest.

**De verschillende vormen van encryptie op S3, en waarom de ene veiliger is dan de andere:**

- **SSE-S3** (`AES256`): AWS beheert de sleutel volledig, inclusief rotatie. Eenvoudigst, maar SaxIT heeft geen enkele controle over of zicht op de sleutel zelf.
- **SSE-KMS** (door AWS beheerde sleutel): de sleutel staat in KMS, met een eigen toegangsbeleid (wie mag deze sleutel gebruiken om te ontsleutelen) en een audit-trail via CloudTrail van elk sleutelgebruik. Veiliger dan SSE-S3 omdat SaxIT nu kan afdwingen én loggen wíe de data mag ontsleutelen, los van wie toegang tot de bucket zelf heeft.
- **SSE-KMS met eigen (BYOK) keymateriaal** (4.3): zoals SSE-KMS, maar het keymateriaal is door SaxIT zelf gegenereerd en kan op elk moment ingetrokken worden door het materiaal te verwijderen uit KMS. Dan is de data onherstelbaar onleesbaar, zelfs voor AWS zelf. Dit geeft SaxIT een "crypto-shredding"-mogelijkheid (meteen alles onleesbaar maken) en volledige controle over de levenscyclus van de sleutel, wat nog een stap verder gaat dan SSE-KMS met een door AWS gegenereerde sleutel.
- **SSE-C** (door de klant meegegeven sleutel per request, niet gebruikt in dit ontwerp): nog meer controle, maar SaxIT moet dan zelf de sleutel bij elke aanvraag meesturen en veilig bewaren. Dat is meer eigen verantwoordelijkheid en meer kans op een menselijke fout (sleutel kwijt = data kwijt).

Voor de geheime bucket is SSE-KMS met eigen keymateriaal daarom de juiste keuze: het geeft SaxIT de audit-trail van KMS én de garantie dat alleen SaxIT zelf het keymateriaal ooit in bezit heeft gehad.

**De procedure voor het eigen geïmporteerde keymateriaal, samengevat:** het materiaal wordt nooit onversleuteld naar AWS gestuurd. SaxIT genereert het lokaal met OpenSSL, vraagt bij KMS een publieke wrapping-key en eenmalig import-token op, versleutelt het eigen materiaal daarmee, en pas dát versleutelde pakket gaat naar AWS, waar het met de bijbehorende privésleutel (die AWS nooit verlaat) weer wordt uitgepakt. Zo ziet niemand bij AWS ooit het keymateriaal in platte tekst, en kan SaxIT het sleutelmateriaal op elk moment weer verwijderen om de data definitief ontoegankelijk te maken.

Bronnen: [AWS Well-Architected: Data protection](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/data-protection.html), [AVG/GDPR uitgelegd (Europese Commissie)](https://commission.europa.eu/law/law-topic/data-protection/data-protection-explained_en), [Client-side encryption (AWS)](https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingClientSideEncryption.html), [BYOK: eigen keymateriaal importeren in KMS](https://docs.aws.amazon.com/kms/latest/developerguide/importing-keys.html), [Keymateriaal versleutelen voor import](https://docs.aws.amazon.com/kms/latest/developerguide/importing-keys-encrypt-key-material.html), [S3-encryptie met customer managed keys](https://medium.com/@dyavanapellisujal7/aws-s3-encryption-with-customer-managed-keys-using-sse-kms-for-secure-object-storage-045f6fddeea5), [S3 object tagging](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-tagging.html).
