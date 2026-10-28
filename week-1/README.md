# Week 1

Ik richt de initiële 3-tier infrastructuur in AWS in met het Terraform-script uit de module (`rds.tf` en `main.tf`), teken het netwerk, en schrijf twee adviezen voor SaxIT: het Shared Responsibility Model (1.2) en een bastion host (1.3).

**Terraform versus OpenTofu:** de module levert `main.tf`/`rds.tf` aan als HashiCorp Terraform-script. Ik draai dit zelf met **OpenTofu** in plaats van Terraform: dezelfde HCL-taal, dezelfde providers (ook gewoon `hashicorp/aws`), dus de `.tf`-bestanden zelf blijven identiek. Het enige verschil is welke CLI ik gebruik (`tofu` in plaats van `terraform`) en hoe ik die installeer (zie 1.1). Reden: OpenTofu is de open-source fork van Terraform en blijft dat ook, in tegenstelling tot Terraform zelf sinds de licentiewijziging van HashiCorp.

**AWS-provider-versie:** de module pint `hashicorp/aws` op `3.66.0`. Ik gebruik zelf de actuele `6.70.0` (Dependabot had dit al voorgesteld, zie [PR #133](https://github.com/Stensel8/Cloud-Security/pull/133)). Tussen v3 en v6 zijn er echte breaking changes; de enige die mijn code echt raakte was `aws_db_instance`: het argument `name` heette vanaf v5 `db_name` ([upgradegids](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/version-5-upgrade)). Dat heb ik aangepast in [`rds-bootstrap/rds.tf`](../opentofu/rds-bootstrap/rds.tf), en meteen ook een expliciete `identifier = "cloudsecdb"` toegevoegd (stond er nog niet in, waardoor de data-lookup in `iam.tf` nooit de juiste instance zou vinden).

## 1.1 Bootomgeving: de 3-tier infrastructuur

De omgeving bestaat uit twee OpenTofu-scripts, precies zoals de handleiding voorschrijft (die het over Terraform heeft, zie hierboven waarom ik voor OpenTofu koos):

1. **[`rds-bootstrap/rds.tf`](../opentofu/rds-bootstrap/rds.tf)** maakt een eigen VPC (`10.1.0.0/16`) met een MySQL RDS-instance erin. Dit script staat bewust in een eigen map, los van `main.tf`, en draait zonder remote backend. Na het aanmaken van de database noteer ik het endpoint en verwijder ik de lokale OpenTofu-state van dit script, zodat een latere `tofu destroy` op `main.tf` deze database nooit per ongeluk meeneemt. Zo raakt ook de pipeline van week 3 (3.3), die alleen `main.tf`/`bastion.tf` opnieuw uitrolt, deze map nooit aan.
2. **[`main.tf`](../opentofu/main.tf)** (plus [`bastion.tf`](../opentofu/bastion.tf)) maakt de rest: een eigen VPC (`10.0.0.0/16`) met presentation- en applicationtier-subnets verspreid over twee availability zones, twee Application Load Balancers, vier EC2's (`web01`, `web02`, `app01`, `app02`) die bij het opstarten via `user_data` Docker installeren en mijn fork van de applicatie bouwen en draaien, en een VPC-peering naar de db-VPC van `rds.tf`.

### Toegang tot de AWS Learner Lab

Ik heb toegang tot de module via AWS Academy, en heb de Learner Lab-sessie gestart:

<img src="images/aws-academy-dashboard.png" alt="AWS Academy dashboard met de cursussen AWS Academy Cloud Security Foundations en twee Learner Lab-instanties" width="720">

<img src="images/learner-lab-start.png" alt="AWS Academy Learner Lab met de Start Lab-knop" width="720">

Eenmaal gestart (timer loopt) geeft de lab tijdelijke AWS-credentials via "AWS Details" → "Cloud Access". Het credentials-blok zelf staat hieronder bewust afgeschermd met een ondoorzichtig vlak, niet geblurd: dat zijn actieve sleutels, en blur op dit soort monospace-tekst is met wat moeite soms terug te herleiden.

<img src="images/learner-lab-cloud-access.png" alt="AWS Academy Learner Lab met de tijdelijke CLI-credentials, credentials-blok afgeschermd" width="500">

### Keypair aanmaken

Eerst een eigen EC2-keypair voor dit project, via EC2 → Key Pairs:

<img src="images/ec2-keypairs-zoeken.png" alt="EC2-console, zoeken naar de Key Pairs-functie" width="720">

<img src="images/ec2-keypairs-overzicht.png" alt="EC2 Key Pairs-overzicht met de bestaande key vockey, Create key pair wordt aangeklikt" width="720">

<img src="images/ec2-keypair-aanmaken.png" alt="Create key pair-formulier: naam Cloud-Security (550600), type ED25519, formaat .pem" width="720">

Deze keypair gebruik ik om op de EC2-instances in te loggen. De naam noteer ik in `labnotes.txt`, want die heb ik later nodig in het OpenTofu-script. De private key bewaar ik lokaal, niet in de repository.

### Stappen (AWS CloudShell)

```bash
# 1. Keypair en S3-bucket voor de OpenTofu state eerst handmatig aanmaken in de AWS-console,
#    naam en bucket-URL in labnotes.txt zetten.

# 2. OpenTofu installeren in CloudShell (de handleiding gebruikt tfenv voor Terraform,
#    ik gebruik het OpenTofu-equivalent: tofuenv)
git clone https://github.com/tofuutils/tofuenv.git ~/.tofuenv
mkdir ~/bin
ln -s ~/.tofuenv/bin/* ~/bin/
tofuenv install 1.13.2
tofuenv use 1.13.2
tofu --version

# 3. Eerst alléén rds.tf draaien (los, geen backend)
tofu init
tofu apply
# -> endpoint van de RDS-instance noteren in labnotes.txt
# -> daarna lokale .terraform/ en terraform.tfstate* van dit script verwijderen (OpenTofu's eigen vaste bestandsnamen, niet onze mapnaam)

# 4. main.tf aanpassen: keyname, mijn eigen IP (bastion_sg), de S3-bucket voor de state,
#    het db_vpc_id en de db route table id (bestaan na stap 3), en de RDS-endpoint in app01/app02.
#    Zie de TODO/REPLACE_* markeringen in opentofu/main.tf en opentofu/bastion.tf.

tofu init
tofu apply
# -> minimaal 10 minuten wachten: de VM's installeren Docker en bouwen de containers bij het opstarten.
```

**Nog te doen (bewijs):** `tofu apply`-output, de resource map van beide load balancers met status "healthy", en een screenshot van de werkende applicatie via de DNS-naam van de presentation-load-balancer.

### Netwerktekening

In plaats van Cloudcraft gebruik ik een Mermaid-diagram, zodat de tekening meteen in deze repository meekomt en meeverandert met de OpenTofu-code. De security groups en de CIDR-ranges staan in de tekening; mijn eigen IP-adres (in `bastion_sg`) laat ik later als screenshot zien, niet hier in platte tekst.

```mermaid
flowchart TB
    internet(("Internet"))

    subgraph VPC1["saxit_vpc (10.0.0.0/16)"]
        direction TB
        bastion["bastion (EC2)\nsubnet presentation-1"]

        subgraph PLB["presentation-lb (ALB, poort 80)"]
        end

        subgraph PRES["presentationtier (presentation_sg)"]
            direction LR
            subgraph PRES1["subnet presentation-1\n10.0.1.0/24, us-east-1a"]
                web01["web01 (EC2)\nReact frontend"]
            end
            subgraph PRES2["subnet presentation-2\n10.0.2.0/24, us-east-1b"]
                web02["web02 (EC2)\nReact frontend"]
            end
        end

        subgraph ALB2["application-lb (ALB, poort 8080)"]
        end

        subgraph APPL["applicationtier (applicationtier_sg)"]
            direction LR
            subgraph APPL1["subnet appl-1\n10.0.3.0/24, us-east-1a"]
                app01["app01 (EC2)\nSpring backend"]
            end
            subgraph APPL2["subnet appl-2\n10.0.4.0/24, us-east-1b"]
                app02["app02 (EC2)\nSpring backend"]
            end
        end
    end

    subgraph VPC2["saxit_vpc_db (10.1.0.0/16, peered)"]
        rds[("RDS MySQL\ncloudsecdb\nrds_security_group: TCP 3306")]
    end

    internet -- "HTTP 80" --> PLB
    internet -. "SSH 22, alleen eigen IP\n(bastion_sg)" .-> bastion
    bastion -. "SSH 22\n(sg-naar-sg)" .-> PRES
    bastion -. "SSH 22\n(sg-naar-sg)" .-> APPL
    PLB --> web01
    PLB --> web02
    web01 -- "HTTP 80-9000\n(0.0.0.0/0, nog niet verscherpt)" --> ALB2
    web02 -- "HTTP 80-9000\n(0.0.0.0/0, nog niet verscherpt)" --> ALB2
    ALB2 --> app01
    ALB2 --> app02
    app01 -- "TCP 3306\nVPC peering" --> rds
    app02 -- "TCP 3306\nVPC peering" --> rds
```

**Nog te doen (bewijs):** als alternatief, of aanvullend, nog een export uit Cloudcraft met de echte resource-ID's en mijn toegekende IP-ranges.

## 1.2 Advies: het Shared Responsibility Model voor SaxIT

Dit ontwerp draait op EC2, RDS en Elastic Load Balancing: allemaal IaaS/managed-services, geen serverless. Voor AWS betekent dat "Security **of** the Cloud": AWS is verantwoordelijk voor de fysieke datacenters, het netwerk van de hypervisor naar beneden, de hardware van RDS en de beschikbaarheid van de load balancer-service zelf. Voor alles wat ik er bovenop zet geldt "Security **in** the Cloud": dat is mijn verantwoordelijkheid.

Concreet, per onderdeel in dit ontwerp:

| Onderdeel | AWS doet | SaxIT (ik) doet |
| --- | --- | --- |
| VPC, subnets, routering | Het fysieke netwerk en de isolatie tussen VPC's van verschillende klanten | De indeling in tiers, de routetabellen, de VPC-peering |
| Security groups | De firewall-functionaliteit zelf werkt altijd | Welke poorten open staan en voor wie (nu nog te ruim, zie 1.3 en week 3) |
| EC2 (web01/02, app01/02, bastion) | Het fysieke hostplatform, de hypervisor | Het besturingssysteem, patches, welke software erop draait, de Docker-containers, user-data met (nu nog) een wachtwoord in platte tekst |
| RDS (MySQL) | De database-engine draaiende houden, onderliggende patches van het DB-platform, back-ups van de infrastructuur | Het databasewachtwoord, wie er toegang toe heeft, of encryptie aan staat, het databaseschema |
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

**Nog te doen (bewijs):** na `tofu apply`, een proef vanaf mijn eigen laptop: direct SSH'en naar `app01` moet mislukken (timeout), SSH via de bastion host (`ssh -J ubuntu@<bastion-ip> ubuntu@<app01-private-ip>`) moet lukken. Screenshot van beide pogingen.

Bronnen: [AWS: wat is een bastion host](https://docs.aws.amazon.com/whitepapers/latest/aws-fault-isolation-boundaries/bastion-hosts.html), [SSH ProxyJump (OpenSSH)](https://www.ssh.com/academy/ssh/proxyjump).
