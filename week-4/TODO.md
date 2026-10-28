# Week 4 - status

## Gemaakt
- [x] 4.1 Dataclassificatie uitgewerkt (Openbaar/Intern/Geheim, met maatregelen per categorie)
- [x] 4.2 Terraform voor drie buckets, encryptie, bucket-policies (encryptie + classificatietag verplicht) (`../terraform/data-protection.tf`)
- [x] 4.2 Demobestanden per classificatie klaargezet (`demo-files/`)
- [x] 4.3 BYOK-procedure (OpenSSL + KMS-import) beschreven + `aws_kms_external_key`
- [x] 4.4 CloudTrail (data events), EventBridge-rule, SNS-topic en CloudWatch-dashboard geschreven
- [x] 4.6 Advies AVG-koppeling en vergelijking encryptievormen geschreven

## Nog te doen
- [ ] AWS Learner Lab: `tofu apply` met een unieke `bucket_suffix` en een echt e-mailadres voor de SNS-alert
- [ ] 4.2 Bewijs: de drie buckets met hun encryptie-instelling, en een geweigerde upload (verkeerde tag/geen encryptie)
- [ ] 4.3 Bewijs: KMS-sleutel met status "Imported key material", en de encryptie-instelling van de geheime bucket die ernaar wijst
- [ ] 4.4 Bewijs: CloudTrail-logregel van een download, de e-mail-alert (of de EventBridge-configuratie als die laatste stap op rechten vastloopt), en het CloudWatch-dashboard
- [ ] 4.5 AWS Academy Cloud Security Foundations: Lab 5.1 zelf afronden, bewijsscherm in README.md plakken
