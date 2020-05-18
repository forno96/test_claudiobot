#!/bin/bash
#set -x

# Utilizzare questo script come punto di partenza per la creazione del proprio ingress.yml

# Make sure the cluster is running and get the ip_address
ip_addr=$(ibmcloud cs workers $PIPELINE_KUBERNETES_CLUSTER_NAME | grep normal | awk '{ print $2 }')
if [ -z $ip_addr ]; then
  echo "$PIPELINE_KUBERNETES_CLUSTER_NAME not created or workers not ready"
  exit 1
fi

# Initialize script variables
NAME="$IDS_PROJECT_NAME"
IMAGE="$PIPELINE_IMAGE_URL"
if [ -z IMAGE ]; then
  echo "$IMAGE not set. If using $PIPELINE_IMAGE_URL this variable is only configured when a "Container Registry" build job is used as the stage input."
  exit 1
fi
PORT=$(ibmcloud cr image-inspect $IMAGE --format '{{ range $key,$value := .ContainerConfig.ExposedPorts }} {{ $key }} {{ "" }} {{end}}' | sed -E 's/^[^0-9]*([0-9]+).*$/\1/')
if [ -z "$PORT" ]; then
    PORT=5000
    echo "Port not found in Dockerfile, using $PORT"
fi

echo ""
echo "Deploy environment variables:"
echo "NAME=$NAME"
echo "IMAGE=$IMAGE"
echo "PORT=$PORT"
echo ""

DEPLOYMENT_FILE="ingress.yml"
echo "Creating deployment file $DEPLOYMENT_FILE"

# Build the deployment file
DEPLOYMENT=$(cat <<EOF''
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: claudio-ingress
spec:
  rules:
  - host: devbo-kubestd-mi01-feb0a24d32c3bf6b1218d75d58d7acb5-0000.mil01.containers.appdomain.cloud
    http:
      paths:
      - path: /claudiobot
        backend:
          serviceName: toolchaintest-bo
          servicePort: 80
EOF
)

# Substitute the variables
echo "$DEPLOYMENT" > $DEPLOYMENT_FILE
sed -i 's/$NAME/'"$NAME"'/g' $DEPLOYMENT_FILE
sed -i 's=$IMAGE='"$IMAGE"'=g' $DEPLOYMENT_FILE
sed -i 's/$PORT/'"$PORT"'/g' $DEPLOYMENT_FILE

# Show the file that is about to be executed
echo ""
echo "DEPLOYING USING MANIFEST:"
echo "cat $DEPLOYMENT_FILE"
cat $DEPLOYMENT_FILE
echo ""

# Execute the file
echo "KUBERNETES COMMAND:"
echo "kubectl --namespace ${CLUSTER_NAMESPACE} apply -f $DEPLOYMENT_FILE"
kubectl --namespace ${CLUSTER_NAMESPACE} apply -f $DEPLOYMENT_FILE
echo ""

echo ""
echo "DEPLOYED INGRESS:"
kubectl describe ingress ClaudioIngress
echo ""
