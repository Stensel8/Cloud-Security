# Week 1

Ik richt de initiële 3-tier infrastructuur in AWS in met het Terraform-script uit de module (`rds.tf` en `main.tf`), teken het netwerk, en schrijf twee adviezen voor SaxIT: het Shared Responsibility Model (1.2) en een bastion host (1.3).

**Terraform versus OpenTofu:** de module levert `main.tf`/`rds.tf` aan als HashiCorp Terraform-script. Ik draai dit zelf met **OpenTofu** in plaats van Terraform: dezelfde HCL-taal, dezelfde providers (ook gewoon `hashicorp/aws`), dus de `.tf`-bestanden zelf blijven identiek. Het enige verschil is welke CLI ik gebruik (`tofu` in plaats van `terraform`) en hoe ik die installeer (zie 1.1). Reden: OpenTofu is de open-source fork van Terraform en blijft dat ook, in tegenstelling tot Terraform zelf sinds de licentiewijziging van HashiCorp.

**AWS-provider-versie:** de module pint `hashicorp/aws` op `3.66.0`. Ik gebruik zelf de actuele `6.70.0` (Dependabot had dit al voorgesteld, zie [PR #133](https://github.com/Stensel8/Cloud-Security/pull/133)). Tussen v3 en v6 zijn er echte breaking changes; de enige die mijn code echt raakte was `aws_db_instance`: het argument `name` heette vanaf v5 `db_name` ([upgradegids](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/version-5-upgrade)). Dat heb ik aangepast in [`rds-bootstrap/rds.tf`](../opentofu/rds-bootstrap/rds.tf), en meteen ook een expliciete `identifier = "cloudsecdb"` toegevoegd (stond er nog niet in, waardoor de data-lookup in `iam.tf` nooit de juiste instance zou vinden).

## 1.1 Bootomgeving: de 3-tier infrastructuur

De omgeving bestaat uit twee OpenTofu-scripts, precies zoals de handleiding voorschrijft (die het over Terraform heeft, zie hierboven waarom ik voor OpenTofu koos):

1. **[`rds-bootstrap/rds.tf`](../opentofu/rds-bootstrap/rds.tf)** maakt een eigen VPC (`10.1.0.0/16`) met een MariaDB RDS-instance erin. Dit script staat bewust in een eigen map, los van `main.tf`, en draait zonder remote backend. Na het aanmaken van de database noteer ik het endpoint en verwijder ik de lokale OpenTofu-state van dit script, zodat een latere `tofu destroy` op `main.tf` deze database nooit per ongeluk meeneemt. Zo raakt ook de pipeline van week 3 (3.3), die alleen `main.tf`/`bastion.tf` opnieuw uitrolt, deze map nooit aan.
2. **[`main.tf`](../opentofu/main.tf)** (plus [`bastion.tf`](../opentofu/bastion.tf)) maakt de rest: een eigen VPC (`10.0.0.0/16`) met presentation- en applicationtier-subnets verspreid over twee availability zones, twee Application Load Balancers, vier EC2's (`web01`, `web02`, `app01`, `app02`) die bij het opstarten via `user_data` Docker installeren en mijn fork van de applicatie bouwen en draaien, en een VPC-peering naar de db-VPC van `rds.tf`.

### Toegang tot de AWS Learner Lab

Ik heb toegang tot de module via AWS Academy, en heb de Learner Lab-sessie gestart:

<img src="images/aws-academy-dashboard.png" alt="AWS Academy dashboard met de cursussen AWS Academy Cloud Security Foundations en twee Learner Lab-instanties" width="720">

<img src="images/learner-lab-start.png" alt="AWS Academy Learner Lab met de Start Lab-knop" width="720">

Eenmaal gestart (timer loopt) geeft de lab tijdelijke AWS-credentials via "AWS Details" → "Cloud Access". Het credentials-blok zelf staat hieronder bewust afgeschermd met een ondoorzichtig vlak, niet geblurd: dat zijn actieve sleutels, en blur op dit soort monospace-tekst is met wat moeite soms terug te herleiden.

<img src="images/learner-lab-cloud-access.png" alt="AWS Academy Learner Lab met de tijdelijke CLI-credentials, credentials-blok afgeschermd" width="500">

### AWS CLI lokaal + lab-credentials verversen

Ik werk niet in CloudShell maar lokaal, met OpenTofu en de AWS CLI op mijn eigen laptop:

<img src="images/aws-cli-installeren.png" alt="AWS CLI installeren via pacman op Arch Linux" width="720">

Een Learner Lab-sessie geeft tijdelijke credentials die na een paar uur verlopen. Account-ID en regio vind ik terug onder "AWS Details":

<img src="images/lab-account-id-regio.png" alt="AWS Details-paneel met AWSAccountId 142585515293 en Region us-east-1" width="400">

Om die credentials niet elke keer met de hand in `~/.aws/credentials` te zetten, heb ik [`setup/lab-login.sh`](../setup/lab-login.sh) geschreven: het script vraagt de Access Key ID, Secret Access Key en Session Token op uit "AWS Details" → "Cloud Access", zet ze onder het juiste profiel, en test de verbinding meteen met `aws sts get-caller-identity`.

<img src="images/lab-login-script-prompts.png" alt="Terminal met setup/lab-login.sh: prompts voor account-ID, keys en regio" width="500">

<img src="images/lab-login-script-geslaagd.png" alt="Terminal met geslaagde get-caller-identity output: account 142585515293, rol voclabs" width="600">

Secret Access Key en Session Token worden niet op het scherm getoond tijdens het typen (`read -s`). Voor hulp bij dit script heb ik Claude Sonnet 5 gebruikt; uitleg erover staat in [`setup/README.md`](../setup/README.md).

### Keypair aanmaken

Eerst een eigen EC2-keypair voor dit project, via EC2 → Key Pairs:

<img src="images/ec2-keypairs-zoeken.png" alt="EC2-console, zoeken naar de Key Pairs-functie" width="720">

<img src="images/ec2-keypairs-overzicht.png" alt="EC2 Key Pairs-overzicht met de bestaande key vockey, Create key pair wordt aangeklikt" width="720">

<img src="images/ec2-keypair-aanmaken.png" alt="Create key pair-formulier: naam Cloud-Security (550600), type ED25519, formaat .pem" width="720">

Deze keypair gebruik ik om op de EC2-instances in te loggen. De naam noteer ik in `labnotes.txt`. De private key bewaar ik lokaal, niet in de repository.

### S3-bucket voor de OpenTofu state

<img src="images/s3-buckets-leeg.png" alt="S3-console, nog geen buckets, Create bucket wordt aangeklikt" width="720">

<img src="images/s3-bucket-aanmaken.png" alt="Create bucket-formulier: prefix 550600-cloudsec-tfstate, Account Regional namespace, regio us-east-1" width="720">

Regio `us-east-1`, zelfde regio als in `main.tf`/`rds.tf`. Voor de naamgeving kies ik Account Regional namespace in plaats van Global namespace: AWS plakt er automatisch een account-specifieke suffix achter, wat de bucketnaam lastiger te gokken maakt voor scanners die bekende naampatronen afgaan. Dat is een extra laag bovenop Block Public Access (staat aan), niet de beveiliging zelf. Volledige naam (`550600-cloudsec-tfstate-142585515293-us-east-1-an`) noteer ik in `labnotes.txt`.

Rest van de instellingen laat ik op de AWS-standaard staan: Object Ownership op "ACLs disabled", Block all public access aan, en SSE-S3-encryptie met Bucket Key aan. Versioning zet ik niet aan, niet nodig voor dit project.

Keypair-naam, bucketnaam, account-ID en mijn eigen IP staan nergens in `main.tf` zelf, maar in `terraform.tfvars`/`backend.hcl` (niet gecommit) en in `labnotes.txt`. Volledige installatiehandleiding, stap voor stap: [`setup/README.md`](../setup/README.md).

<img src="images/main-tf-init.png" alt="tofu init -backend-config=backend.hcl: backend succesvol geconfigureerd" width="720">

<img src="images/main-tf-apply-plan.png" alt="tofu apply-plan voor main.tf: 65 to add, 0 to change, 0 to destroy" width="720">

<img src="images/main-tf-apply-confirm-create.png" alt="Plan bevestigd met yes, VPC/subnets/EC2's/load balancers worden aangemaakt" width="720">

<img src="images/load-balancers-overzicht.png" alt="EC2-console, Load balancers-overzicht: presentation-lb en application-lb, beide Active, Dualstack" width="900">

<img src="images/resource-map-presentation-lb.png" alt="Resource map presentation-lb: listener HTTP:80 -> target group -> 2 targets, beide Healthy" width="900">

<img src="images/resource-map-application-lb.png" alt="Resource map application-lb: listener HTTP:8080 -> target group -> 2 targets, beide Healthy" width="900">

<img src="images/applicatie-werkt-via-presentation-lb.png" alt="Werkende Product App via presentation-lb-4216771.us-east-1.elb.amazonaws.com, DevTools Network-tab toont 200 OK op de echte ELB-DNS-naam" width="900">

Alle "Nog te doen (bewijs)"-punten van 1.1 zijn hiermee compleet.

### RDS-bootstrap draaien, en daarna de lokale state weggooien

<img src="images/rds-bootstrap-apply-plan-1.png" alt="tofu apply-plan voor rds-bootstrap: aws_db_instance.cloudsecdb wordt aangemaakt" width="720">

<img src="images/rds-bootstrap-apply-confirm-create.png" alt="Plan bevestigd met yes, VPC/subnets/security group/database worden aangemaakt" width="720">

<img src="images/rds-bootstrap-apply-complete.png" alt="Apply complete, 6 resources toegevoegd" width="720">

Endpoint, db-VPC-ID en de route table-ID van die VPC noteer ik in `labnotes.txt` en zet ik in `opentofu/terraform.tfvars`, zodat `main.tf` straks de VPC-peering naar de juiste database kan maken.

Daarna verwijder ik de lokale `.terraform/` en `terraform.tfstate*` van dit losse script. Dat is geen eigen voorzichtigheidsmaatregel, maar letterlijk wat de handleiding van school voorschrijft (`school docs/handleiding/Cloud Sec module launch begin environment V1.docx`):

> *"We don't want the database instance to be deleted with a Terraform destroy command, so we delete all files in the directory that are related to Terraform, including the state file."*

```bash
rm -rf opentofu/rds-bootstrap/.terraform opentofu/rds-bootstrap/terraform.tfstate*
```

<img src="images/rds-bootstrap-state-opgeruimd.png" alt="Terminal: rm -rf van .terraform en terraform.tfstate*, daarna een lege rds-bootstrap-map op die twee na" width="600">

De database zelf blijft gewoon bestaan in AWS; alleen OpenTofu's eigen boekhouding van dit losse script is weg. Een `tofu destroy` op `main.tf` kent deze resources dus niet en kan ze nooit meenemen.

### Netwerktekening

In plaats van Cloudcraft gebruik ik een Mermaid-diagram, zodat de tekening meteen in deze repository meekomt en meeverandert met de OpenTofu-code. De security groups en de CIDR-ranges staan in de tekening; mijn eigen IP-adres (in `bastion_sg`) laat ik later als screenshot zien, niet hier in platte tekst.

```mermaid
flowchart TB
    internet(("Internet"))
    browser["Browser\n(roept presentation-lb én\napplication-lb rechtstreeks aan,\nzie week 3.1)"]
    internet --- browser

    subgraph VPC1["saxit_vpc (10.0.0.0/16, dual-stack, eigen /56 IPv6-blok)"]
        direction TB

        subgraph PUB["Public subnets: 10.0.10.0/24 (1a), 10.0.11.0/24 (1b)"]
            direction LR
            bastion["bastion (EC2)\nbastion_sg"]
            PLB["presentation-lb\nALB, dualstack, poort 80"]
            ALB2["application-lb\nALB, dualstack, poort 8080"]
            NAT["NAT gateway\n(IPv4-egress)"]
        end

        subgraph PRES["presentationtier (presentationtier_sg)\n10.0.1.0/24 (1a), 10.0.2.0/24 (1b)"]
            direction LR
            web01["web01 (EC2)\nReact frontend, IPv6-only target"]
            web02["web02 (EC2)\nReact frontend, IPv6-only target"]
        end

        subgraph APPL["applicationtier (applicationtier_sg)\n10.0.3.0/24 (1a), 10.0.4.0/24 (1b)"]
            direction LR
            app01["app01 (EC2)\nSpring backend"]
            app02["app02 (EC2)\nSpring backend"]
        end
    end

    subgraph VPC2["saxit_vpc_db (10.1.0.0/16, peered)"]
        rds[("RDS MariaDB\ncloudsecdb\nrds_security_group: TCP 3306")]
    end

    browser -- "HTTP 80" --> PLB
    browser -- "HTTP 8080\n(rechtstreeks, geen proxy)" --> ALB2
    internet -. "SSH 22, alleen eigen IP\n(bastion_sg)" .-> bastion
    bastion -. "SSH 22\n(sg-naar-sg)" .-> PRES
    bastion -. "SSH 22\n(sg-naar-sg)" .-> APPL
    PLB -- "IPv6" --> web01
    PLB -- "IPv6" --> web02
    ALB2 --> app01
    ALB2 --> app02
    web01 -. "apt/Docker-mirror/npm\n(IPv4 via NAT)" .-> NAT
    app01 -. "apt/Docker-mirror/Maven\n(IPv4 via NAT)" .-> NAT
    app01 -- "TCP 3306\nVPC peering" --> rds
    app02 -- "TCP 3306\nVPC peering" --> rds
```

IPv6-egress (via een gratis egress-only internet gateway, niet apart getekend) loopt parallel aan de NAT gateway-pijlen hierboven - zie [setup/README.md](../setup/README.md#ipv6-only-experiment-en-waarom-alles-nu-dual-stack-is) voor waarom alles dual-stack is in plaats van IPv6-only.

## 1.2 Advies: het Shared Responsibility Model voor SaxIT

Dit ontwerp draait op EC2, RDS en Elastic Load Balancing: allemaal IaaS/managed-services, geen serverless. Voor AWS betekent dat "Security **of** the Cloud": AWS is verantwoordelijk voor de fysieke datacenters, het netwerk van de hypervisor naar beneden, de hardware van RDS en de beschikbaarheid van de load balancer-service zelf. Voor alles wat ik er bovenop zet geldt "Security **in** the Cloud": dat is mijn verantwoordelijkheid.

Concreet, per onderdeel in dit ontwerp:

| Onderdeel | AWS doet | SaxIT (ik) doet |
| --- | --- | --- |
| VPC, subnets, routering | Het fysieke netwerk en de isolatie tussen VPC's van verschillende klanten | De indeling in tiers, de routetabellen, de VPC-peering |
| Security groups | De firewall-functionaliteit zelf werkt altijd | Welke poorten open staan en voor wie (nu nog te ruim, zie 1.3 en week 3) |
| EC2 (web01/02, app01/02, bastion) | Het fysieke hostplatform, de hypervisor | Het besturingssysteem, patches, welke software erop draait, de Docker-containers, user-data met (nu nog) een wachtwoord in platte tekst |
| RDS (MariaDB) | De database-engine draaiende houden, onderliggende patches van het DB-platform, back-ups van de infrastructuur | Het databasewachtwoord, wie er toegang toe heeft, of encryptie aan staat, het databaseschema |
| Elastic Load Balancer | De beschikbaarheid en schaling van de load balancer zelf | Welke listeners en targetgroups ik configureer, of er TLS op zit (nu nog niet: alles is HTTP) |
| IAM | De IAM-service zelf werkt en is beschikbaar | Welke gebruikers, rollen en policies ik aanmaak en hoe strikt least privilege is (zie week 2) |

Mijn advies aan SaxIT: AWS zorgt dat de bakstenen stevig zijn, maar het huis zelf (wie er binnen mag, welke deuren er zijn, of de brandkast op slot zit) is aan ons. Dat betekent dat een "het staat in de cloud dus het is beveiligd"-aanname niet klopt: de security groups, IAM-rollen, encryptie en patching in dit ontwerp zijn allemaal dingen die ík fout kan laten staan, en AWS lost dat niet voor me op. Ik zou dit verder uitwerken door dit schema als uitgangspunt te nemen bij elke nieuwe AWS-dienst die SaxIT toevoegt: eerst vaststellen wat AWS regelt, dan expliciet maken wat er aan onze kant nog open staat.

Bronnen: [AWS Shared Responsibility Model](https://aws.amazon.com/compliance/shared-responsibility-model/), [AWS Well-Architected Security Pillar: Shared Responsibility](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/shared-responsibility.html), [Wat is cloud security (Check Point)](https://www.checkpoint.com/cyber-hub/cloud-security/what-is-cloud-security/).

## 1.3 Advies en implementatie: bastion host

Een bastion host (ook wel jump host) is één, bewust kleine en goed bewaakte server die als enige poort naar buiten voor SSH-verkeer dient. In plaats van dat elke VM in de presentation- en applicationtier zelf bereikbaar is via SSH vanaf het hele internet, staat SSH op al die VM's alleen nog open voor verkeer dat van de bastion host zelf komt. Wil ik op `app01` inloggen, dan SSH ik eerst naar de bastion host, en vandaar met een tweede SSH-sprong (`ssh -J` of `ProxyJump`) door naar `app01`.

Voor deze casus verhoogt dat de veiligheid om een paar redenen:

- **Kleiner aanvalsoppervlak.** In de beginsituatie staat SSH op `web01`, `web02`, `app01` en `app02` open voor `0.0.0.0/0`: vier publieke IP-adressen die vanaf elk IP ter wereld te benaderen zijn. Met een bastion host is dat nog maar één host, met één smalle regel (alleen mijn eigen IP).
- **Eén plek om te monitoren en te patchen.** Loginpogingen, mislukte authenticaties en kwetsbaarheden in de SSH-daemon hoef ik nu nog maar op één machine in de gaten te houden, in plaats van op vier.
- **Credentials blijven dichter bij huis.** Alleen de bastion host hoeft de private key te zien die ook echt gebruikt wordt om in te loggen; de andere VM's zijn alleen bereikbaar via die ene sprong.

Ik heb dit toegepast in [`opentofu/bastion.tf`](../opentofu/bastion.tf): een losse `bastion_sg` die SSH alleen toestaat vanaf mijn eigen IP (`local.my_ip`), en een EC2-instance in de presentationtier-subnet die als enige poort naar binnen dient. In [`opentofu/main.tf`](../opentofu/main.tf) heb ik de SSH-ingress-regel van `presentationtier_sg` en `applicationtier_sg` aangepast van een open CIDR-blok (`0.0.0.0/0`) naar een verwijzing naar `bastion_sg.id` (security-group-naar-security-group, geen CIDR meer). Daarmee kan niemand, ook ikzelf niet, nog rechtstreeks met SSH bij `web01/web02/app01/app02` komen: alleen via de bastion host.

```hcl
ingress {
  description     = "SSH ingress - alleen vanaf de bastion host"
  from_port       = 22
  to_port         = 22
  protocol        = "tcp"
  security_groups = [aws_security_group.bastion_sg.id]
}
```

Bewijs vanaf mijn eigen laptop: direct SSH'en naar `app01` (privé-IP, niet routeerbaar vanaf het internet) hangt/mislukt, SSH via de bastion host (`ssh -J ubuntu@<bastion-ip> ubuntu@<app01-private-ip>`) lukt meteen:

<img src="images/ssh-direct-faalt-via-bastion-lukt.png" alt="Terminal: directe SSH naar 10.0.3.16 wordt afgebroken (^C), SSH via -J ubuntu@bastion-ip lukt en logt in op ip-10-0-3-16" width="800">

En ter controle in de AWS-console dat dit ook echt de juiste IP's zijn: alle vier de web-/app-instances hebben geen publiek IPv4-adres, alleen de bastion heeft er één (`35.173.231.84`):

<img src="images/ec2-instances-overzicht-public-ip.png" alt="EC2 Instances-overzicht: app01/app02/web01/web02 hebben Public IPv4 address '-', bastion heeft 35.173.231.84" width="900">

<img src="images/app01-instance-summary-geen-public-ip.png" alt="Instance summary van app01: Private IPv4 10.0.3.16, Public IPv4 address leeg" width="900">

Bronnen: [AWS: wat is een bastion host](https://docs.aws.amazon.com/whitepapers/latest/aws-fault-isolation-boundaries/bastion-hosts.html), [SSH ProxyJump (OpenSSH)](https://www.ssh.com/academy/ssh/proxyjump).
