# Week 4: S3-buckets per classificatie (Openbaar/Intern/Geheim), encryptie, policies, BYOK voor de geheime
# bucket, en CloudTrail/EventBridge/CloudWatch voor logging en alerting op die bucket.
#
# Alleen de KMS-sleutel (BYOK) staat nog in OpenTofu. De rest (buckets, policies, CloudTrail, EventBridge, SNS,
# dashboard) is verplaatst naar week-4/scripts/data-protection-setup.sh, een los AWS CLI-script - zie de
# toelichting in week-4/README.md voor waarom. Kort: de AWS-provider leest bij ieder aws_s3_bucket-resource de
# object lock-configuratie uit als onderdeel van zijn normale Create/Read-cyclus, en dat is in de Learner Lab
# geblokkeerd door een Service Control Policy. Dat blokkeert niet alleen die ene bucket, maar via Terraform's
# "tainted"-mechanisme ook alles wat eraan hangt, met een onstabiele applystate tot gevolg. Een gewoon
# "aws s3api create-bucket" (en de rest van het script) doet die extra leesactie nooit en heeft dit probleem niet.

###################################################
# 4.3: eigen (BYOK) KMS-sleutel voor de geheime bucket.
# Het sleutelmateriaal zelf genereer je met OpenSSL en importeer je los met de AWS CLI (geen OpenTofu-resource
# voor de import zelf, dat is een eenmalige, stateful actie) - zie week-4/README.md voor de stappen.
resource "aws_kms_external_key" "geheim_byok" {
  description             = "BYOK-sleutel (eigen keymateriaal) voor de S3-bucket met geheime documenten"
  deletion_window_in_days = 7
  key_usage               = "ENCRYPT_DECRYPT"

  tags = {
    classificatie = "geheim"
  }
}

# Vaste alias zodat week-4/scripts/data-protection-setup.sh de sleutel kan opzoeken zonder een OpenTofu-output
# nodig te hebben.
resource "aws_kms_alias" "geheim_byok" {
  name          = "alias/saxit-geheim-byok"
  target_key_id = aws_kms_external_key.geheim_byok.id
}
