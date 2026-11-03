#!/bin/bash

# Check if all required arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <source_namespace> <destination_namespace> <secret_name>"
    exit 1
fi

# Assign command line arguments to variables
SOURCE_NAMESPACE=$1
DESTINATION_NAMESPACE=$2
SECRET_NAME=$3

# Function to copy a single secret
copy_secret() {
    echo "Copying secret '$SECRET_NAME' from '$SOURCE_NAMESPACE' to '$DESTINATION_NAMESPACE'"
    
    # Check if the secret exists in the source namespace
    if ! kubectl get secret $SECRET_NAME -n $SOURCE_NAMESPACE &> /dev/null; then
        echo "Error: Secret '$SECRET_NAME' not found in namespace '$SOURCE_NAMESPACE'"
        exit 1
    fi

    # Copy the secret
    kubectl get secret $SECRET_NAME -n $SOURCE_NAMESPACE -o yaml | \
    sed "s/namespace: $SOURCE_NAMESPACE/namespace: $DESTINATION_NAMESPACE/" | \
    sed '/creationTimestamp:/d' | \
    sed '/resourceVersion:/d' | \
    sed '/uid:/d' | \
    kubectl apply -n $DESTINATION_NAMESPACE -f -

    if [ $? -eq 0 ]; then
        echo "Secret '$SECRET_NAME' successfully copied to '$DESTINATION_NAMESPACE'"
    else
        echo "Error: Failed to copy secret '$SECRET_NAME'"
        exit 1
    fi
}

# Execute the function to copy the secret
copy_secret

echo "Verifying secret in $DESTINATION_NAMESPACE:"
kubectl get secret $SECRET_NAME -n $DESTINATION_NAMESPACE