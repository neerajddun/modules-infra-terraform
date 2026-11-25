provider "aws" {

    region = "us-east-1"
}

resource "aws_vpc" "main" {

    cidr_block = "10.0.0.0/16"
    tags = {

        Name = "main"
    }
}

resource "aws_subnet" "sub1" {

    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"
    tags = {

        Name = "sub1"
    }
}

resource "aws_subnet" "sub2" {

    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "us-east-1b"
    tags = {

        Name = "sub2"
    }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "rt" {
    vpc_id = aws_vpc.main.id
    route  {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
}

resource "aws_route_table_association" "rta" {
    subnet_id = aws_subnet.sub1.id
    route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "rta1" {
    subnet_id = aws_subnet.sub2.id
    route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "sg" {

    vpc_id = aws_vpc.main.id

    ingress {

        to_port = 80
        from_port = 80
        protocol = "tcp"
        description = "http from vpc"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {

        to_port = 0
        from_port = 0
        protocol = "-1"
        description = "from vpc"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_instance" "server1" {
    ami = "ami-0fef201115eefe936"
    instance_type ="t3.micro"
    subnet_id = aws_subnet.sub1.id
    vpc_security_group_ids = [aws_security_group.sg.id]
    user_data = file("userdata.sh")
}

resource "aws_instance" "server2" {
    ami = "ami-0fef201115eefe936"
    instance_type ="t3.micro"
    subnet_id = aws_subnet.sub2.id
    vpc_security_group_ids = [aws_security_group.sg.id]
    user_data = file("userdata1.sh")
}
resource "aws_s3_bucket" "bucket1" {

  bucket = "neerajddun-d126buck"

  tags = {
    Name = "bucket-1"
    env  = "staging"
  }
}

resource "aws_s3_bucket_ownership_controls" "bucket1" {

  bucket = aws_s3_bucket.bucket1.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_lb" "alb" {

    name = "test-alb"
    load_balancer_type = "application"
    internal = false
    security_groups = [aws_security_group.sg.id]
    subnets= [aws_subnet.sub1.id,aws_subnet.sub2.id]

    access_logs {
      
      bucket = aws_s3_bucket.bucket1.id
      prefix = "test-lb"
      enabled = true
    }

    tags = {

        Name = "staging"
    }
}

resource "aws_lb_target_group" "albtg"{
    name ="target-alb"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.main.id

    health_check {
      path = "/"
      port = "traffic-port"
    }

}

resource "aws_lb_target_group_attachment" "albtga" {
    target_group_arn = aws_lb_target_group.albtg.arn
    target_id = aws_instance.server1.id
    port = 80
}

resource "aws_lb_target_group_attachment" "albtga1" {
    target_group_arn = aws_lb_target_group.albtg.arn
    target_id = aws_instance.server2.id
    port = 80
}

resource "aws_lb_listener" "albl" {
    load_balancer_arn = aws_lb.alb.arn
    port = 80
    protocol = "HTTP"

    default_action {
      target_group_arn = aws_lb_target_group.albtg.arn
      type = "forward"
    }
}

output "loadbalancername" {
    value = aws_lb.alb.dns_name
  
}