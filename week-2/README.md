# Week 2

In de beginsituatie staat het databasewachtwoord van `cloudsecdb` in platte tekst in `user_data` van `app01` en `app02` (zichtbaar voor iedereen die EC2-instance-metadata van die VM kan lezen, en zichtbaar in het Terraform-bestand zelf). Ik beschrijf hoe ik dat zonder wachtwoord oplos met IAM-authenticatie (2.1), doe de AWS Academy-labstof (2.2), en schrijf een advies over least privilege en Entra ID (2.3).

> **Status:** "in klad". 2.1 is een beschrijving + Terraform-code die in een gewone AWS-omgeving zou werken, maar in het Learner Lab vastloopt op een AccessDenied (precies wat de opdracht ook verwacht). 2.2 moet ik zelf nog doen in de AWS Academy-module.

## 2.1 IAM-authenticatie naar RDS in plaats van een wachtwoord

In de Learner Lab-module heb ik geen rechten om IAM-rollen of policies aan te maken (`iam:CreateRole`, `iam:CreatePolicy` staan niet toe op een studentenaccount). Dat betekent dat ik de stappen hieronder wél kan voorbereiden en in de AWS-console kan proberen uit te voeren, maar dat de definitieve `terraform apply` een rode `AccessDenied`-foutmelding geeft. Dat is ook precies wat de opdracht vraagt: de stappen laten zien, ondanks de foutmelding.

Zo zou ik app01/app02 zonder wachtwoord bij de database laten komen:

1. **IAM-rol en policy** ([`terraform/iam.tf`](../terraform/iam.tf)): een rol `app-tier-rds-iam-role` die EC2 mag aannemen, met een policy die alleen `rds-db:connect` toestaat, en dat ook nog eens afgebakend tot precies één database-gebruiker (`app_iam_user`) op precies deze RDS-instance. Geen bredere RDS- of AWS-rechten.
2. **Instance profile**: die rol wordt gekoppeld aan `app01` en `app02` via `iam_instance_profile` (zie de toevoeging in [`terraform/main.tf`](../terraform/main.tf)). Dat is de brug tussen een IAM-rol en een EC2-instance.
3. **IAM-authenticatie aanzetten op de RDS-instance**: `iam_database_authentication_enabled = true` in [`terraform/rds-bootstrap/rds.tf`](../terraform/rds-bootstrap/rds.tf).
4. **Een databasegebruiker die IAM-tokens accepteert**, aangemaakt via SQL (geen Terraform-resource voor MySQL-gebruikers binnen RDS zelf):
   ```sql
   CREATE USER 'app_iam_user'@'%' IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS';
   GRANT SELECT, INSERT, UPDATE, DELETE ON cloudsecdb.* TO 'app_iam_user'@'%';
   ```
5. **De applicatie zelf**: in plaats van `SPRING_DATASOURCE_PASSWORD=password123` in `user_data`, haalt de backend bij het opstarten (en periodiek opnieuw, want een IAM auth-token is maar 15 minuten geldig) een token op met `aws rds generate-db-auth-token --hostname <endpoint> --port 3306 --username app_iam_user`, en gebruikt dat token als wachtwoord. Spring Boot ondersteunt geen token-verversing in een gewone `DataSource` out-of-the-box; dat vraagt een kleine custom `DataSource`/`ConnectionProvider` die het token ververst vóór het verloopt, of een sidecar-proces dat de env-variabele herschrijft en de pool laat vernieuwen. Omdat de instance het IAM-token haalt via zijn eigen instance profile (stap 2), hoeft er nergens meer een AWS access key of wachtwoord in code, user-data of git te staan.

Een eenvoudiger alternatief, dat ik ook aan SaxIT zou noemen: het wachtwoord zelf laten staan, maar het uit Terraform/user-data halen en in **AWS Secrets Manager** zetten met automatische rotatie, en de applicatie het wachtwoord bij het opstarten laten ophalen via dezelfde instance profile. Minder "native" dan IAM-tokens, maar eenvoudiger te bouwen en nog steeds geen statisch wachtwoord meer in code.

**Nog te doen (bewijs):** printscreens van de AWS-console-stappen (IAM-rol aanmaken, policy toevoegen, instance profile koppelen aan `app01`), inclusief de rode foutmelding bij de uiteindelijke apply. Dat is wat de opdracht expliciet vraagt ("ondanks dat je rode foutmeldingen krijgt").

## 2.2 AWS Academy Cloud Security Foundations: Lab 3.1 en Knowledge check

Dit moet ik zelf doen in de AWS Academy-leeromgeving; dat kan ik niet namens jou uitvoeren, dat is online door de docent te controleren.

**Nog te doen:** Lab 3.1 en de bijbehorende Knowledge check afronden in de module *AWS Academy Cloud Security Foundations*, en het bewijsscherm hier plakken.

## 2.3 Advies: least privilege en Entra ID-federatie

**Least privilege.** Het principe van least access betekent dat elke identiteit (mens of service) precies genoeg rechten krijgt om zijn taak te doen, niet meer. Voor SaxIT is dat niet alleen een IAM-regel, maar ook hoe het hele ontwerp in elkaar steekt: de security groups uit week 1 en 3 zijn ook least privilege, maar dan op netwerkniveau. Mijn advies voor SaxIT, concreet voor deze casus:

- Elke rol krijgt een eigen, smalle policy in plaats van één brede "PowerUser"-rol voor alle app-servers. In dit ontwerp is dat bijvoorbeeld `app-tier-rds-iam-role`: alleen `rds-db:connect`, alleen op die ene databasegebruiker, niets anders.
- Rollen voor VM's/services (zoals de instance profile hierboven) in plaats van lange-termijn access keys die in configuratie of code terecht kunnen komen.
- Rechten regelmatig herzien: een rol die bij het opzetten van de omgeving breed was "om het werkend te krijgen" (zoals nu met het wachtwoord in `user_data`) moet daarna versmald worden, niet voor altijd zo blijven staan.
- Voor externe klanten van het CMDB-systeem (zie `Casus SaxIT.docx`): elke klant mag alleen bij zijn eigen tenant-data, nooit bij die van een andere klant. Dat is least privilege op applicatieniveau, net zo belangrijk als op infrastructuurniveau.

**Entra ID-federatie naar de AWS-console.** SaxIT gebruikt al Microsoft Entra ID (voorheen Azure AD) voor identiteiten. In plaats van losse IAM-gebruikers met eigen wachtwoorden in AWS aan te maken (weer een identiteitsbron om te beheren, weer een plek waar een wachtwoord kan uitlekken) zou ik Entra ID koppelen aan AWS via **IAM Identity Center** (voorheen AWS SSO) met SAML 2.0, of via directe **OIDC/SAML-federatie** naar IAM-rollen. Een medewerker logt dan in met zijn bestaande Entra ID-account en krijgt, via een groep in Entra ID die gekoppeld is aan een IAM-rol, tijdelijke AWS-credentials voor precies de rechten die bij die rol horen. Voordelen voor SaxIT: één plek voor onboarding/offboarding (iemand die uit dienst gaat, verliest automatisch ook zijn AWS-toegang zodra zijn Entra ID-account wordt uitgeschakeld), MFA en conditional access-beleid dat al in Entra ID staat werkt meteen door naar AWS, en er hoeven geen losse, soms vergeten IAM-gebruikers met eigen wachtwoorden bijgehouden te worden.

Bronnen: [AWS Well-Architected: Identity and access management](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/identity-and-access-management.html), [Principle of least privilege (Cloudflare)](https://www.cloudflare.com/learning/access-management/principle-of-least-privilege/), [IAM-authenticatie voor RDS](https://mafiaguy.medium.com/a-comprehensive-guide-to-iam-authentication-for-amazon-rds-instances-b1ac96c52233), [AWS IAM Identity Center: SAML/externe IdP](https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html), [Microsoft Entra ID federatie met AWS](https://learn.microsoft.com/en-us/entra/identity/saas-apps/amazon-web-service-tutorial).
