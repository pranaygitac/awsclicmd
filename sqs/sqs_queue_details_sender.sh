#!/bin/bash

# Define the output CSV file name sahil
OUTPUT_FILE="sqs_queue_details_prodvir.csv"

# Define the AWS profile and region
AWS_PROFILE_NAME="default"
AWS_REGION="eu-central-1"

# Define the number of parallel processes
PARALLEL_PROCESSES=20

# Remove the queue name prefix option to fetch all queues
 Q_NAME_CONTAINS="norm"

###########################################################################################################################################
# Print the CSV header
echo "QueueName,MessagesAvailable,MessagesInFlight" > $OUTPUT_FILE

# TO Get all queue URLs and process them in parallel
# Remove --queue-name-prefix $Q_NAME_CONTAINS
aws sqs list-queues --profile $AWS_PROFILE_NAME --region $AWS_REGION --queue-name-prefix $Q_NAME_CONTAINS --no-paginate | \
  jq -r '.QueueUrls[]' | \
  xargs -P $PARALLEL_PROCESSES -I {} bash -c '
    queue_url="$1"
    
    # Get queue attributes with a single --attribute-names option
    QUEUE_ATTRIBUTES=$(aws sqs get-queue-attributes \
      --queue-url "$queue_url" \
      --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
      --query "Attributes" \
      --profile '"$AWS_PROFILE_NAME"' --region '"$AWS_REGION"')

    # Extract attribute values
    MESSAGES_AVAILABLE=$(echo $QUEUE_ATTRIBUTES | jq -r ".ApproximateNumberOfMessages")
    MESSAGES_IN_FLIGHT=$(echo $QUEUE_ATTRIBUTES | jq -r ".ApproximateNumberOfMessagesNotVisible")
    
    # Check for non-zero messages and print to stdout
    if [[ "$MESSAGES_AVAILABLE" -gt 0 || "$MESSAGES_IN_FLIGHT" -gt 0 ]]; then
      QUEUE_NAME=$(basename "$queue_url")
      echo "$QUEUE_NAME,$MESSAGES_AVAILABLE,$MESSAGES_IN_FLIGHT"
    fi
  ' _ {} >> $OUTPUT_FILE

echo "Output saved to $OUTPUT_FILE"
