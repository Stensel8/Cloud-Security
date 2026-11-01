# Week 4 - status

## Gemaakt
- [x] 4.1 Dataclassificatie uitgewerkt (Openbaar/Intern/Geheim, met maatregelen per categorie)
- [x] 4.2 AWS CLI-script voor drie buckets, encryptie, bucket-policies (encryptie + classificatietag verplicht) (`scripts/data-protection-setup.sh`, zie README.md voor waarom dit geen OpenTofu-resources zijn)
- [x] 4.2 Demobestanden per classificatie klaargezet (`demo-files/`)
- [x] 4.3 BYOK-procedure (OpenSSL + KMS-import) beschreven + `aws_kms_external_key` (`../opentofu/data-protection.tf`)
- [x] 4.4 CloudTrail (data events), EventBridge-rule, SNS-topic en CloudWatch-dashboard geschreven (`scripts/data-protection-setup.sh`)
- [x] 4.6 Advies AVG-koppeling en vergelijking encryptievormen geschreven

- [x] AWS Learner Lab: `tofu apply` + `scripts/data-protection-setup.sh` gedraaid
- [x] 4.2 Bewijs: buckets + geweigerde upload (verkeerde tag) via S3-console, screenshots in `images/`

- [x] 4.3 Bewijs: keymateriaal geïmporteerd, KMS-sleutel status "Enabled" (screenshots in `images/`)
- [x] 4.3 Bewijs: encryptie-instelling confidential-bucket wijst naar de sleutel (screenshot)
- [x] 4.4 Bewijs: download + alert-mail met volledige CloudTrail-event (screenshots in `images/`)

- [x] 4.5 Module 5 Knowledge Check (100/100), zie README.md

## Nog te doen
Geen, week 4 is compleet.

---
Hier houd ik bij wat ik nog moet doen.
