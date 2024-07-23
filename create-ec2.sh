#!/bin/bash

# Define the instances
instances=("mongodb redis mysql rabbitmq catalogue user cart shipping payment web")

# Define the domain name
DOMAIN_NAME="daws78s.online"
HOSTED_ZONE_ID="Z08884492QFPW45HM4UQO"

# Create the instances and Route 53 records
for name in "${instances[@]}"; do
    if [ "$name" == "mysql" ] || [ "$name" == "shipping" ]; then
        instance_type="t3.medium"
    else
        instance_type="t3.micro"
    fi

    echo "Creating instance $name with type $instance_type..."

    # Create the EC2 instance
    instance_id=$(aws ec2 run-instances \
        --image-id ami-041e2ea9402c46c32 \
        --instance-type $instance_type \
        --security-group-ids sg-0fea5e49e962e81c9 \
        --subnet-id subnet-0ea509ad4cba242d7 \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$name}]" \
        --query 'Instances[0].InstanceId' \
        --output text)

    # Get the instance's private IP address
    private_ip=$(aws ec2 describe-instances \
        --instance-ids $instance_id \
        --query 'Reservations[0].Instances[0].PrivateIpAddress' \
        --output text)

    # Get the instance's public IP address (if the instance is 'web')
    if [ "$name" == "web" ]; then
        echo "Waiting for instance $instance_id to be running..."
        aws ec2 wait instance-running --instance-ids $instance_id

        public_ip=$(aws ec2 describe-instances \
            --instance-ids $instance_id \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text)

        ip_to_use=$public_ip
    else
        ip_to_use=$private_ip
    fi

    # Create or replace the Route 53 record
    echo "Creating or replacing Route 53 record for $name.$DOMAIN_NAME with IP $ip_to_use..."
    aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch '{
      "Changes": [{
        "Action": "UPSERT",
        "ResourceRecordSet": {
          "Name": "'"$name.$DOMAIN_NAME"'",
          "Type": "A",
          "TTL": 300,
          "ResourceRecords": [{"Value": "'"$ip_to_use"'"}]
        }
      }]
    }'

    echo "Instance $name created with instance ID $instance_id and IP $ip_to_use."
done

echo "All instances and Route 53 records created or updated."
