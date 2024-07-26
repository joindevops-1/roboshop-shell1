#!/bin/bash

USERID=$(id -u)
TIMESTAMP=$(date +%F-%H-%M-%S)
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
LOGFILE=/tmp/$SCRIPT_NAME-$TIMESTAMP.log
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

VALIDATE(){
   if [ $1 -ne 0 ]
   then
        echo -e "$2...$R FAILURE $N"
        exit 1
    else
        echo -e "$2...$G SUCCESS $N"
    fi
}

if [ $USERID -ne 0 ]
then
    echo "Please run this script with root access."
    exit 1 # manually exit if error comes.
else
    echo "You are super user."
fi

curl -s https://packagecloud.io/install/repositories/rabbitmq/erlang/script.rpm.sh | bash &>>$LOGFILE
VALIDATE $? "Erlang script installation"

curl -s https://packagecloud.io/install/repositories/rabbitmq/rabbitmq-server/script.rpm.sh | bash &>>$LOGFILE
VALIDATE $? "Server script installation"

dnf install rabbitmq-server -y &>>$LOGFILE
VALIDATE $? "Installing RabbitMQ"

systemctl enable rabbitmq-server  &>>$LOGFILE
VALIDATE $? "Enabling RabbitMQ"

rabbitmqctl list_users | grep -q "roboshop"
if [ $? -eq 0 ]; then
    echo -e "RabbitMQ user 'roboshop' already exists...$Y SKIPPING $N"
else
    rabbitmqctl add_user roboshop roboshop123 &>>$LOGFILE
    VALIDATE $? "Adding RabbitMQ user"
    rabbitmqctl set_permissions -p / roboshop ".*" ".*" ".*" &>>$LOGFILE
fi