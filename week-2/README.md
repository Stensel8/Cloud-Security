# Week 2: Identity and Access Management

Identity and access management (IAM) gaat over de vraag wie of wat bij welke resources mag, en onder welke voorwaarden. In de Security Pillar van het AWS Well-Architected Framework heeft het twee kanten: het beheren van identiteiten, van mensen en van machines, en het beheren van hun rechten [(Amazon Web Services, z.d.-b)](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/identity-and-access-management.html).

Het belangrijkste principe is least privilege: elke identiteit krijgt alleen de rechten die nodig zijn voor zijn taak. AWS raadt daarnaast aan om workloads tijdelijke credentials te geven via IAM-rollen in plaats van vaste access keys, en om medewerkers in te laten loggen via een identity provider in plaats van met losse IAM-gebruikers [(Amazon Web Services, z.d.-d)](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html).

In de beginsituatie gaat dat nog mis. Het databasewachtwoord staat in platte tekst in de user data van app01 en app02. Iedereen die de OpenTofu-code leest, of op de server de user data opvraagt, kent het wachtwoord.

Deze week bestaat uit drie opdrachten. Paragraaf 2.1 beschrijft hoe de applicatie zonder wachtwoord bij de database kan komen. Paragraaf 2.2 gaat over een lab en de knowledge check uit AWS Academy, en paragraaf 2.3 bevat een advies aan SaxIT over least privilege en het koppelen van Entra ID.

## 2.1 IAM-authenticatie naar RDS in plaats van een wachtwoord

Bij IAM-databaseauthenticatie logt de applicatie niet in met een wachtwoord, maar met een token. AWS maakt dat token aan op basis van de IAM-rol van de server, en het is 15 minuten geldig [(Amazon Web Services, z.d.-a)](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html). Er hoeft dan nergens meer een wachtwoord te staan.

In het Learner Lab mag ik zelf geen IAM-rollen en policies aanmaken. Ik heb de stappen daarom wel in de code uitgewerkt, maar `tofu apply` stopt bij de IAM-rol met een foutmelding. De opdracht vraagt ook om de stappen te laten zien, ook als ze een fout geven. Wat er wel en niet mag in het Learner Lab staat in [setup/README.md](../setup/README.md#wat-welniet-mag-in-de-learner-lab).

De stappen zijn:

1. Een IAM-rol voor de app-servers, `app-tier-rds-iam-role`, met een policy die alleen `rds-db:connect` toestaat. De policy geldt voor één databasegebruiker op deze ene database. Dit staat in `opentofu/iam.tf`:

   ```hcl
   Statement = [{
     Effect   = "Allow"
     Action   = "rds-db:connect"
     Resource = "arn:aws:rds-db:us-east-1:${data.aws_caller_identity.current.account_id}:dbuser:${data.aws_db_instance.cloudsecdb.resource_id}/app_iam_user"
   }]
   ```

2. Een instance profile dat die rol aan app01 en app02 koppelt. Omdat de rol niet aangemaakt kan worden, draaien de servers nu met het standaard LabInstanceProfile van het Learner Lab. Of de rol daarachter `rds-db:connect` toestaat, kon ik niet controleren, want het policy-document mag ik niet inzien.
3. IAM-authenticatie aanzetten op de database, met `iam_database_authentication_enabled = true` in `opentofu/rds-bootstrap/rds.tf`.
4. Een databasegebruiker die via IAM inlogt in plaats van met een wachtwoord. Dat kan niet met OpenTofu, dus dat gaat met SQL:

   ```sql
   CREATE USER 'app_iam_user'@'%' IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS';
   GRANT SELECT, INSERT, UPDATE, DELETE ON cloudsecdb.* TO 'app_iam_user'@'%';
   ```

5. De backend haalt een token op met `aws rds generate-db-auth-token` en gebruikt dat als wachtwoord. Omdat het token na 15 minuten verloopt, moet de backend het op tijd vernieuwen. Daarvoor is een aanpassing in de databaseverbinding van de backend nodig.

Daarna staat er geen wachtwoord meer in de code, in de user data of in git. De database-gebruiker mag ook alleen gegevens lezen en wijzigen, en bijvoorbeeld geen tabellen verwijderen.

![tofu apply stopt met AccessDenied op iam:CreateRole bij het aanmaken van app-tier-rds-iam-role](images/iam-createrole-accessdenied.png)

In de foutmelding is te zien dat de student-rol van het Learner Lab geen `iam:CreateRole` mag uitvoeren. Dat is de verwachte uitkomst.

Een eenvoudiger alternatief is om het wachtwoord te houden, maar het uit de code te halen en in AWS Secrets Manager te zetten. De backend haalt het daar op via dezelfde IAM-rol, en Secrets Manager kan het wachtwoord automatisch roteren [(Amazon Web Services, z.d.-c)](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html). Dat is sneller te bouwen, maar er blijft een wachtwoord bestaan.

## 2.2 AWS Academy: Lab 3.1 en de knowledge check

AWS Academy is de leeromgeving van AWS, met modules, labs en toetsen. Voor deze opdracht heb ik lab 3.1 doorlopen, "Using Resource-Based Policies to Secure an S3 Bucket". De policy van de ontwikkelaarsgroep uit het lab heb ik bewaard in [lab-3.1-developergrouppolicy.json](lab-3.1-developergrouppolicy.json). Die groep krijgt vooral lees- en lijstrechten, plus een aantal S3-acties om buckets aan te maken en af te schermen.

Voor de knowledge check van module 3 haalde ik 90 van de 100 punten. Het cijferoverzicht staat bij [week 7.4](../week-7/README.md).

In dat overzicht staat bij de labs `- / 100`, ook bij labs die wel af zijn. De lab-omgeving en het cijferboek lopen niet altijd gelijk, en dat zie ik ook bij medestudenten. Daarom heb ik de policy uit het lab bewaard als bewijs.

## 2.3 Advies: least privilege en Entra ID-federatie

### Least privilege

Mijn advies aan SaxIT is om least privilege overal toe te passen, net zoals bij de security groups uit week 1 en 3. Concreet betekent dat:

- elke rol een eigen, smalle policy geven in plaats van één brede rol voor alles. In 2.1 mag `app-tier-rds-iam-role` bijvoorbeeld alleen `rds-db:connect`, voor één databasegebruiker;
- servers en diensten rechten geven via rollen, zodat er geen vaste access keys in code of configuratie terechtkomen;
- rechten die tijdelijk ruim zijn gezet om iets werkend te krijgen, daarna weer beperken;
- in het CMDB-systeem zelf ervoor zorgen dat elke klant alleen bij zijn eigen gegevens kan.

### Entra ID koppelen aan AWS

SaxIT gebruikt al Microsoft Entra ID. Ik raad aan om medewerkers niet als losse IAM-gebruikers met eigen wachtwoorden in AWS aan te maken, maar Entra ID te koppelen aan AWS IAM Identity Center. Een medewerker logt dan in met zijn Entra ID-account en krijgt via zijn groep tijdelijke toegang tot de juiste AWS-accounts en rechten [(Amazon Web Services, z.d.-e)](https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html). Microsoft beschrijft stap voor stap hoe je die koppeling met SAML instelt [(Microsoft, 2026)](https://learn.microsoft.com/en-us/entra/identity/saas-apps/aws-single-sign-on-tutorial).

Dat heeft drie voordelen. Toegang regelen gebeurt op één plek: wie uit dienst gaat, verliest met zijn Entra ID-account ook de toegang tot AWS. MFA en de andere inlogregels uit Entra ID gelden meteen ook voor AWS. En er zijn geen losse IAM-wachtwoorden of access keys meer die iemand moet bijhouden.

## Bronnen

Amazon Web Services. (z.d.-a). *IAM database authentication for MariaDB, MySQL, and PostgreSQL*. Amazon RDS User Guide. https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html

Amazon Web Services. (z.d.-b). *Identity and access management*. Security Pillar: AWS Well-Architected Framework. https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/identity-and-access-management.html

Amazon Web Services. (z.d.-c). *Rotate AWS Secrets Manager secrets*. AWS Secrets Manager User Guide. https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html

Amazon Web Services. (z.d.-d). *Security best practices in IAM*. AWS Identity and Access Management User Guide. https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html

Amazon Web Services. (z.d.-e). *What is IAM Identity Center?* AWS IAM Identity Center User Guide. https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html

Microsoft. (2026, 26 mei). *Configure AWS IAM Identity Center (successor to AWS Single Sign-On) for single sign-on with Microsoft Entra ID*. Microsoft Learn. https://learn.microsoft.com/en-us/entra/identity/saas-apps/aws-single-sign-on-tutorial
