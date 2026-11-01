# Week 1 - status

## Gemaakt
- [x] 1.1 OpenTofu-code geschreven volgens de handleiding (`../opentofu/main.tf`, `bastion.tf`, `rds-bootstrap/rds.tf`)
- [x] 1.1 Netwerktekening (Mermaid-diagram) in README.md
- [x] 1.2 Advies Shared Responsibility Model geschreven
- [x] 1.3 Advies bastion host geschreven + daadwerkelijk in OpenTofu verwerkt (`bastion.tf`, SSH-regels aangepast)
- [x] AWS Learner Lab-sessie gestart, toegang bevestigd (screenshots in `images/`)
- [x] Keypair en S3-bucket voor de OpenTofu-state aangemaakt (screenshots in `images/`)
- [x] `labnotes.txt` en `opentofu/terraform.tfvars`/`backend.hcl` ingevuld (keyname, state-bucket, lab-profile, eigen IP)
- [x] `main.tf`/`bastion.tf`/`rds.tf` gebruiken nu `var.*` in plaats van `REPLACE_WITH_*`, en setup is herschreven in `setup/README.md`
- [x] `rds-bootstrap/rds.tf` los draaien, endpoint/db-vpc-id/route-table-id noteren, lokale state daarna verwijderen (opnieuw gedaan na de lab-reset van 31-10-2026, inclusief screenshots van de state-opruiming + citaat uit de handleiding)
- [x] Die drie waardes in `labnotes.txt` en `opentofu/terraform.tfvars` gezet
- [x] `tofu apply` op `main.tf` gedraaid (incl. een NAT gateway-race-condition gevonden en gefixt, zie `setup/README.md`)
- [x] Bewijs 1.1: load balancers "healthy" + werkende app via de presentation-lb DNS-naam (screenshots in `images/`)
- [x] Bewijs 1.3: SSH rechtstreeks naar `app01` mislukt, via de bastion host lukt het (screenshots in `images/`)
- [x] Mermaid-netwerktekening bijgewerkt naar de huidige architectuur (public subnets met bastion+beide LB's, NAT gateway, dual-stack) - geen Cloudcraft nodig

## Nog te doen
Geen, week 1 is compleet.

---
Hier houd ik bij wat ik nog moet doen.
