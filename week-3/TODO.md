# Week 3 - status

## Gemaakt
- [x] 3.1 North-South: `applicationtier_sg` vernauwd tot poort 8080 (`../opentofu/main.tf`) - zelf-referentie voor LB-naar-instance, plus een bewust publieke regel voor de browser-naar-API-calls van de frontend (zie README.md voor de afweging)
- [x] 3.2 East-West: `rds_security_group` vernauwd tot de applicationtier-subnets (`../opentofu/rds-bootstrap/rds.tf`)
- [x] 3.3 GitHub Actions-pipeline voor OpenTofu toegevoegd (`../.github/workflows/opentofu.yml`), met plan-only op pull requests
- [x] 3.4 Advies infrastructure protection geschreven (micro segmentatie, North-South, immutable infra, network automation)
- [x] 3.3 AWS-credentials van de Learner Lab-sessie als GitHub secrets ingesteld (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`), screenshot in `images/`
- [x] 3.1 Bewijs: directe `curl` naar `app01:8080` (buiten de load balancer om) geeft een timeout (screenshot in `images/`)
- [x] 3.2 Bewijs: SG-regels in de console + TCP-test vanaf `app01` (gelukt) en `web01` (mislukt) (screenshots in `images/`)

- [x] 3.3 Bewijs: geslaagde pipeline-run op `uitwerkingen` (incl. twee echte CI-bugs gevonden en gefixt: hangende backend-prompt, ontbrekende variabelen - zie README.md)

- [x] 3.3 Bewijs: plan-only run op PR #140, apply-stap "skipped"

## Nog te doen
Geen, week 3 is compleet.

---
Hier houd ik bij wat ik nog moet doen.
