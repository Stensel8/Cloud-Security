# Week 4: S3-buckets per classificatie (Openbaar/Intern/Geheim), encryptie, policies, BYOK voor de geheime
# bucket, en CloudTrail/EventBridge/CloudWatch voor logging en alerting op die bucket.

locals {
  # Bucketnamen moeten wereldwijd uniek zijn; vul een eigen, korte suffix in (bv. je studentnummer).
  bucket_suffix = "REPLACE_WITH_UNIQUE_SUFFIX"
}

###################################################
# 4.3: eigen (BYOK) KMS-sleutel voor de geheime bucket.
# Het sleutelmateriaal zelf genereer je met OpenSSL en importeer je los met de AWS CLI (geen Terraform-
# resource voor de import zelf, dat is een eenmalige, stateful actie) - zie week-4/README.md voor de stappen.
resource "aws_kms_external_key" "geheim_byok" {
  description             = "BYOK-sleutel (eigen keymateriaal) voor de S3-bucket met geheime documenten"
  deletion_window_in_days = 7
  key_usage               = "ENCRYPT_DECRYPT"

  tags = {
    classificatie = "geheim"
  }
}

###################################################
# 4.1/4.2: drie buckets, één per classificatie.

resource "aws_s3_bucket" "openbaar" {
  bucket = "saxit-data-openbaar-${local.bucket_suffix}"
  tags   = { classificatie = "openbaar" }
}

resource "aws_s3_bucket" "intern" {
  bucket = "saxit-data-intern-${local.bucket_suffix}"
  tags   = { classificatie = "intern" }
}

resource "aws_s3_bucket" "geheim" {
  bucket = "saxit-data-geheim-${local.bucket_suffix}"
  tags   = { classificatie = "geheim" }
}

# Standaardencryptie: SSE-S3 (AES256) voor openbaar/intern, SSE-KMS met eigen sleutel voor geheim.
resource "aws_s3_bucket_server_side_encryption_configuration" "openbaar" {
  bucket = aws_s3_bucket.openbaar.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "intern" {
  bucket = aws_s3_bucket.intern.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "geheim" {
  bucket = aws_s3_bucket.geheim.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_external_key.geheim_byok.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "openbaar" {
  bucket                  = aws_s3_bucket.openbaar.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  # "Openbaar" is een classificatie van het dóel van de data (voor iedereen binnen SaxIT leesbaar), geen
  # publiek-op-internet bucket. Publieke toegang blijft net als bij de andere twee dicht.
}
resource "aws_s3_bucket_public_access_block" "intern" {
  bucket                  = aws_s3_bucket.intern.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_public_access_block" "geheim" {
  bucket                  = aws_s3_bucket.geheim.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Policy: encryptie verplicht bij elke upload, en het object moet getagd zijn met de classificatie die bij
# déze bucket hoort (zo kan een "geheim"-bestand niet per ongeluk in de "openbaar"-bucket belanden).
data "aws_iam_policy_document" "classified_bucket_policy" {
  for_each = {
    openbaar = { bucket = aws_s3_bucket.openbaar, classificatie = "openbaar", sse = "AES256" }
    intern   = { bucket = aws_s3_bucket.intern, classificatie = "intern", sse = "AES256" }
    geheim   = { bucket = aws_s3_bucket.geheim, classificatie = "geheim", sse = "aws:kms" }
  }

  statement {
    sid    = "DenyUnEncryptedObjectUploads"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${each.value.bucket.arn}/*"]
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = [each.value.sse]
    }
  }

  statement {
    sid    = "DenyWrongClassificationTag"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${each.value.bucket.arn}/*"]
    condition {
      test     = "StringNotEquals"
      variable = "s3:RequestObjectTag/classificatie"
      values   = [each.value.classificatie]
    }
  }
}

resource "aws_s3_bucket_policy" "openbaar" {
  bucket = aws_s3_bucket.openbaar.id
  policy = data.aws_iam_policy_document.classified_bucket_policy["openbaar"].json
}
resource "aws_s3_bucket_policy" "intern" {
  bucket = aws_s3_bucket.intern.id
  policy = data.aws_iam_policy_document.classified_bucket_policy["intern"].json
}
resource "aws_s3_bucket_policy" "geheim" {
  bucket = aws_s3_bucket.geheim.id
  policy = data.aws_iam_policy_document.classified_bucket_policy["geheim"].json
}

###################################################
# 4.4: logging + alert op downloads uit de geheime bucket.

resource "aws_cloudtrail" "geheim_data_events" {
  name                          = "saxit-geheim-bucket-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = false
  is_multi_region_trail         = false

  event_selector {
    read_write_type           = "All"
    include_management_events = false

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.geheim.arn}/"]
    }
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail_logs]
}

# Los bucket voor de CloudTrail-logs zelf (mag nooit dezelfde bucket zijn als wat je bijhoudt).
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "saxit-cloudtrail-logs-${local.bucket_suffix}"
}

data "aws_iam_policy_document" "cloudtrail_logs" {
  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloudtrail_logs.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail_logs.arn]
  }
}

resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  policy = data.aws_iam_policy_document.cloudtrail_logs.json
}

# EventBridge-rule: elke GetObject op de geheime bucket (via CloudTrail-data-events) -> SNS -> e-mail.
resource "aws_cloudwatch_event_rule" "geheim_object_read" {
  name = "saxit-geheim-object-read"
  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["s3.amazonaws.com"]
      eventName   = ["GetObject"]
      requestParameters = {
        bucketName = [aws_s3_bucket.geheim.id]
      }
    }
  })
}

resource "aws_sns_topic" "geheim_alerts" {
  name = "saxit-geheim-bucket-alerts"
}

resource "aws_sns_topic_subscription" "geheim_alerts_email" {
  topic_arn = aws_sns_topic.geheim_alerts.arn
  protocol  = "email"
  endpoint  = "REPLACE_WITH_YOUR_EMAIL"
}

resource "aws_cloudwatch_event_target" "geheim_object_read_to_sns" {
  rule      = aws_cloudwatch_event_rule.geheim_object_read.name
  target_id = "sns"
  arn       = aws_sns_topic.geheim_alerts.arn
}

###################################################
# CloudWatch-dashboard met bucketmetrics.
resource "aws_cloudwatch_dashboard" "s3_classificatie" {
  dashboard_name = "saxit-s3-classificatie"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Aantal objecten per classificatie-bucket"
          region = "us-east-1"
          metrics = [
            ["AWS/S3", "NumberOfObjects", "BucketName", aws_s3_bucket.openbaar.id, "StorageType", "AllStorageTypes"],
            ["AWS/S3", "NumberOfObjects", "BucketName", aws_s3_bucket.intern.id, "StorageType", "AllStorageTypes"],
            ["AWS/S3", "NumberOfObjects", "BucketName", aws_s3_bucket.geheim.id, "StorageType", "AllStorageTypes"],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Bucketgrootte per classificatie"
          region = "us-east-1"
          metrics = [
            ["AWS/S3", "BucketSizeBytes", "BucketName", aws_s3_bucket.openbaar.id, "StorageType", "StandardStorage"],
            ["AWS/S3", "BucketSizeBytes", "BucketName", aws_s3_bucket.intern.id, "StorageType", "StandardStorage"],
            ["AWS/S3", "BucketSizeBytes", "BucketName", aws_s3_bucket.geheim.id, "StorageType", "StandardStorage"],
          ]
        }
      }
    ]
  })
}
