# Week 4

Dataclassificatie en S3-buckets per classificatie (4.1–4.2), een eigen (BYOK) KMS-sleutel voor de geheime bucket (4.3), logging en alerting op die bucket (4.4), de AWS Academy-labstof (4.5), en een advies over AVG en encryptie (4.6).

## 4.1 Dataclassificatie

| Classificatie | Voorbeelden (voor SaxIT's CMDB) | Motivatie |
| --- | --- | --- |
| **Openbaar** | Persberichten, marketingmateriaal, publieke productdocumentatie | Bedoeld om naar buiten te gaan; schade bij lekken is er niet, wel moet de integriteit gewaarborgd zijn (niemand mag het ongemerkt aanpassen) |
| **Intern** | Personeelsplanningen, interne processen, niet-gevoelige bedrijfsinformatie | Niet bedoeld voor klanten of publiek, maar een lek is geen ramp; wel reputatieschade of concurrentienadeel mogelijk |
| **Geheim** | Klantgegevens in het CMDB (contactpersonen, asset-inventarissen van klanten), inloggegevens, persoonsgegevens | Direct onder de AVG (zie 7.3), bedrijfsgevoelige informatie van klanten zelf; een lek is een meldingsplichtig datalek en kan klanten direct schaden |

De namen van de classificaties blijven Nederlands (dat zijn de officiële termen uit de opdracht), maar de AWS-resources zelf (bucketnamen, tags, variabelen in het script) zijn in het Engels, zoals gebruikelijk in infrastructuurcode: **Openbaar → `public`**, **Intern → `internal`**, **Geheim → `confidential`**.

Per categorie, concrete maatregelen in de cloudomgeving:

| Maatregel | Openbaar | Intern | Geheim |
| --- | --- | --- | --- |
| Encryptie in transit | HTTPS (aanbevolen, niet verplicht) | HTTPS verplicht | HTTPS verplicht + alleen interne routes |
| Encryptie at rest | SSE-S3 (standaard AES-256) | SSE-S3 (standaard AES-256) | SSE-KMS met eigen (BYOK) sleutel (4.3) |
| Toegangsbeheer (IAM) | Read voor hele organisatie | Read/write voor medewerkers, geen externe toegang | Alleen specifieke rollen/applicatiecomponenten, least privilege (zie week 2) |
| Logging en monitoring | Basis (CloudTrail management events) | CloudTrail + CloudWatch-metrics | CloudTrail **data events** op object-niveau + EventBridge-alert per download (4.4) |
| Data Loss Prevention (DLP) | Niet nodig | Macie periodiek (week 6.2) om te checken dat er geen gevoelige data in beland is | Macie structureel, plus de classificatie-tag-policy (4.2) die verkeerd geclassificeerde uploads blokkeert |

## 4.2 Drie buckets, één per classificatie

**Waarom een los bash-script in plaats van OpenTofu.** Eerst stonden de buckets, policies, encryptie, CloudTrail, EventBridge, SNS en het dashboard allemaal gewoon als OpenTofu-resources in `opentofu/data-protection.tf`. De AWS-provider leest bij ieder `aws_s3_bucket`-resource echter standaard ook de object lock-configuratie uit (een verouderd/computed attribuut, onderdeel van de normale Create/Read-cyclus van die resource) - en die ene leesactie is in de AWS Academy Learner Lab geblokkeerd door een Service Control Policy op organisatieniveau. Niet op te lossen met IAM-rechten op mijn eigen rol: dit is een org-brede restrictie. Het bucket zelf wordt wél gewoon aangemaakt, maar OpenTofu markeert 'm daardoor als "tainted", en een volgende `apply` probeert 'm dan te vervangen - wat weer exact dezelfde leesfout raakt, dus weer tainted wordt. Resultaat: een oneindige lus, of op zijn minst een hoop handmatig untainten en losse `-refresh=false`-applies om er doorheen te komen (zie [setup/README.md](../setup/README.md#wat-welniet-mag-in-de-learner-lab) voor hoe dat via OpenTofu wél lukt, mocht je dat willen zien).

Een gewone `aws s3api create-bucket` doet die extra leesactie nooit, en heeft dit probleem dus helemaal niet. Daarom staat dit stuk nu in [`week-4/scripts/data-protection-setup.sh`](scripts/data-protection-setup.sh), een idempotent AWS CLI-script (opnieuw draaien hergebruikt bestaande resources i.p.v. te falen). Alleen de BYOK KMS-sleutel (4.3, geen last van dit probleem) blijft in [`opentofu/data-protection.tf`](../opentofu/data-protection.tf) staan, via een vaste alias (`alias/saxit-confidential-byok`) zodat het script 'm kan opzoeken zonder een OpenTofu-output nodig te hebben. Draaien:

```bash
./week-4/scripts/data-protection-setup.sh <unieke-suffix> <mailadres-voor-de-alert>
```

Het script zet per classificatiebucket (`saxit-data-public-*`, `saxit-data-internal-*`, `saxit-data-confidential-*` - Engelse resource-namen, zie de vertaaltabel in 4.1 voor hoe die zich verhouden tot de Nederlandse classificatietermen uit de opdracht):

- **Standaardencryptie verplicht**: SSE-S3 voor public/internal, SSE-KMS met de eigen sleutel uit 4.3 voor confidential.
- **Een bucket policy die drie dingen afdwingt**: (1) alleen HTTPS, (2) een upload zonder de juiste `x-amz-server-side-encryption`-header wordt geweigerd, en (3) een object zonder de `classification`-tag die bij déze bucket hoort, wordt ook geweigerd. Zo kan een confidential bestand niet per ongeluk (of expres) als "public" getagd in de verkeerde bucket belanden.
- **Block Public Access volledig aan**: "Public" is hier een classificatie van het dóel van de data binnen SaxIT (voor iedereen binnen de organisatie leesbaar), geen publiek-op-internet bucket.

```bash
{"Sid":"DenyWrongClassificationTag","Effect":"Deny","Principal":"*","Action":"s3:PutObject","Resource":"$arn/*","Condition":{"StringNotEquals":{"s3:RequestObjectTag/classification":"$classification"}}}
```

Drie demobestanden staan al klaar in [`demo-files/`](demo-files/): [`public-press-release.txt`](demo-files/public-press-release.txt), [`internal-staff-planning.txt`](demo-files/internal-staff-planning.txt) en [`confidential-customer-data.txt`](demo-files/confidential-customer-data.txt) (met nepdata, geen echte klantgegevens). Die upload ik met de bijbehorende tag:

```bash
aws s3api put-object --bucket saxit-data-public-<suffix> --key public-press-release.txt \
  --body demo-files/public-press-release.txt --tagging "classification=public" --server-side-encryption AES256

aws s3api put-object --bucket saxit-data-confidential-<suffix> --key confidential-customer-data.txt \
  --body demo-files/confidential-customer-data.txt --tagging "classification=confidential" --server-side-encryption aws:kms --ssekms-key-id <kms-key-id>
```

**Hoe zorg ik dat een specifieke gebruiker alleen in bepaalde buckets mag schrijven?** Via een IAM-policy die, net als bij de RDS-rol in week 2.1, precies één of twee bucket-ARN's als `Resource` heeft in plaats van `*`. Bijvoorbeeld een rol voor de supportmedewerkers die alleen `s3:PutObject`/`s3:GetObject` mag op `saxit-data-internal-*`, en expliciet geen rechten op `saxit-data-confidential-*`. Dit kan ik in de Learner Lab niet aantonen (zelfde IAM-beperking als in week 2.1), maar het principe is identiek aan wat ik daar al heb uitgewerkt.

**Nog te doen (bewijs):** `tofu apply` (voor de KMS-sleutel) en daarna `week-4/scripts/data-protection-setup.sh` draaien, screenshots van de drie buckets met hun encryptie-instelling, en een mislukte upload-poging (verkeerde tag of geen encryptie) die door de policy geweigerd wordt.

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

Daarna zoekt [`week-4/scripts/data-protection-setup.sh`](scripts/data-protection-setup.sh) deze sleutel op via de vaste alias (`alias/saxit-confidential-byok`) en zet 'm als standaardencryptie op de geheime bucket (`aws s3api put-bucket-encryption` met `SSEAlgorithm: aws:kms` en dit `KMSMasterKeyID`) - zie 4.2 voor waarom dat via een los script gaat in plaats van een OpenTofu-resource.

**Nog te doen (bewijs):** screenshot van de KMS-sleutel in de AWS-console met status "Imported key material", en van de encryptie-instelling van de geheime bucket die naar die sleutel wijst.

## 4.4 Logging en alerting op de geheime bucket

Ook dit zet [`week-4/scripts/data-protection-setup.sh`](scripts/data-protection-setup.sh) neer (zie 4.2 voor waarom via een los script):

- Een **CloudTrail-trail** (`saxit-confidential-bucket-trail`) die specifiek **data events** (object-niveau, niet alleen management-events) logt voor de geheime bucket: elke `GetObject`, `PutObject`, etc. op dat ene bucket, naar een aparte logs-bucket (`saxit-cloudtrail-logs-*`).
- Een **EventBridge-rule** (`saxit-confidential-object-read`) die matcht op `GetObject`-events via CloudTrail voor die bucket, en die doorstuurt naar een **SNS-topic** (`saxit-confidential-bucket-alerts`) met een e-mail-abonnement. Dus een e-mail bij elke download van een geheim object.
- Een **CloudWatch-dashboard** (`saxit-s3-classification`) met het aantal objecten en de bucketgrootte per classificatie, zodat in één oogopslag te zien is hoeveel data er in elke categorie zit.

```json
{"source":["aws.s3"],"detail-type":["AWS API Call via CloudTrail"],"detail":{"eventSource":["s3.amazonaws.com"],"eventName":["GetObject"],"requestParameters":{"bucketName":["saxit-data-confidential-<suffix>"]}}}
```

**Als `aws events put-rule` een foutmelding geeft** (te weinig rechten in de Learner Lab, zelfde soort beperking als de IAM-rol in week 2.1): het script vangt dat expliciet af en print bovenstaand event pattern alsnog, zodat ik met een screenshot van die output kan laten zien hóe ik de rule zou instellen, ook al werkt de laatste schakel niet in deze beperkte omgeving. Vergelijkbaar met wat ik in 2.1 ook al moest doen. De SNS-topic-policy die EventBridge toestemming geeft om te publiceren (`events.amazonaws.com` als principal) zet het script zelf, dus die laatste koppeling hoeft geen aparte IAM-rol te hebben zoals bijvoorbeeld een Lambda-target dat wel zou vragen.

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
