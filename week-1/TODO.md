# Week 1 - status

## Gemaakt
- [x] 1.1 OpenTofu-code geschreven volgens de handleiding (`../terraform/main.tf`, `bastion.tf`, `rds-bootstrap/rds.tf`)
- [x] 1.1 Netwerktekening (Mermaid-diagram) in README.md
- [x] 1.2 Advies Shared Responsibility Model geschreven
- [x] 1.3 Advies bastion host geschreven + daadwerkelijk in OpenTofu verwerkt (`bastion.tf`, SSH-regels aangepast)

## Nog te doen
- [ ] AWS Learner Lab opzetten: keypair aanmaken, S3-bucket voor de OpenTofu-state, `labnotes.txt` bijhouden
- [ ] `rds-bootstrap/rds.tf` los draaien, endpoint noteren, lokale state daarna verwijderen
- [ ] `REPLACE_WITH_*`-placeholders in `main.tf`/`bastion.tf` invullen (keyname, eigen IP, db-vpc-id, db-route-table-id, rds-endpoint, state-bucket, lab-profile)
- [ ] `tofu apply` draaien, minimaal 10 min wachten
- [ ] Bewijs 1.1: load balancers "healthy" + werkende app via de presentation-lb DNS-naam (screenshot)
- [ ] Bewijs 1.3: SSH rechtstreeks naar `app01` moet mislukken, via de bastion host moet het lukken (screenshot van beide pogingen)
- [ ] Optioneel: netwerktekening ook even in Cloudcraft, als alternatief/aanvulling op het Mermaid-diagram
