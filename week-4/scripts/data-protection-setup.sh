#!/usr/bin/env bash
# Week 4.1 t/m 4.4: S3-buckets per classificatie, bucket-policies, CloudTrail data events, EventBridge-alert
# naar SNS, en een CloudWatch-dashboard.
#
# Dit is een los AWS CLI-script in plaats van OpenTofu-resources: de AWS-provider leest bij ieder
# aws_s3_bucket-resource standaard ook de object lock-configuratie uit (een verouderd/computed attribuut,
# onderdeel van zijn normale Create/Read-cyclus), en die leesactie is in de AWS Academy Learner Lab geblokkeerd
# door een Service Control Policy op organisatieniveau - niet op te lossen met IAM-rechten op je eigen rol.
# OpenTofu markeert de bucket dan als "tainted", en een volgende apply probeert 'm daardoor te vervangen -
# wat weer exact dezelfde leesfout raakt, dus weer tainted wordt. Resultaat: een oneindige lus, of op zijn
# minst een hoop handmatig untainten en losse "-refresh=false"-applies om er doorheen te komen (zie
# setup/README.md voor hoe dat wél lukt via OpenTofu, mocht je dat willen zien). Een gewoon
# "aws s3api create-bucket" doet die extra leesactie nooit, en heeft dit probleem dus helemaal niet.
#
# Idempotent: opnieuw draaien hergebruikt bestaande resources i.p.v. te falen.
#
# Gebruik:  ./data-protection-setup.sh <unieke-suffix> <mailadres-voor-de-alert>
# Bijv.:    ./data-protection-setup.sh 550600 550600@student.saxion.nl

set -uo pipefail

SUFFIX="${1:?gebruik: ./data-protection-setup.sh <unieke-suffix> <mailadres>}"
ALERT_EMAIL="${2:?gebruik: ./data-protection-setup.sh <unieke-suffix> <mailadres>}"
REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$REGION"

KMS_ALIAS="alias/saxit-geheim-byok" # door OpenTofu aangemaakt, zie opentofu/data-protection.tf
BUCKET_OPENBAAR="saxit-data-openbaar-$SUFFIX"
BUCKET_INTERN="saxit-data-intern-$SUFFIX"
BUCKET_GEHEIM="saxit-data-geheim-$SUFFIX"
BUCKET_LOGS="saxit-cloudtrail-logs-$SUFFIX"
TRAIL_NAME="saxit-geheim-bucket-trail"
TOPIC_NAME="saxit-geheim-bucket-alerts"
RULE_NAME="saxit-geheim-object-read"
DASHBOARD_NAME="saxit-s3-classificatie"

step() { echo; echo "=== $*"; }
ok()   { echo "    OK: $*"; }
warn() { echo "    LET OP: $*"; }

KEY_ARN="$(aws kms describe-key --key-id "$KMS_ALIAS" --query KeyMetadata.Arn --output text 2>/dev/null)" \
  || { echo "Kon $KMS_ALIAS niet vinden - draai eerst 'tofu apply' (de BYOK-sleutel staat nog in OpenTofu)." >&2; exit 1; }

###################################################
make_bucket() {
  local b="$1"
  if aws s3api head-bucket --bucket "$b" 2>/dev/null; then
    ok "bucket $b bestaat al"
  else
    aws s3api create-bucket --bucket "$b" >/dev/null && ok "bucket $b aangemaakt"
  fi
  aws s3api put-public-access-block --bucket "$b" --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
}

# Policy per classificatie: alleen HTTPS, encryptie verplicht van het juiste type (geheim: ook de juiste
# KMS-sleutel), en het object moet getagd zijn met de classificatie die bij déze bucket hoort - zo kan een
# "geheim"-bestand niet per ongeluk (of expres) als "openbaar" getagd in de verkeerde bucket belanden.
bucket_policy() {
  local classificatie="$1" arn="arn:aws:s3:::saxit-data-$1-$SUFFIX" sse="AES256" kms_statement=""
  if [[ "$classificatie" == geheim ]]; then
    sse="aws:kms"
    kms_statement='{"Sid":"DenyWrongKmsKey","Effect":"Deny","Principal":"*","Action":"s3:PutObject","Resource":"'"$arn"'/*","Condition":{"StringNotEquals":{"s3:x-amz-server-side-encryption-aws-kms-key-id":"'"$KEY_ARN"'"}}},'
  fi
  cat <<EOF
{"Version":"2012-10-17","Statement":[
{"Sid":"DenyInsecureTransport","Effect":"Deny","Principal":"*","Action":"s3:*","Resource":["$arn","$arn/*"],"Condition":{"Bool":{"aws:SecureTransport":"false"}}},
{"Sid":"DenyUnEncryptedObjectUploads","Effect":"Deny","Principal":"*","Action":"s3:PutObject","Resource":"$arn/*","Condition":{"StringNotEquals":{"s3:x-amz-server-side-encryption":"$sse"}}},
$kms_statement
{"Sid":"DenyWrongClassificationTag","Effect":"Deny","Principal":"*","Action":"s3:PutObject","Resource":"$arn/*","Condition":{"StringNotEquals":{"s3:RequestObjectTag/classificatie":"$classificatie"}}}
]}
EOF
}

bucket_encryption() {
  if [[ "$1" == geheim ]]; then
    echo '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"aws:kms","KMSMasterKeyID":"'"$KEY_ARN"'"},"BucketKeyEnabled":true}]}'
  else
    echo '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
  fi
}

step "4.1/4.2 Drie buckets, één per classificatie"
for c in openbaar intern geheim; do
  b="saxit-data-$c-$SUFFIX"
  make_bucket "$b"
  aws s3api put-bucket-tagging --bucket "$b" --tagging "TagSet=[{Key=classificatie,Value=$c}]"
  aws s3api put-bucket-encryption --bucket "$b" --server-side-encryption-configuration "$(bucket_encryption "$c")"
  aws s3api put-bucket-policy --bucket "$b" --policy "$(bucket_policy "$c")" && ok "policy + encryptie op $b"
done

###################################################
step "4.4 Logging: CloudTrail data events op de geheime bucket"
make_bucket "$BUCKET_LOGS"
aws s3api put-bucket-policy --bucket "$BUCKET_LOGS" --policy "$(cat <<EOF
{"Version":"2012-10-17","Statement":[
{"Sid":"AWSCloudTrailAclCheck","Effect":"Allow","Principal":{"Service":"cloudtrail.amazonaws.com"},"Action":"s3:GetBucketAcl","Resource":"arn:aws:s3:::$BUCKET_LOGS"},
{"Sid":"AWSCloudTrailWrite","Effect":"Allow","Principal":{"Service":"cloudtrail.amazonaws.com"},"Action":"s3:PutObject","Resource":"arn:aws:s3:::$BUCKET_LOGS/*","Condition":{"StringEquals":{"s3:x-amz-acl":"bucket-owner-full-control"}}}
]}
EOF
)" && ok "policy op $BUCKET_LOGS"

if aws cloudtrail get-trail --name "$TRAIL_NAME" >/dev/null 2>&1; then
  ok "trail $TRAIL_NAME bestaat al"
else
  aws cloudtrail create-trail --name "$TRAIL_NAME" --s3-bucket-name "$BUCKET_LOGS" \
    --no-include-global-service-events --no-is-multi-region-trail >/dev/null && ok "trail $TRAIL_NAME aangemaakt"
fi
aws cloudtrail put-event-selectors --trail-name "$TRAIL_NAME" --event-selectors \
  '[{"ReadWriteType":"All","IncludeManagementEvents":false,"DataResources":[{"Type":"AWS::S3::Object","Values":["arn:aws:s3:::'"$BUCKET_GEHEIM"'/"]}]}]' >/dev/null \
  && ok "data events voor $BUCKET_GEHEIM"
aws cloudtrail start-logging --name "$TRAIL_NAME" && ok "trail logt"

###################################################
step "4.4 Alert: CloudTrail -> EventBridge -> SNS -> e-mail"
TOPIC_ARN="$(aws sns create-topic --name "$TOPIC_NAME" --query TopicArn --output text)"
aws sns set-topic-attributes --topic-arn "$TOPIC_ARN" --attribute-name Policy --attribute-value \
  '{"Version":"2012-10-17","Statement":[{"Sid":"EventBridgePublish","Effect":"Allow","Principal":{"Service":"events.amazonaws.com"},"Action":"sns:Publish","Resource":"'"$TOPIC_ARN"'"}]}'
if aws sns list-subscriptions-by-topic --topic-arn "$TOPIC_ARN" --query 'Subscriptions[].Endpoint' --output text | grep -qw "$ALERT_EMAIL"; then
  ok "$ALERT_EMAIL is al geabonneerd"
else
  aws sns subscribe --topic-arn "$TOPIC_ARN" --protocol email --notification-endpoint "$ALERT_EMAIL" >/dev/null
  ok "bevestigingsmail gestuurd naar $ALERT_EMAIL - klik de link aan voordat de alert echt afgaat"
fi

EVENT_PATTERN='{"source":["aws.s3"],"detail-type":["AWS API Call via CloudTrail"],"detail":{"eventSource":["s3.amazonaws.com"],"eventName":["GetObject"],"requestParameters":{"bucketName":["'"$BUCKET_GEHEIM"'"]}}}'
if aws events put-rule --name "$RULE_NAME" --event-pattern "$EVENT_PATTERN" \
     --description "Geheim object gelezen uit $BUCKET_GEHEIM" >/dev/null; then
  aws events put-targets --rule "$RULE_NAME" --targets '[{"Id":"sns","Arn":"'"$TOPIC_ARN"'"}]' >/dev/null \
    && ok "EventBridge-rule $RULE_NAME met SNS-target"
else
  warn "EventBridge-rule geweigerd door de Learner Lab - toon in het verslag het event pattern hieronder:"
  echo "$EVENT_PATTERN"
fi

###################################################
step "CloudWatch-dashboard met bucketmetrics"
objects=""; storage=""
for c in openbaar intern geheim; do
  b="saxit-data-$c-$SUFFIX"
  objects+='["AWS/S3","NumberOfObjects","BucketName","'"$b"'","StorageType","AllStorageTypes"],'
  storage+='["AWS/S3","BucketSizeBytes","BucketName","'"$b"'","StorageType","StandardStorage"],'
done
DASHBOARD_BODY='{"widgets":[
{"type":"metric","x":0,"y":0,"width":12,"height":6,"properties":{"title":"Aantal objecten per classificatie-bucket","region":"'"$REGION"'","metrics":['"${objects%,}"']}},
{"type":"metric","x":0,"y":6,"width":12,"height":6,"properties":{"title":"Bucketgrootte per classificatie","region":"'"$REGION"'","metrics":['"${storage%,}"']}}
]}'
aws cloudwatch put-dashboard --dashboard-name "$DASHBOARD_NAME" --dashboard-body "$DASHBOARD_BODY" >/dev/null \
  && ok "dashboard $DASHBOARD_NAME"

###################################################
step "Klaar"
cat <<EOF
    Buckets: $BUCKET_OPENBAAR, $BUCKET_INTERN, $BUCKET_GEHEIM
    Logs:    $BUCKET_LOGS
    KMS key: $KEY_ARN ($KMS_ALIAS)
    Volgende stappen:
      1. Bevestig de SNS-mail (als die net verstuurd is).
      2. Upload de demo-bestanden (zie week-4/README.md, 4.2) om de policy te testen.
EOF
