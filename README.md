# Terraforming Dockerized Nginx-Webserver on AWS


## Bonial Exercise 2 - Terraform
Write a terraform configuration which contains the following:
AWS Setup
• An EC2 instance of type t2.micro based on a Debian Stretch Image.
• A Loadbalancer forwarding incoming requests to the EC2 instance.
The EC2 instance needs to run an Nginx webserver serving one HTML file (just make one up and
make the file part of your Github repo). The Nginx server is a Docker container started on the EC2
instance.


5. terraform apply -- den erstellten plan umsetzen.

## Getting Started

These instructions will get you a copy of the project up and running on an AWS EC2 instance with a Nginx Server which is built in a Docker Container.

One task is that a Load-Balancer also has to be integrated in that Infrastructure, to check that i have built one autoscaling group on the available AWS Zone.

### Prerequisites

1. Amazon Webservice Account for the AWS-Services
2. Terraform -> Terraform v0.11.7

### Installing

For using the AWS- Service we have to create also one IAM User (in this case "Terraform") with rights to creating an EC2 instance. Here you will get an AWS_ACCESS_KEY_ID and an AWS_SECRET_ACCESS_KEY. They are need to Login in to AWS later. How do you create an AWS IAM User is not explained here. Check https://docs.aws.amazon.com/de_de/IAM/latest/UserGuide/best-practices.html for more Details.

Download Terraform from https://www.terraform.io/downloads.html

For Windows User: Put the Path to System Variables so you can use it via the cmd-tool

## Deployment
### EC2 Instance & Security Group

1. create a Project folder (bonial_task)
2. create a file inside that Folder (main.tf) and put following in
```
###############################################################
#                        AWS Provider                         #
###############################################################
provider "aws" {
  access_key = "${var.AWS_ACCESS_KEY_ID}"
  secret_key = "${var.AWS_SECRET_ACCESS_KEY}"
  region     = "eu-central-1"
}
###############################################################
#                        EC2 Instance                         #
###############################################################
resource "aws_instance" "instance_name" {
  ami = "ami-id which is available in your region"
  instance_type = "your desired instance_type (t2.micro = free tier)"
  key_name = "your_aws_key_name"
}
```
3. create a file inside that Folder (variables.tf) and put following in
```
variable "AWS_ACCESS_KEY_ID" {
  default = "your_aws_acces_key_id"
}
variable "AWS_SECRET_ACCESS_KEY" {
  default = "your_aws_secret_key"
}
variable "aws_ami" {
  default = "your preferred ami-id"
}
```
4. Open a Command Tool Line / Terminal and go to your project folder and initialize Terraform
```
\Bonial\bonial_task > terraform init

Initializing provider plugins...
- Checking for available provider plugins on https://releases.hashicorp.com...
- Downloading plugin for provider "aws" (1.24.0)...

The following providers do not have any version constraints in configuration,
so the latest version was installed.

To prevent automatic upgrades to new major versions that may contain breaking
changes, it is recommended to add version = "..." constraints to the
corresponding provider blocks in configuration, with the constraint strings
suggested below.

* provider.aws: version = "~> 1.24"

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.

```
Everything fine till now.

5. Go to main.tf an create s Security group ressource for in- and outcoming Traffic
```
#################################################################
#                 Security group ressource                      #
#################################################################
resource "aws_security_group" "aws_instance" {
  name = "your desired name"

  ingress {
  from_port   = 0  
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
      create_before_destroy = true
    }
  }
```
For developing issues we opened all ports an the instance with that security-group.

6. The created security group has to be declared in the instance-ressource part and put the below code inside.

```
###############################################################
#                        EC2 Instance                         #
###############################################################
resource "aws_instance" "instance_name" {
  ami = "ami-id which is available in your region"
  instance_type = "your desired instance_type (t2.micro = free tier)"
  key_name = "your_aws_key_name"
+ vpc_security_group_ids = ["${aws_security_group.aws_instance.id}"]
}

```
7. Go back to your cmd/terminal and type
```
terraform plan
```
Now a lot of messages will be shown how your infrastructure is be planned for building.
At the end it will show a line like that
```
Plan: 6 to add, 0 to change, 0 to destroy.
```
8. Time to Apply all changes and  starting an instance on AWS
Type in your commandline
```
terraform apply
```
and accept the changings with "yes". If everything is fine we get this message:
```
Apply complete! Resources: 6 added, 0 changed, 0 destroyed.
```

###  Launch Configuration ressource
Now we define a Launch Configuration ressource in main.tf for the autoscaling group in AWS. This is a template for further building of instances inside the Scaling Group. It's the common same like the first EC2 instance.  

```
#################################################################
#             Launch Configuration ressource                    #
#################################################################
resource "aws_launch_configuration" "instance-name" {
image_id = "ami-id"
instance_type = "t2.micro"
key_name = "your_aws_key_name"
security_groups = ["${aws_security_group.aws_instance.id}"]

lifecycle {
    create_before_destroy = true
  }
}
```

### Autoscaling Group & Load Balancing ressources
1. We configure the Autoscaling Group as a ressource inside the main.tf.
```
#################################################################
#                     Auto Scaling ressource                    #
#################################################################
resource "aws_autoscaling_group" "instance_name" {
  launch_configuration = "${aws_launch_configuration.instance_name.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  min_size = 2
  max_size = 4

  tag {
    key = "Name"
    value = "name_for_created_instances"
    propagate_at_launch = true
  }
}
```
in the line where availability_zones = ["${data.aws_availability_zones.all.names}"] is, the "data" part has to be declared first in variables.tf, just put the code below inside that file variabels.tf.

```
data "aws_availability_zones" "all" {}
```
2. Configuring the Load Balancer and its Security Groups

```
#################################################################
#              Load Balancing ressource                         #
#################################################################
resource "aws_elb" "autoscaling_instance_name" {
  name = "asg_name"
  security_groups = ["${aws_security_group.elb.id}"]
  availability_zones = ["${data.aws_availability_zones.all.names}"]

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:${var.server_port}/"
  }
  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "${var.server_port}"
    instance_protocol = "http"
  }
}

#################################################################
# security ressource für das load_balancing                     #
#################################################################
resource "aws_security_group" "elb_instance_name" {
  name = "elb_name"
  egress {
   from_port = 0
   to_port = 0
   protocol = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```
### Installing Docker and nginx
For installing Docker and Nginx on the AWS Instance we use the provisioner method from terraform. (https://www.terraform.io/docs/provisioners/index.html)

We will use 2 commands which are "file" and "remote-exec".

I found a very useful script on github (https://github.com/salizzar/terraform-aws-docker/blob/master/main.tf) which has been include the docker and nginx commands.

NOTE: These "provisioner" explanations are for a different AMI-ID and Linux distrubitions. In our case we use a Debian Stretch Image from AWS (k8s-1.10-debian-stretch-amd64-hvm-ebs-2018-05-27 (ami-f3143e18)).

Now go back to main.tf, to the EC2-Instance ressource and put following code inside the EC2 Instance.
```
provisioner "file" {              
      source = "files/"
      destination = "/tmp/"
  }

provisioner "remote-exec" {       
      inline = [
          "sudo apt-get install --no-install-recommends --no-install-suggests -y gnupg1 apt-transport-https ca-certificates",
          "sudo apt-get -y install docker-ce",
          "sudo systemctl start docker",
          "sudo systemctl status docker",       
          "sudo systemctl enable docker",       
          "sudo docker run -d -p 80:80 -v /tmp:/usr/share/nginx/html --name nginx_${count.index} nginx",
          "sudo sed -iE \"s/{{ hostname }}/`hostname`/g\" /tmp/index.html",
          "sudo sed -iE \"s/{{ container_name }}/nginx_${count.index}/g\" /tmp/index.html"
      ]
  }

  connection {
   type     = "ssh"
   user     = "admin"
   agent = true
   private_key = "${file("./your_aws_key.pem")}"
   timeout = "10m"
 }
```
Inside the provisioner "files" folder we can now put all the files we want to transfer to that instance.

The "remote-exec" command do what the name says its executing the files/commands on the external instance. For my Debian version i had to use systemctl as prefix and also look for the right docker-engine.

Nginx will take the index.html file inside the ./tmp folder.

We also need an connection to the instance to be able to run the remote-exec command on the instance.


### And coding style tests

1.We can show us the Public Ip-Adress of our AWS-EC2-Instance created by Terraform. Put the code below inside the main.tf file.
Type in the commandline
```
 > terraform apply  
```
and you will get an output like that :

Outputs:
elb_dns_name = terraform-asg-example-1343921751.eu-central-1.elb.amazonaws.com
public_ip = 52.59.228.48

This means that our Loadbalancer is working fine and our first instance have a public ip.

```
#################################################################
#             Public-IP of the AWS-instance                     #
#################################################################

  output "public_ip" {
    value = "${aws_instance.your_ec2_instance_name.public_ip}"
    }

#################################################################
# Ausgabe der öfftl- IP von AWS-instance                        #
#################################################################
  output "elb_dns_name" {
    value = "${aws_elb.elb_instance_name.dns_name}"
    }

```
2. After setting up docker and nginx we would be able to reach our instance over its PublicIP and PublicDnsName.

Go to your AWS Console and open the EC2 Part. There you will see the running instances, choose one and take the Public DNS (IPv4) Adress and put it in your Browser and open the Adress.

There you will see now the Nginx Webserver running.





## Authors

* **Ferhat Ipek** - *Initial work* -
