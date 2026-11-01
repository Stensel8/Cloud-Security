# Week 2 - status

## Gemaakt
- [x] 2.1 IAM-rol, policy en instance profile ontworpen (`../opentofu/iam.tf`) en gekoppeld aan `app01`/`app02`
- [x] 2.1 IAM-authenticatie op de RDS-instance aangezet (`iam_database_authentication_enabled`)
- [x] 2.1 Procedure beschreven (incl. SQL voor de IAM-databasegebruiker en token-verversing)
- [x] 2.3 Advies least privilege + Entra ID-federatie naar de AWS-console geschreven
- [x] 2.1 Bewijs: de rode `AccessDenied`-foutmelding bij `tofu apply` (screenshot in `images/`)
- [x] 2.2 Module 3 Knowledge Check (90/100) + Lab 3.1 doorlopen (policy-artefact in `lab-3.1-developergrouppolicy.json`, zie README.md voor de toelichting over AWS Academy's onbetrouwbare labs-voltooiingsregistratie)

## Nog te doen
- [ ] 2.1 Bewijs (optioneel): dezelfde stappen nog los in de AWS-console doorlopen (IAM-rol/policy aanmaken) - geeft hetzelfde resultaat als de apply-foutmelding, dus niet strikt nodig
