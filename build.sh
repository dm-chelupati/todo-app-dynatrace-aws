#!/bin/bash

echo "Building Lambda deployment packages..."

# Create temp directory
mkdir -p /tmp/lambda-build

# Build Lambda layer with dependencies
cd app/lambda
pip install -r requirements.txt -t /tmp/lambda-build/python/
cd /tmp/lambda-build
zip -r lambda_layer.zip python/
mv lambda_layer.zip $OLDPWD/terraform/

# Clean up
rm -rf /tmp/lambda-build

echo "Lambda packages built successfully!"
