resource "aws_vpc" "myvpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "myvpc"
  }
}

resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.sub1_cidr
  availability_zone       = var.sub1_region
  map_public_ip_on_launch = true
  tags = {
    Name = "sub1"
  }
}

resource "aws_subnet" "sub2" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.sub2_cidr
  availability_zone       = var.sub2_region
  map_public_ip_on_launch = true
  tags = {
    Name = "sub2"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id
  tags = {
    Name = "igw"
  }
}

resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "RT"
  }
}

resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.sub2.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_security_group" "websg" {
  name   = "websg"
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "websg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ingresshttp" {
  description       = "HTTP"
  security_group_id = aws_security_group.websg.id
  cidr_ipv4         = var.anywhere_ipv4_cidr
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "ingressssh" {
  description       = "SSH"
  security_group_id = aws_security_group.websg.id
  cidr_ipv4         = var.anywhere_ipv4_cidr
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "egressanywhere" {
  description       = "Anywhere"
  security_group_id = aws_security_group.websg.id
  cidr_ipv4         = var.anywhere_ipv4_cidr
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_security_group" "ec2sg" {
  name   = "ec2sg"
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "ec2sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "fromalb" {
  description       = "fromalb"
  security_group_id = aws_security_group.ec2sg.id
  referenced_security_group_id = aws_security_group.websg.id
  #cidr_ipv4         = aws_lb.mylb.
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "foralb" {
  description       = "foralb"
  security_group_id = aws_security_group.ec2sg.id
  cidr_ipv4         = var.anywhere_ipv4_cidr
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_s3_bucket" "mybucket" {
  bucket = "shrinathkopareterraformbucket"

  tags = {
    Name = "My bucket"
  }
}

resource "aws_s3_bucket_ownership_controls" "myoc" {
  bucket = aws_s3_bucket.mybucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "mypab" {
  bucket = aws_s3_bucket.mybucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "myacl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.myoc,
    aws_s3_bucket_public_access_block.mypab,
  ]

  bucket = aws_s3_bucket.mybucket.id
  acl    = "public-read"
}

resource "aws_instance" "server1" {
  ami                    = var.microami
  instance_type          = var.microinstance
  vpc_security_group_ids = [aws_security_group.ec2sg.id]
  subnet_id              = aws_subnet.sub1.id
  user_data              = base64encode(file("userdata.sh"))

  tags = {
    Name = "Serve1"
  }
}

resource "aws_instance" "server2" {
  ami                    = var.microami
  instance_type          = var.microinstance
  vpc_security_group_ids = [aws_security_group.ec2sg.id]
  subnet_id              = aws_subnet.sub2.id
  user_data              = base64encode(file("userdata1.sh"))

  tags = {
    Name = "Serve2"
  }
}

resource "aws_lb" "mylb" {
  name = "mylb"
  internal = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.websg.id]
  subnets = [aws_subnet.sub1.id, aws_subnet.sub2.id]
}

resource "aws_lb_target_group" "mytg" {
  name = "mytg"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.myvpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.mytg.arn
  target_id = aws_instance.server1.id
  port = 80
}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.mytg.arn
  target_id = aws_instance.server2.id
  port = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.mylb.arn
  port = 80
  protocol = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.mytg.arn
    type = "forward"
  }
}

output "load_balancer_dns" {
  value = aws_lb.mylb.dns_name
}