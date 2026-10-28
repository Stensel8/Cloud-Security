### React Product App using Spring Boot as the backend
![alt text](react-product-app.avif)

## Run locally with Docker

    docker compose up --build

## Run locally with Podman

    podman compose --file docker-compose.yml up --detach --build

Frontend: http://localhost:3000, backend: http://localhost:8080/api/products.

## Cloud Security - Casus SaxIT

Mijn uitwerking van de Cloud Security-module. Deze applicatie draait in een 3-tier opzet op AWS (zie [`terraform/`](terraform/)), die ik week voor week verder beveilig. De originele opdrachten/slides van school staan in [`school docs/`](school%20docs/); elke week-map heeft naast de uitwerking (`README.md`) ook een `TODO.md` met wat er nog gedaan moet worden.

De infrastructuurcode gebruikt [OpenTofu](https://opentofu.org/) in plaats van HashiCorp Terraform: dezelfde taal en providers, maar open source gebleven. Zie [week 1](week-1/README.md) voor waarom.

- [Week 1](week-1/README.md) ([TODO](week-1/TODO.md)): 3-tier infrastructuur, netwerktekening, Shared Responsibility Model, bastion host
- [Week 2](week-2/README.md) ([TODO](week-2/TODO.md)): IAM-authenticatie naar RDS, least privilege, Entra ID-federatie
- [Week 3](week-3/README.md) ([TODO](week-3/TODO.md)): North-South/East-West segmentatie, immutable infrastructure via een pipeline
- [Week 4](week-4/README.md) ([TODO](week-4/TODO.md)): Dataclassificatie, S3-encryptie, bring your own key, logging en alerting
- [Week 5](week-5/README.md) ([TODO](week-5/TODO.md)): Incident response plan, application security, STRIDE-threatmodel
- [Week 6](week-6/README.md) ([TODO](week-6/TODO.md)): Centrale logging, AWS-detectiediensten, Security Hub, log-analyse met Python en IsolationForest
- [Week 7](week-7/README.md) ([TODO](week-7/TODO.md)): Security frameworks, NIST CSF, AVG
