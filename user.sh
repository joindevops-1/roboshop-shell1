#!/bin/bash

USERID=$(id -u)
TIMESTAMP=$(date +%F-%H-%M-%S)
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
LOGFILE=/tmp/$SCRIPT_NAME-$TIMESTAMP.log
MONGDB_HOST=mongodb.daws78s.online
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

dnf module disable nodejs -y &>> $LOGFILE

VALIDATE $? "Disabling current NodeJS"

dnf module enable nodejs:20 -y  &>> $LOGFILE

VALIDATE $? "Enabling NodeJS:20"

dnf install nodejs -y  &>> $LOGFILE

VALIDATE $? "Installing NodeJS:18"

id roboshop #if roboshop user does not exist, then it is failure
if [ $? -ne 0 ]
then
    useradd roboshop
    VALIDATE $? "roboshop user creation"
else
    echo -e "roboshop user already exist $Y SKIPPING $N"
fi

mkdir -p /app

VALIDATE $? "creating app directory"

curl -o /tmp/user.zip https://roboshop-builds.s3.amazonaws.com/user.zip  &>> $LOGFILE

VALIDATE $? "Downloading user application"

cd /app 

unzip -o /tmp/user.zip  &>> $LOGFILE

VALIDATE $? "unzipping user"

npm install  &>> $LOGFILE

VALIDATE $? "Installing dependencies"

# use absolute, because user.service exists there
cp /home/ec2-user/roboshop-shell/user.service /etc/systemd/system/user.service &>> $LOGFILE

VALIDATE $? "Copying user service file"

systemctl daemon-reload &>> $LOGFILE

VALIDATE $? "user daemon reload"

systemctl enable user &>> $LOGFILE

VALIDATE $? "Enable user"

systemctl start user &>> $LOGFILE

VALIDATE $? "Starting user"

cp /home/ec2-user/roboshop-shell/mongo.repo /etc/yum.repos.d/mongo.repo

VALIDATE $? "copying mongodb repo"

dnf install -y mongodb-mongosh &>> $LOGFILE

VALIDATE $? "Installing MongoDB client"

SCHEMA_EXISTS=$(mongosh --host mongodb.daws78s.online --quiet --eval 'db.getMongo().getDBNames().indexOf("users")')
echo "schema: $SCHEMA_EXISTS"

if [ $SCHEMA_EXISTS -le 0 ]
then
    echo "MongoDB schema does not exist"
    mongosh --host $MONGDB_HOST </app/schema/user.js
    VALIDATE $? "Loading user data into MongoDB"
else
    echo "MongoDB schema already exist"
fi