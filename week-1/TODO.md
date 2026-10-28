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

## Nog te doen
- [ ] `rds-bootstrap/rds.tf` los draaien, endpoint/db-vpc-id/route-table-id noteren, lokale state daarna verwijderen
- [ ] Die drie waardes in `labnotes.txt` en `opentofu/terraform.tfvars` zetten
- [ ] `tofu apply` op `main.tf` draaien, minimaal 10 min wachten
- [ ] Bewijs 1.1: load balancers "healthy" + werkende app via de presentation-lb DNS-naam (screenshot)
- [ ] Bewijs 1.3: SSH rechtstreeks naar `app01` moet mislukken, via de bastion host moet het lukken (screenshot van beide pogingen)
- [ ] Optioneel: netwerktekening ook even in Cloudcraft, als alternatief/aanvulling op het Mermaid-diagram
