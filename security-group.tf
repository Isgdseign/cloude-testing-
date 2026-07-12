# Gravia Test Repo - security-group.tf
# INTENTIONALLY VULNERABLE

# VULN: Wide open security group — allows ALL inbound traffic
resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Web server security group"
  vpc_id      = aws_vpc.main.id

  # CRITICAL: 0.0.0.0/0 on all ports
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # CRITICAL: All outbound open
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {}
}

# VULN: SSH open to the entire internet
resource "aws_security_group" "ssh" {
  name        = "ssh-access"
  description = "SSH access"
  vpc_id      = aws_vpc.main.id

  # CRITICAL: SSH (22) open to 0.0.0.0/0
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {}
}

# VULN: RDP (3389) open to internet — Windows remote desktop
resource "aws_security_group" "rdp" {
  name        = "rdp-access"
  description = "RDP access for Windows servers"
  vpc_id      = aws_vpc.main.id

  # CRITICAL: RDP port 3389 open to 0.0.0.0/0
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {}
}

# VULN: No security group for database tier — private subnet has no SG rules
# Missing: Separate SG for app tier, db tier with least-privilege