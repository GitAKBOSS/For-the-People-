variable "aws_region" {
  type = "string"
  default = "us-east-1"
}

variable "service_name" {
  type = "string"
  default = "sample-php-application"
}

variable "service_title" {
  type = "string"
  default = "Sample PHP Application"
}

variable "solutions_stack" {
  type = "string"
  default = "64bit Amazon Linux 2017.09 v2.6.5 running PHP 7.1"
}

variable "bucket_name" {
  type = "string"
  default = "arsalan2018-application-bucket"
}
variable "aws_access_key" {
  type = "string"
}

variable "aws_secret_key" {
  type = "string"
}
provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region = "${var.aws_region}"
}

resource "aws_iam_instance_profile" "beanstalk_service" {
  name = "${var.service_name}-beanstalk-service-user"
  role = "${aws_iam_role.beanstalk_service.name}"
}
resource "aws_iam_instance_profile" "beanstalk_ec2" {
  name = "${var.service_name}-beanstalk-ec2-user"
  role = "${aws_iam_role.beanstalk_ec2.name}"
}
resource "aws_iam_role" "beanstalk_service" {
  name = "${var.service_name}-elastic-beanstalk-service-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "elasticbeanstalk.amazonaws.com"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "elasticbeanstalk"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role" "beanstalk_ec2" {
  name = "${var.service_name}-elastic-beanstalk-ec2-role"
  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "beanstalk_service" {
  name = "${var.service_name}-elastic-beanstalk-service"
  roles = [
    "${aws_iam_role.beanstalk_service.id}"]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkService"
}

resource "aws_iam_policy_attachment" "beanstalk_service_health" {
  name = "${var.service_name}-elastic-beanstalk-service-health"
  roles = [
    "${aws_iam_role.beanstalk_service.id}"]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth"
}

resource "aws_iam_policy_attachment" "beanstalk_ec2_web" {
  name = "${var.service_name}-elastic-beanstalk-ec2-web"
  roles = [
    "${aws_iam_role.beanstalk_ec2.id}"]
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "all" {
  vpc_id = "${data.aws_vpc.default.id}"
}

resource "aws_security_group" "sg" {
  name = "${var.service_name}"
  vpc_id = "${data.aws_vpc.default.id}"
}

resource "aws_security_group_rule" "http" {
  from_port = 80
  protocol = "tcp"
  security_group_id = "${aws_security_group.sg.id}"
  to_port = 80
  type = "ingress"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ssh" {
  from_port = 22
  protocol = "tcp"
  security_group_id = "${aws_security_group.sg.id}"
  to_port = 22
  type = "ingress"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "internal-ingress" {
  from_port = 0
  protocol = "-1"
  source_security_group_id = "${aws_security_group.sg.id}"
  security_group_id = "${aws_security_group.sg.id}"
  to_port = 65535
  type = "ingress"
}

resource "aws_security_group_rule" "internal-egress" {
  from_port = 0
  protocol = "-1"
  source_security_group_id = "${aws_security_group.sg.id}"
  security_group_id = "${aws_security_group.sg.id}"
  to_port = 65535
  type = "egress"
}


resource "aws_elastic_beanstalk_application" "app" {
  name = "${var.service_name}"
}

resource "aws_elastic_beanstalk_environment" "app" {
  name = "${var.service_name}"
  application = "${aws_elastic_beanstalk_application.app.name}"
  solution_stack_name = "${var.solutions_stack}"
 # tell beanstalk to deploy the version, without this, the standard php page for beanstalk comes up
  version_label       = "${aws_elastic_beanstalk_application_version.default.id}"

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "IamInstanceProfile"
    value = "${aws_iam_instance_profile.beanstalk_ec2.id}"
  }
  setting {
    namespace = "aws:ec2:vpc"
    name = "VPCId"
    value = "${data.aws_vpc.default.id}"
  }
  setting {
    namespace = "aws:ec2:vpc"
    name = "AssociatePublicIpAddress"
    value = "true"
  }
  setting {
    namespace = "aws:ec2:vpc"
    name = "Subnets"
    value = "${join(",",data.aws_subnet_ids.all.ids)}"
  }
  setting {
    namespace = "aws:ec2:vpc"
    name = "ELBSubnets"
    value = "${join(",",data.aws_subnet_ids.all.ids)}"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "InstanceType"
    value = "t2.micro"
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name = "MinSize"
    value = "1"
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name = "MaxSize"
    value = "1"
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name = "ServiceRole"
    value = "${aws_iam_role.beanstalk_service.id}"
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name = "environment"
    value = "prod"
  }
  setting {
    namespace = "aws:elb:loadbalancer"
    name = "CrossZone"
    value = "true"
  }
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name = "BatchSizeType"
    value = "Fixed"
  }
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name = "BatchSize"
    value = "1"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "SecurityGroups"
    value = "${aws_security_group.sg.id}"
  }
}

resource "aws_s3_bucket" "default" {
  bucket = "${var.bucket_name}"
}

resource "aws_s3_bucket_object" "default" {
  bucket = "${aws_s3_bucket.default.id}"
  key    = "app.zip"
  source = "app.zip"
}

resource "aws_elastic_beanstalk_application_version" "default" {
# the version name changes whenever the zip file changes. to enable automatic updates of the application when the zip file changes. otherwise manual taint is required for resource or manually click update on aws. 
  name        = "${var.service_name}-${sha256(file("app.zip"))}"
  application = "${aws_elastic_beanstalk_application.app.id}"
  description = "application version created by terraform"
  bucket      = "${aws_s3_bucket.default.id}"
  key         = "${aws_s3_bucket_object.default.id}"
}
