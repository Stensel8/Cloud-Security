### React Product App using Spring Boot as the backend
![alt text](react-product-app.avif)

[![CodeTrunk mirror](https://img.shields.io/badge/mirror-CodeTrunk%20(EU)-2496ED)](https://repos.codetrunk.eu/Stensel8/Cloud-Security)

## Run locally with Docker

    docker compose up --build

## Run locally with Podman

    podman compose --file compose.yml up --detach --build

Frontend: http://localhost:3000, backend: http://localhost:8080/api/products.

## Cloud Security - Casus SaxIT

Mijn uitwerking van de Cloud Security-module. Deze applicatie draait in een 3-tier opzet op AWS (zie [`opentofu/`](opentofu/)), die ik week voor week verder beveilig. De originele opdrachten/slides van school staan lokaal in `school docs/`, maar die map hoort niet in een publieke repo en staat daarom in `.gitignore`. Elke week-map heeft naast de uitwerking (`README.md`) ook een `TODO.md` met wat er nog gedaan moet worden.

De infrastructuurcode gebruikt [OpenTofu](https://opentofu.org/) in plaats van HashiCorp Terraform: dezelfde taal en providers, maar open source gebleven. Zie [week 1](week-1/README.md) voor waarom. Installatiehandleiding (van nul af aan opzetten): [`setup/README.md`](setup/README.md).

Ik werk hierbij met AI-assistentie, via IDE-integraties. De opzet, keuzes en het testen zijn van mij, maar een deel van het typewerk en het debuggen doe ik samen met deze tools.

- Anthropic. (2026). *Claude (Sonnet 5)* [Large language model]. [https://claude.ai](https://claude.ai)
- Mistral AI. (2026). *Mistral Vibe (GLM 5.3)* [Large language model]. [https://mistral.ai](https://mistral.ai)

**PDF/ODT-export van deze portfolio.** Bij elke push naar `uitwerkingen` zet een GitHub Actions-workflow ([`.github/workflows/docs.yml`](.github/workflows/docs.yml)) automatisch een PDF en een ODT klaar met alle informatie uit de repo, als assets bij een nieuwe [release](../../releases). Ik heb deze exports dus niet zelf handmatig gemaakt; ze worden automatisch gegenereerd vanuit de README's via [`setup/export-portfolio.sh`](setup/export-portfolio.sh) (pandoc + typst).

De repository staat ook gespiegeld op [CodeTrunk](https://repos.codetrunk.eu/Stensel8/Cloud-Security), een Europese Git-host met IPv6-ondersteuning: voor redundantie en omdat ik niet alles alleen op GitHub (VS) wil hebben staan.

- [Week 1](week-1/README.md): 3-tier infrastructuur, netwerktekening, Shared Responsibility Model, bastion host
- [Week 2](week-2/README.md): IAM-authenticatie naar RDS, least privilege, Entra ID-federatie
- [Week 3](week-3/README.md): North-South/East-West segmentatie, immutable infrastructure via een pipeline
- [Week 4](week-4/README.md): Dataclassificatie, S3-encryptie, bring your own key, logging en alerting
- [Week 5](week-5/README.md): Incident response plan, application security, STRIDE-threatmodel
- [Week 6](week-6/README.md): Centrale logging, AWS-detectiediensten, Security Hub, log-analyse met Python en IsolationForest
- [Week 7](week-7/README.md): Security frameworks, NIST CSF, AVG
