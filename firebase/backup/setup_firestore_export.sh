#!/bin/bash
# automated data protection pipeline

# Run this script to configure automated daily exports of Firestore data to a Cloud Storage bucket.
# Requires: gcloud CLI configured and authenticated, Firebase Blaze plan.

PROJECT_ID=$(gcloud config get-value project)
BUCKET_NAME="gs://${PROJECT_ID}-firestore-backups"
LOCATION="us-central1" # Can be updated to match specific region

echo "Setting up Firestore backups for project: $PROJECT_ID"

# 1. Create a Cloud Storage bucket for backups
echo "Creating Cloud Storage bucket $BUCKET_NAME in $LOCATION..."
gcloud storage buckets create $BUCKET_NAME --location=$LOCATION

# 2. Add a 30-day lifecycle rule to the bucket
echo "Configuring 30-day object lifecycle retention on the bucket..."
cat << EOF > lifecycle.json
{
  "rule": [
    {
      "action": {"type": "Delete"},
      "condition": {"age": 30}
    }
  ]
}
EOF
gcloud storage buckets update $BUCKET_NAME --lifecycle-file=lifecycle.json
rm lifecycle.json

# 3. Create a Cloud Scheduler job to run daily
echo "Creating Cloud Scheduler job for daily Firestore exports..."
# We use the default App Engine service account, ensure it has Datastore Import Export Admin role
gcloud scheduler jobs create http firestore-daily-export \
  --schedule="0 2 * * *" \
  --uri="https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default):exportDocuments" \
  --message-body="{\"outputUriPrefix\": \"${BUCKET_NAME}\"}" \
  --oauth-service-account-email="${PROJECT_ID}@appspot.gserviceaccount.com" \
  --headers="Content-Type=application/json" \
  --location=$LOCATION

echo "Setup complete! Backups will run daily at 2:00 AM."
