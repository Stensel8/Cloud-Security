# Setup

Dit is mijn eigen, herschreven versie van de install guide van school (`school docs/handleiding/Cloud Sec module launch begin environment V1.docx`, origineel `main.tf`/`rds.tf` staan in dezelfde map). Stap voor stap hoe ik de omgeving vanaf nul opzet. De weekopdrachten zelf (en het bewijs) staan in `week-1/` t/m `week-7/`; dit is puur de installatiehandleiding.

## Wat ik anders doe dan de handleiding

- **OpenTofu in plaats van Terraform.** Zelfde taal, zelfde providers. Zie [week-1/README.md](../week-1/README.md) voor waarom.
- **Nieuwere AWS-provider (6.70.0 i.p.v. 3.66.0).** Daarvoor moest `aws_db_instance`'s `name` naar `db_name`. Zie [week-1/README.md](../week-1/README.md).
- **Variabelen in plaats van waardes in `main.tf`.** Keypair-naam, bucketnaam, account-ID en mijn eigen IP staan in `terraform.tfvars`/`backend.hcl` (niet gecommit) en in `labnotes.txt`, nooit in de `.tf`-bestanden zelf — dat gaat naar een publieke repo.
- **tofuenv in plaats van tfenv** om OpenTofu te installeren (zelfde soort tool, ander project).

## Stap voor stap

1. AWS Academy Learner Lab starten.
2. EC2 → Key Pairs → eigen keypair aanmaken, naam in `labnotes.txt`.
3. S3 → eigen bucket aanmaken voor de OpenTofu state, naam in `labnotes.txt`.
4. `opentofu/terraform.tfvars` en `opentofu/backend.hcl` aanmaken (kopieer de `.example`-bestanden) met die waardes.

```bash
# 5. OpenTofu installeren in CloudShell
git clone https://github.com/tofuutils/tofuenv.git ~/.tofuenv
mkdir ~/bin
ln -s ~/.tofuenv/bin/* ~/bin/
tofuenv install 1.13.2
tofuenv use 1.13.2
tofu --version

# 6. Eerst alléén rds-bootstrap/rds.tf draaien (los project, geen remote backend)
cd opentofu/rds-bootstrap
tofu init
tofu apply
# -> endpoint, db_vpc_id (aws_vpc.saxit_vpc_db.id) en de route table ID van de db-VPC
#    noteren in labnotes.txt en in opentofu/terraform.tfvars
# -> daarna lokale .terraform/ en terraform.tfstate* van dit script verwijderen,
#    zodat een latere "tofu destroy" op main.tf deze database nooit meeneemt

# 7. main.tf (plus bastion.tf)
cd ../
tofu init -backend-config=backend.hcl
tofu apply
# -> minimaal 10 minuten wachten: de VM's installeren Docker en bouwen de containers bij het opstarten
```

8. Testen: DNS-naam van de presentation-load-balancer in de browser.

## Alternatief voor S3: Bunny.net

Deze casus gebruikt AWS S3, dus dat houd ik aan. Voor mezelf gebruik ik voor opslag/CDN meestal [Bunny.net](https://bunny.net), een Sloveens (EU) bedrijf — qua prijs per GB en dataverkeer goedkoper dan S3, en data staat standaard in de EU, wat voor een Europese partij als SaxIT relevant kan zijn voor soevereiniteit/GDPR.

Twee dingen die ik SaxIT wel eerlijk zou meegeven voordat ze dat zouden overwegen: Bunny Storage praat geen S3-protocol (eigen REST-API/FTP), dus dit is geen drop-in vervanging voor iets dat al op de S3-API leunt, zoals de OpenTofu-backend hier. En Bunny heeft niet het IAM/KMS/CloudTrail-ecosysteem dat deze casus juist gebruikt (week 2, week 4) — voor de beveiligde, auditbare opslag die hier gevraagd wordt is AWS op dit moment vollediger. Ik zou het SaxIT aanraden als iets om te evalueren voor losse, minder gevoelige opslag- of CDN-behoeften, niet als vervanging voor de security-kritieke dataflows uit deze casus.
