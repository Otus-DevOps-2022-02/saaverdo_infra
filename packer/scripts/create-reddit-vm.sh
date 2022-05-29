gcloud compute instances create \
  --boot-disk-size=10GB \
  --image=reddit-full-otus-w-hw5 \
  --machine-type=e2-medium \
  --tags puma-server --restart-on-failure \
  --zone=europe-west4-a reddit-app
