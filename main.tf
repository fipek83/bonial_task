###############################################################
#                      AWS Provider                         #
###############################################################
provider "aws" {
  access_key = "${var.AWS_ACCESS_KEY_ID}"
  secret_key = "${var.AWS_SECRET_ACCESS_KEY}"
  region     = "eu-central-1"
}

###############################################################
#              erste ressource mit einer Instance             #
###############################################################
resource "aws_instance" "terra-sample" {
  ami = "${var.aws_ami}"
  instance_type = "t2.micro"
  key_name = "terraform"
  vpc_security_group_ids = ["${aws_security_group.aws_instance.id}"]

provisioner "file" {              #zum laden der Files auf die Instanz
      source = "files/"
      destination = "/tmp/"
  }

provisioner "remote-exec" {       #externer aufruf (aufruf in der instanz)
      inline = [
          "sudo apt-get install --no-install-recommends --no-install-suggests -y gnupg1 apt-transport-https ca-certificates",
          "sudo apt-get -y install docker-ce",
          "sudo systemctl start docker",
          "sudo systemctl status docker",       #überprüfen ob docker container aktiv
          "sudo systemctl enable docker",       #mit systemstart docker starten
          "sudo docker run -d -p 80:80 -v /tmp:/usr/share/nginx/html --name nginx_${count.index} nginx",
          "sudo sed -iE \"s/{{ hostname }}/`hostname`/g\" /tmp/index.html",
          "sudo sed -iE \"s/{{ container_name }}/nginx_${count.index}/g\" /tmp/index.html"
      ]
  }

  connection {
   type     = "ssh"
   user     = "admin"
   agent = true
   private_key = "${file("./terraform.pem")}"
   timeout = "10m"
 }

}

#################################################################
# zweite ressource zuständig für die Erreichbarkeit (Sicherheit)#
#################################################################
resource "aws_security_group" "aws_instance" {
  name = "terra-sample"

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

#################################################################
# Ausgabe der öfftl- IP von AWS-instance                        #
#################################################################

  output "public_ip" {
    value = "${aws_instance.terra-sample.public_ip}"
    }

#################################################################
# Ausgabe der öfftl- IP von AWS-instance                        #
#################################################################
  output "elb_dns_name" {
    value = "${aws_elb.terra-sample-instance.dns_name}"
    }

#################################################################
# ressource launch_configuration einrichten                     #
#################################################################
resource "aws_launch_configuration" "terra-sample" {
image_id = "ami-f3143e18"
instance_type = "t2.micro"
key_name = "terraform"
security_groups = ["${aws_security_group.aws_instance.id}"]

lifecycle {
    create_before_destroy = true
  }
}

#################################################################
# ressource für das autoscaling notwendig für das load_balancing#
#################################################################
resource "aws_autoscaling_group" "terra-sample-instance" {
  launch_configuration = "${aws_launch_configuration.terra-sample.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  min_size = 2
  max_size = 4

  load_balancers = ["${aws_elb.terra-sample-instance.name}"]
  health_check_type = "ELB"

  tag {
    key = "Name"
    value = "terra-asg-sample"
    propagate_at_launch = true
  }
}

#################################################################
# ressource für das load_balancing                              #
#################################################################
resource "aws_elb" "terra-sample-instance" {
  name = "terraform-asg-example"
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
resource "aws_security_group" "elb" {
  name = "terraform-elb-example"
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
