# Setup

Dit is mijn eigen, herschreven versie van de install guide van school (`school docs/handleiding/Cloud Sec module launch begin environment V1.docx`, origineel `main.tf`/`rds.tf` staan in dezelfde map). Stap voor stap hoe ik de omgeving vanaf nul opzet. De weekopdrachten zelf (en het bewijs) staan in `week-1/` t/m `week-7/`; dit is puur de installatiehandleiding.

## Wat ik anders doe dan de handleiding

- **OpenTofu in plaats van Terraform.** Zelfde taal, zelfde providers. Zie [week-1/README.md](../week-1/README.md) voor waarom.
- **Nieuwere AWS-provider (6.70.0 i.p.v. 3.66.0).** Daarvoor moest `aws_db_instance`'s `name` naar `db_name`. Zie [week-1/README.md](../week-1/README.md).
- **Variabelen in plaats van waardes in `main.tf`.** Keypair-naam, bucketnaam, account-ID en mijn eigen IP staan in `terraform.tfvars`/`backend.hcl` (niet gecommit) en in `labnotes.txt`, nooit in de `.tf`-bestanden zelf — dat gaat naar een publieke repo.
- **tofuenv in plaats van tfenv** om OpenTofu te installeren (zelfde soort tool, ander project).
- **Lokaal werken i.p.v. in CloudShell.** Ik draai alles vanaf mijn eigen laptop, met een eigen scriptje (`setup/lab-login.sh`) om telkens nieuwe lab-credentials in te stellen. Zie "Lab-credentials verversen" hieronder.

## Lab-credentials verversen

Een AWS Academy Learner Lab-sessie verloopt na een paar uur — daarna werken de CLI-credentials niet meer en moet je nieuwe ophalen. Ik gebruik daarvoor een eigen scriptje, [`setup/lab-login.sh`](lab-login.sh): het vraagt interactief om de credentials, zet ze in `~/.aws/credentials` onder het juiste profiel, en test meteen de verbinding met `aws sts get-caller-identity`.

```bash
./setup/lab-login.sh
```

In de lab-omgeving: **AWS Details → AWS CLI** (of "Cloud Access"), daar staan `aws_access_key_id`, `aws_secret_access_key` en `aws_session_token`, plus de AccountId en regio die als profielnaam dienen:

<img src="images/lab-account-id-regio.png" alt="AWS Details-paneel met AWSAccountId 142585515293 en Region us-east-1" width="400">

Die waardes plak je los in de prompts van het script. Secret Access Key en Session Token worden niet op het scherm getoond tijdens het typen (`read -s`):

<img src="images/lab-login-script-prompts.png" alt="Terminal met setup/lab-login.sh: prompts voor account-ID, keys en regio" width="500">

Script zet de credentials onder het juiste profiel en test meteen de verbinding:

<img src="images/lab-login-script-geslaagd.png" alt="Terminal met geslaagde get-caller-identity output: account 142585515293, rol voclabs" width="600">

Faalt de verbindingstest, dan zijn de credentials verlopen of verkeerd gekopieerd — gewoon opnieuw ophalen en het script nog eens draaien.

Voor hulp bij het schrijven van dit script heb ik Claude Sonnet 5 gebruikt (met hoge redeneerinspanning).

## Stap voor stap

1. AWS Academy Learner Lab starten.
2. `./setup/lab-login.sh` draaien (zie hierboven).
3. EC2 → Key Pairs → eigen keypair aanmaken, naam in `labnotes.txt`.
4. S3 → eigen bucket aanmaken voor de OpenTofu state, naam in `labnotes.txt`.
5. `opentofu/terraform.tfvars` en `opentofu/backend.hcl` aanmaken (kopieer de `.example`-bestanden) met die waardes.

```bash
# 6. OpenTofu installeren
git clone https://github.com/tofuutils/tofuenv.git ~/.tofuenv
mkdir ~/bin
ln -s ~/.tofuenv/bin/* ~/bin/
tofuenv install 1.13.2
tofuenv use 1.13.2
tofu --version

# 7. Eerst alléén rds-bootstrap/rds.tf draaien (los project, geen remote backend)
cd opentofu/rds-bootstrap
tofu init
tofu apply
# -> endpoint, db_vpc_id (aws_vpc.saxit_vpc_db.id) en de route table ID van de db-VPC
#    noteren in labnotes.txt en in opentofu/terraform.tfvars
# -> daarna lokale .terraform/ en terraform.tfstate* van dit script verwijderen,
#    zodat een latere "tofu destroy" op main.tf deze database nooit meeneemt

# 8. main.tf (plus bastion.tf)
cd ../
tofu init -backend-config=backend.hcl
tofu apply
# -> minimaal 10 minuten wachten: de VM's installeren Docker en bouwen de containers bij het opstarten
```

9. Testen: DNS-naam van de presentation-load-balancer in de browser.

## Alternatief voor S3: Bunny.net

Deze casus gebruikt AWS S3, dus dat houd ik aan. Voor mezelf gebruik ik voor opslag/CDN meestal [Bunny.net](https://bunny.net), een Sloveens (EU) bedrijf — qua prijs per GB en dataverkeer goedkoper dan AWS, en data staat standaard in de EU, wat voor een Europese partij als SaxIT relevant kan zijn voor soevereiniteit/GDPR.

Bunny Storage heeft ook een S3-compatible API ([docs](https://bunny.net/docs/storage/s3)), dus qua protocol is het geen ander verhaal dan S3 zelf, en Bunny breidt die storage-laag nog actief uit met nieuwe features. Geen IAM-achtig policysysteem met fijnmazige rechten, wel een read-only en een write key per storage zone — daar kun je zelf iets omheen bouwen (zelfde idee als de aparte read-only pull-PAT die ik in mijn andere vak voor Docker Hub gebruik). Wat er volgens de eigen docs nog niet in zit: SSE/SSE-C-encryptie (botst met de BYOK-encryptie uit week 4), object versioning, en ACL's.

Bunny.net is in de kern ook meer een webproduct dan een security-product: CDN, WAF, DNS en static file storage, en snel — Nederland ligt midden in hun servernetwerk. Voor SaxIT zou ik het zo adviseren: security en IAM gewoon bij AWS (of een andere cloud) houden, en Bunny.net ernaast inzetten als snelle CDN/WAF/DNS-laag met static file storage, niet als vervanging voor de security-kritieke dataflows uit deze casus.
