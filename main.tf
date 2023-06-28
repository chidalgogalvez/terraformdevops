provider "aws" {
  region = "us-west-2"
}
## configurando datasource
//subnet-038e110690eecd989 -> us-west-2a 2b 2c 2d

data "aws_subnet" "az_a" {
  availability_zone = "us-west-2a"
}

data "aws_subnet" "az_b" {
  availability_zone = "us-west-2b"
}

data "aws_subnet" "az_c" {
  availability_zone = "us-west-2c"
}

resource "aws_instance" "servidor1" {
  ami           = "ami-03f65b8614a860c29"
  instance_type = "t2.micro"
  #subnet_id = "subnet-008ab9f9ec176e717"
  subnet_id              = data.aws_subnet.az_a.id
  vpc_security_group_ids = [aws_security_group.mi_grupo_de_seguridad.id]
  user_data              = <<-EOF
              #!/bin/bash
              echo "Hola Terraformers! servidor 1"> index.html
              nohup busybox httpd -f -p 8080 &
              EOF
  tags = {
    Name = "servidor-1"
  }
}

resource "aws_instance" "servidor2" {
  ami                    = "ami-03f65b8614a860c29"
  instance_type          = "t2.micro"
  subnet_id              = data.aws_subnet.az_b.id
  vpc_security_group_ids = [aws_security_group.mi_grupo_de_seguridad.id]
  user_data              = <<-EOF
              #!/bin/bash
              echo "Hola Terraformers! servidor 2"> index.html
              nohup busybox httpd -f -p 8080 &
              EOF
  tags = {
    Name = "servidor-2"
  }
}

resource "aws_instance" "servidor3" {
  ami                    = "ami-03f65b8614a860c29"
  instance_type          = "t2.micro"
  subnet_id              = data.aws_subnet.az_c.id
  vpc_security_group_ids = [aws_security_group.mi_grupo_de_seguridad.id]
  user_data              = <<-EOF
              #!/bin/bash
              echo "Hola Terraformers! servidor 3"> index.html
              nohup busybox httpd -f -p 8080 &
              EOF
  tags = {
    Name = "servidor-3"
  }
}

resource "aws_security_group" "mi_grupo_de_seguridad" {
  name = "primer-servidor-sg"

  ingress {
    security_groups = [aws_security_group.alb.id]
    cidr_blocks     = ["0.0.0.0/0"]
    description     = "Acceso al puerto 8080 desde el exterior"
    from_port       = 8080
    to_port         = 8080
    protocol        = "TCP"
  }
}

# CONFIGURACION DE LOAD BALANCER 

resource "aws_lb" "alb" {
  load_balancer_type = "application"
  name               = "kibernum-alb"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [data.aws_subnet.az_a.id, data.aws_subnet.az_b.id, data.aws_subnet.az_c.id]
}

resource "aws_security_group" "alb" {
  name = "alb-sq"

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "acceso al puerto 80 desde el exterior"
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "acceso al puerto 8080 de nuestros servidores"
    from_port   = 8080
    to_port     = 8080
    protocol    = "TCP"
  }
}

data "aws_vpc" "default" {
  default = true
}


resource "aws_lb_target_group" "this" {
  name     = "kibernum-alb-target-group"
  port     = 80
  vpc_id   = data.aws_vpc.default.id
  protocol = "HTTP"

  health_check {
    enabled  = true
    matcher  = "200"
    path     = "/"
    port     = "8080"
    protocol = "HTTP"
  }
}

resource "aws_lb_target_group_attachment" "servidor_1" {
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = aws_instance.servidor1.id # es la instancia 
  port             = 8080                      # puerto de la instancia
}

resource "aws_lb_target_group_attachment" "servidor_2" {
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = aws_instance.servidor2.id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "servidor_3" {
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = aws_instance.servidor3.id
  port             = 8080
}


resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.alb.id
  port              = 80
  protocol          = "HTTP"
  # hacer forward para todas las peticiones que entren hacia nuestro target group


  default_action {
    target_group_arn = aws_lb_target_group.this.arn
    type             = "forward"
  }
}
