provider "aws" {
  region  = "ap-south-1"
}

resource "aws_s3_bucket" "my_bucket" {
  bucket         = "terraform-mentoring-bucket"
  # force_destroy  = true
  # tags = {
  #   Name = "Pratham_mentorship"
  # }
}
terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket"
    key            = "terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
  }
}

resource "aws_s3_bucket_ownership_controls" "bucket_owner" {
  bucket = aws_s3_bucket.my_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.my_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.my_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }

  routing_rule {
    condition {
      http_error_code_returned_equals = "404"
    }
    redirect {
      replace_key_with   = "index.html"
      http_redirect_code = "302"
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "cors" {
  bucket = aws_s3_bucket.my_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

data "aws_iam_policy_document" "public_read" {
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:DeleteObject"
    ]

    resources = [
      aws_s3_bucket.my_bucket.arn,
      "${aws_s3_bucket.my_bucket.arn}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.my_bucket.id
  policy = data.aws_iam_policy_document.public_read.json

  depends_on = [
    aws_s3_bucket_public_access_block.public_access
  ]
}

locals {
  mime_types = {
    "html"  = "text/html",
    "css"   = "text/css",
    "js"    = "application/javascript",
    "json"  = "application/json",
    "png"   = "image/png",
    "jpg"   = "image/jpeg",
    "jpeg"  = "image/jpeg",
    "svg"   = "image/svg+xml",
    "ico"   = "image/x-icon",
    "txt"   = "text/plain",
    "woff"  = "font/woff",
    "woff2" = "font/woff2",
    "map"   = "application/json",
    "ttf"   = "font/ttf",
    "eot"   = "application/vnd.ms-fontobject"
  }
}

resource "aws_s3_object" "static_files" {
  for_each = fileset("${path.module}/../frontend/out", "**/*.*")

  bucket       = aws_s3_bucket.my_bucket.id
  key          = each.value
  source       = "${path.module}/../frontend/out/${each.value}"
  content_type = lookup(local.mime_types, split(".", each.value)[length(split(".", each.value)) - 1], "application/octet-stream")
  etag         = filemd5("${path.module}/../frontend/out/${each.value}")
  acl          = "public-read"

  cache_control = contains([".html"], ".${split(".", each.value)[length(split(".", each.value)) - 1]}") ? "no-cache" : "max-age=31536000"
}

output "website_url" {
  value = "http://${aws_s3_bucket_website_configuration.website.website_endpoint}"
}
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Security Group for EC2
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg"
  description = "Allow SSH, HTTP and HTTPS"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Key Pair
variable "public_key" {
  description = "Public key for EC2 SSH access"
  type        = string
}

resource "aws_key_pair" "deployer" {
  key_name   = "mentorship-key"
  public_key = var.public_key
}

# Fetch default VPC
data "aws_vpc" "default" {
  default = true
}

# Fetch default subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# EC2 Instance
resource "aws_instance" "my_ec2" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = element(data.aws_subnets.default.ids, 0)
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  tags = {
    Name = "FeedbackCollection-Backend-EC2"
  }

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              # Install Node.js 18.x (Amazon Linux 2)
              curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
              yum install -y nodejs git

              # Install PM2 (to keep Node app running)
              npm install -g pm2

              # Create app directory
              mkdir -p /home/ec2-user/app
              cd /home/ec2-user/app

              # For simplicity, clone from GitHub (replace with your repo URL)
              git clone https://github.com/yourusername/FeedbackCollection.git .
              cd backend

              # Install dependencies
              npm install --production

              # Start the backend (assuming index.js or app.js)
              pm2 start index.js --name feedback-backend
              pm2 startup systemd
              pm2 save
              EOF
}

output "ec2_public_ip" {
  value = aws_instance.my_ec2.public_ip
}

output "ec2_public_dns" {
  value = aws_instance.my_ec2.public_dns
}
