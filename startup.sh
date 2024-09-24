#!/bin/bash

LOGFILE=".logfile.log"

# Function to log messages to both console and log file
log_message() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOGFILE"
}

# Check if global_config.cfg file exists
GLOBAL_CONFIG_FILE="global_config.cfg"
if [ ! -f "$GLOBAL_CONFIG_FILE" ]; then
  log_message "Error: Global config file '$GLOBAL_CONFIG_FILE' not found."
  exit 1
fi

# Source the global config file to get AWS_ACCOUNT_ID, AWS_ACCOUNT_REGION, and $AWS_PROFILE
source "$GLOBAL_CONFIG_FILE"


# Ensure BUCKET_NAME is all lowercase
export BUCKET_NAME="my-terraform-state-bucket-app-plony-2"
# Ensure BUCKET_NAME is all lowercase
#export BUCKET_NAME="flir-cloud-${CUSTOMER_NAME,,}-terraform-s3"

log_message "Using BUCKET_NAME: $BUCKET_NAME"

export TF_BACKEND_DYNAMODB_TABLE='terraform-locks'

# Function to check AWS permissions
check_permissions() {
    aws s3api list-buckets --region $AWS_ACCOUNT_REGION --profile $AWS_PROFILE >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        log_message "Insufficient permissions to list S3 buckets. Please check your AWS credentials and permissions." >&2
        exit 1
    fi

    aws dynamodb list-tables --region $AWS_ACCOUNT_REGION --profile $AWS_PROFILE >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        log_message "Insufficient permissions to list DynamoDB tables. Please check your AWS credentials and permissions." >&2
        exit 1
    fi
}

# Function to create S3 bucket
create_bucket() {
    echo "Creating S3 bucket $BUCKET_NAME..."
    echo "Creating S3 bucket $BUCKET_NAME... $AWS_ACCOUNT_REGION" | tee -a "$LOGFILE"
    aws s3api create-bucket --bucket $BUCKET_NAME --region $AWS_ACCOUNT_REGION --create-bucket-configuration LocationConstraint=$AWS_ACCOUNT_REGION --profile $AWS_PROFILE 2>&1 | tee -a "$LOGFILE"
}

# Function to add tags to S3 bucket
tag_bucket() {
    aws s3api put-bucket-tagging --bucket $BUCKET_NAME --tagging 'TagSet=[{Key=Environment,Value=Production},{Key=Project,Value=Flir-Cloud}]' --region $AWS_ACCOUNT_REGION --profile $AWS_PROFILE 2>&1 | tee -a "$LOGFILE"
}

# Function to enable versioning on S3 bucket
enable_versioning() {
    aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled --region $AWS_ACCOUNT_REGION --profile $AWS_PROFILE 2>&1 | tee -a "$LOGFILE"
}

# Check if bucket exists
bucket_exists() {
    aws s3api head-bucket --bucket $BUCKET_NAME --region $AWS_ACCOUNT_REGION --profile $AWS_PROFILE  2>/dev/null
    return $?
}

# Function to create DynamoDB table
create_dynamodb_table() {
    aws dynamodb create-table --table-name $TF_BACKEND_DYNAMODB_TABLE \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region $AWS_ACCOUNT_REGION --profile $AWS_PROFILE 2>&1 | tee -a "$LOGFILE"
}

# Function to check if DynamoDB table exists
dynamodb_table_exists() {
    aws dynamodb describe-table \
        --table-name "$TF_BACKEND_DYNAMODB_TABLE" \
        --region "$AWS_ACCOUNT_REGION" \
        --profile "$AWS_PROFILE" \
        --no-paginate \
        --output json >/dev/null 2>&1
    return $?
}

# Check permissions
check_permissions

# Try to create the bucket
if bucket_exists; then
    log_message "Bucket already exists. Ensuring configuration..."
else
    output=$(create_bucket)
    if [ $? -eq 0 ]; then
        log_message "Bucket created successfully."
    else
        log_message "Failed to create bucket: $output" >&2 | tee -a "$LOGFILE"
        exit 1
    fi
fi

# Try to tag the bucket
tag_output=$(tag_bucket)
if [ $? -eq 0 ]; then
    log_message "Bucket tagged successfully."
else
    log_message "Failed to tag bucket: $tag_output" >&2 | tee -a "$LOGFILE"
    exit 1
fi

# Try to enable versioning on the bucket
versioning_output=$(enable_versioning)
if [ $? -eq 0 ]; then
    log_message "Versioning enabled successfully."
else
    log_message "Failed to enable versioning: $versioning_output" >&2 | tee -a "$LOGFILE"
    exit 1
fi

# Try to create the DynamoDB table
if dynamodb_table_exists; then
    log_message "DynamoDB table $TF_BACKEND_DYNAMODB_TABLE already exists."
else
    dynamodb_output=$(create_dynamodb_table)
    if [ $? -eq 0 ]; then
        log_message "DynamoDB table created successfully."
        waiting=true
    else
        log_message "Failed to create DynamoDB table: $dynamodb_output" >&2 | tee -a "$LOGFILE"
        exit 1
    fi
fi

# Sleep to allow AWS resources to propagate
if [ "$waiting" = true ]; then
    log_message "Sleeping for 30 seconds to allow AWS resources to propagate..."
    sleep 30
else
    log_message "DynamoDB table already exists."
fi

# Checking if the DynamoDB table is up
max_attempts=5
attempt=1
table_up=false

while [ $attempt -le $max_attempts ]; do
    log_message "Attempt $attempt: Checking if DynamoDB table $TF_BACKEND_DYNAMODB_TABLE is up..."
    aws dynamodb describe-table --table-name $TF_BACKEND_DYNAMODB_TABLE --region $AWS_ACCOUNT_REGION --profile $AWS_PROFILE >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        log_message "DynamoDB table $TF_BACKEND_DYNAMODB_TABLE is up."
        table_up=true
        break
    else
        log_message "DynamoDB table $TF_BACKEND_DYNAMODB_TABLE is not up. Waiting for 10 seconds before rechecking..."
        sleep 10
    fi
    attempt=$((attempt + 1))
done

if [ "$table_up" = false ]; then
    log_message "DynamoDB table $TF_BACKEND_DYNAMODB_TABLE was not created after $max_attempts attempts. Exiting..." >&2 | tee -a "$LOGFILE"
    exit 1
fi

export AWS_PROFILE=$AWS_PROFILE
export TF_BACKEND_BUCKET=$BUCKET_NAME
export TF_BACKEND_REGION=$AWS_ACCOUNT_REGION
export TF_VAR_ACCOUNT=$AWS_ACCOUNT_ID
export TF_VAR_REGION=$AWS_ACCOUNT_REGION
export TF_VAR_PROFILE=$AWS_PROFILE

echo "ACCOUNT = $TF_VAR_ACCOUNT"
echo "REGION = $TF_VAR_REGION"
echo "PROFILE = $TF_VAR_PROFILE"

log_message "Creating infrastructure..."
bash ./terraform-up.sh "$@"  2>&1 | tee -a "$LOGFILE"