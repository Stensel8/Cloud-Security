# Week 3: Infrastructure protection

Infrastructure protection gaat over alles onder de applicatie: het netwerk, de servers, en de manier waarop die met elkaar en met internet communiceren. In de Security Pillar noemt AWS onder andere het opdelen van het netwerk in lagen, het beperken van verkeer tussen die lagen, en het automatiseren van de netwerkbeveiliging [(Amazon Web Services, z.d.-a)](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/infrastructure-protection.html).

Bij segmentatie wordt het netwerk opgedeeld in kleinere delen. Een aanvaller die één onderdeel overneemt, kan dan niet zomaar bij de rest [(Zscaler, z.d.)](https://www.zscaler.com/resources/security-terms-glossary/what-is-network-segmentation). Daarbij worden twee richtingen onderscheiden. North-south is verkeer dat het netwerk in of uit gaat. East-west is verkeer tussen servers binnen het netwerk.

In AWS wordt dit vooral geregeld met security groups. Een security group laat alleen verkeer door waarvoor een regel bestaat. Als bron kan een IP-range worden opgegeven, maar ook een andere security group [(Amazon Web Services, z.d.-c)](https://docs.aws.amazon.com/vpc/latest/userguide/security-group-rules.html).

Immutable infrastructure betekent dat een server na het uitrollen niet meer met de hand wordt aangepast. Is er een wijziging nodig, dan wordt er een nieuwe server gebouwd die de oude vervangt [(Virdó, 2017)](https://www.digitalocean.com/community/tutorials/what-is-immutable-infrastructure).

Deze week bestaat uit vier opdrachten. In paragraaf 3.1 en 3.2 worden de security groups uit week 1 strenger gemaakt, voor north-south- en east-west-verkeer. Paragraaf 3.3 beschrijft het uitrollen van de infrastructuur via een pipeline, en paragraaf 3.4 bevat een advies aan SaxIT over infrastructure protection.

## 3.1 North-South segmentatie

In de beginsituatie stond applicationtier_sg open voor de poorten 80 tot en met 9000, vanaf elk IP-adres. Dat kwam zo uit de beginscripts van de module en is veel te ruim, want de backend luistert alleen op poort 8080. In [`opentofu/main.tf`](../opentofu/main.tf) heb ik de regel beperkt tot poort 8080, en alleen vanaf de application-lb:

```hcl
resource "aws_vpc_security_group_ingress_rule" "application_http_from_lb" {
  security_group_id            = aws_security_group.applicationtier_sg.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.applicationtier_sg.id
}
```

De regel verwijst naar applicationtier_sg zelf. Dat komt doordat de application-lb in deze opstelling ook in die security group zit, waardoor het verkeer van de load balancer naar app01 en app02 uit applicationtier_sg komt. Bij mijn eerste poging had ik hier presentationtier_sg ingevuld. De health checks van de load balancer kwamen toen niet meer aan.

Alleen deze regel bleek niet genoeg. De React-frontend draait in de browser van de gebruiker en roept de application-lb rechtstreeks aan. Dat is te zien in de code: bij het bouwen van de frontend wordt het adres van de application-lb als `VITE_API_BASE_URL` in de JavaScript gezet, en nginx op de webservers serveert alleen de bestanden, zonder verzoeken door te sturen naar de backend. Daarom heb ik een tweede regel toegevoegd, die poort 8080 openzet voor internet. Dat is minder streng dan ik zou willen, maar het volgt uit de manier waarop de applicatie is gebouwd. Het verkeer is wel flink beperkt: van de poorten 80 tot en met 9000 naar alleen poort 8080. Daarnaast hebben app01 en app02 geen publiek IP-adres (zie 1.3), waardoor van buitenaf alleen de load balancer bereikbaar is. De application-lb helemaal intern maken kan pas als de frontend de backend via de webservers aanroept in plaats van vanuit de browser.

## 3.2 East-West segmentatie

rds_security_group stond open voor MariaDB (poort 3306) vanaf elk IP-adres. Ook dat was nog over van de beginscripts. In [`opentofu/rds-bootstrap/rds.tf`](../opentofu/rds-bootstrap/rds.tf) heb ik de regel beperkt tot de twee subnets van de application tier, 10.0.3.0/24 en 10.0.4.0/24.

Hier gebruik ik IP-ranges in plaats van een verwijzing naar applicationtier_sg. Die security group zit in de andere VPC, aan de andere kant van de VPC peering, en een verwijzing over de peering heen kreeg ik in het Learner Lab niet betrouwbaar werkend. Met de IP-ranges van de subnets is het resultaat hetzelfde: alleen de app-servers mogen bij de database.

![De inkomende regels van rds_security_group: TCP 3306, alleen vanaf 10.0.3.0/24 en 10.0.4.0/24](images/rds-sg-inbound-rules-source.png)

Om dit te testen heb ik vanaf app01 en vanaf web01 een TCP-verbinding met de database geprobeerd, beide keren met dezelfde hostnaam en dezelfde controle.

![Vanaf app01 lukt de verbinding met de database op poort 3306](images/app01-naar-rds-gelukt.png)

![Vanaf web01 lukt de verbinding met de database niet](images/web01-naar-rds-mislukt.png)

Het enige verschil tussen beide servers is het subnet, en dat is precies wat de security group afdwingt. Als web01 ooit wordt overgenomen, kan een aanvaller vanaf daar niet rechtstreeks bij de database.

## 3.3 Immutable infrastructure via een pipeline

Voor deze opdracht rol ik de infrastructuur uit via GitHub Actions. GitHub Actions is de CI/CD-dienst van GitHub, die bij een wijziging in de repository automatisch een workflow uitvoert. De workflow voor OpenTofu staat in [`.github/workflows/opentofu.yml`](../.github/workflows/opentofu.yml) en werkt als volgt:

- **Bij een pull request** draait alleen `tofu plan`, zodat de wijziging eerst kan worden bekeken.
- **Na een merge naar de branch `uitwerkingen`** draait ook `tofu apply`.
- **De workflow start alleen** als er iets in de OpenTofu-bestanden verandert.

De scripts voor de database in `opentofu/rds-bootstrap/` vallen buiten de pipeline. OpenTofu leest alleen de map waarin het draait en niet de submappen, waardoor de pipeline de database nooit kan verwijderen.

Bij de eerste runs liep ik tegen twee problemen aan. De naam van de S3-bucket voor de state staat bewust niet in de code, omdat mijn account-ID erin zit. In de pipeline ontbrak die naam, waardoor OpenTofu erom vroeg en bleef wachten op een antwoord dat nooit kwam.

![De pipeline blijft hangen bij tofu init, omdat OpenTofu om de naam van de S3-bucket vraagt](images/pipeline-tofu-init-hangt-op-bucket-prompt.png)

De bucketnaam wordt nu meegegeven als secret, met `-input=false` erbij, zodat OpenTofu nooit meer op invoer wacht. Het tweede probleem was dat een paar variabelen alleen in mijn lokale `terraform.tfvars` stonden. Die staan nu als secrets in GitHub.

![De negen repository secrets die de pipeline gebruikt](images/github-actions-secrets-compleet.png)

De credentials van het Learner Lab zijn tijdelijk, dus bij elke nieuwe labsessie moet ik de drie AWS-secrets opnieuw invullen. In productie zou de pipeline een IAM-rol gebruiken die steeds nieuwe, tijdelijke credentials krijgt, zoals in week 2.

Daarna werkte de pipeline. `tofu plan` slaagt en wil drie onderdelen toevoegen: de IAM-rol, de policy en het instance profile uit 2.1. `tofu apply` stopt daarna op dezelfde AccessDenied als op mijn laptop.

![tofu apply in de pipeline: drie resources toe te voegen, daarna AccessDenied bij het aanmaken van de IAM-rol](images/pipeline-apply-verwachte-iam-fout.png)

Dit is geen fout in de pipeline, maar de bekende beperking van het Learner Lab. Daarom staat `continue-on-error: true` op de apply-stap, zodat de run toch slaagt.

![De OpenTofu-run is geslaagd, met een groen vinkje bij init, plan en apply](images/pipeline-run-geslaagd.png)

In pull request #140 is te zien dat bij een pull request alleen init en plan draaien, en dat de apply-stap wordt overgeslagen ([run op GitHub](https://github.com/Stensel8/Cloud-Security/actions/runs/41314490078)).

![Pull request #140: alleen plan, de apply-stap wordt overgeslagen](images/pr-plan-only.png)

Doordat alles in code staat en via de pipeline loopt, is elke wijziging zichtbaar in een pull request. Een handmatige wijziging in de console wordt bij de volgende apply weer teruggezet. Een server die niet meer te vertrouwen is, kan worden vervangen door hem opnieuw uit te rollen, in plaats van hem met de hand te repareren.

## 3.4 Advies: infrastructure protection voor SaxIT

Mijn advies aan SaxIT is om de maatregelen van deze week standaard te maken voor elke nieuwe omgeving, en niet alleen voor deze proefopstelling:

- **North-south beperken:** alleen de load balancers zijn van buitenaf bereikbaar, en beheer loopt via de bastion host (1.3). Er zijn dan een paar bewaakte ingangen in plaats van een ingang per server.
- **East-west beperken:** elke laag mag alleen communiceren met de laag die hij echt nodig heeft. Een overgenomen webserver kan dan niet bij de database (3.2).
- **Immutable infrastructure:** servers worden vervangen in plaats van met de hand aangepast. Zo ontstaan er geen onderlinge verschillen, en is er bij een incident snel een schone server terug (zie week 5).
- **Netwerkbeveiliging automatiseren:** security groups en de rest van het netwerk staan in OpenTofu, worden beoordeeld in een pull request en uitgerold via de pipeline. AWS raadt dat ook aan, zodat de beveiliging niet afhangt van handwerk [(Amazon Web Services, z.d.-b)](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/sec_network_auto_protect.html).

## Bronnen

Amazon Web Services. (z.d.-a). *Infrastructure protection*. Security Pillar: AWS Well-Architected Framework. https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/infrastructure-protection.html

Amazon Web Services. (z.d.-b). *SEC05-BP04 Automate network protection*. Security Pillar: AWS Well-Architected Framework. https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/sec_network_auto_protect.html

Amazon Web Services. (z.d.-c). *Security group rules*. Amazon VPC User Guide. https://docs.aws.amazon.com/vpc/latest/userguide/security-group-rules.html

Virdó, H. (2017, 26 september). *What is immutable infrastructure?* DigitalOcean. https://www.digitalocean.com/community/tutorials/what-is-immutable-infrastructure

Zscaler. (z.d.). *What is network segmentation?* https://www.zscaler.com/resources/security-terms-glossary/what-is-network-segmentation
