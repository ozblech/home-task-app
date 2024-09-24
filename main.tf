

provider "aws" {
    region = "us-west-2"
    access_key = ""
    secret_key = ""
}

# Create the S3 bucket for Terraform state storage
# resource "aws_s3_bucket" "terraform_state" {
#   bucket = "my-terraform-state-bucket-app-oz-1"  # Replace with your unique bucket name

#   lifecycle {
#     prevent_destroy = true  # Prevent accidental deletion of the state bucket
#   }
# }

# Create a DynamoDB table for state locking and consistency checks
# resource "aws_dynamodb_table" "terraform_locks" {
#   name         = "terraform-locks"
#   billing_mode = "PAY_PER_REQUEST"

#   attribute {
#     name = "LockID"
#     type = "S"
#   }

#   hash_key = "LockID"
# }

// Create ec2 with docker installed
resource "aws_instance" "docker_ec2" {
    ami = "ami-0bfddf4206f1fa7b9"
    instance_type = "t2.small"
    iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
    user_data = <<-EOF
                #!/bin/bash
                sudo yum update -y
                sudo yum install docker -y
                sudo service docker start
                sudo usermod -a -G docker ec2-user

                #copy the init.sql file to the ec2 instance
                echo "${filebase64("${path.module}/init.sql")}" | base64 --decode > /init.sql            
                
                # Create a Docker network
                docker network create test || true

                # Run MySQL container
                docker run -d --network test -p 3306:3306 --name mysql_db -e MYSQL_ROOT_PASSWORD=root_password \
                -e MYSQL_DATABASE=exampleDb -e MYSQL_USER=flaskapp -e MYSQL_PASSWORD=flaskapp \
                -v $(pwd)/init.sql:/docker-entrypoint-initdb.d/init.sql mysql:5.7
                
                # Wait for MySQL container to initialize
                sleep 24

                # Log in to ECR
                aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 024848485658.dkr.ecr.us-west-2.amazonaws.com
                
                # Pull the Docker image from ECR
                docker pull 024848485658.dkr.ecr.us-west-2.amazonaws.com/oz-home-task-repo:latest
                
                # test
                # Run the Docker container pulled from ECR
                docker run -d --network test --name my_app -p 8080:8080 -e DB_HOST=mysql_db -e BACKEND=http://localhost:8080 -e DB_USER=flaskapp -e DB_PASS=flaskapp -e DB_NAME=exampleDb 024848485658.dkr.ecr.us-west-2.amazonaws.com/oz-home-task-repo:latest
                EOF
    # Optional: Add tags to identify the instance
    tags = {
        Name = "Docker-EC2"
  }
  # Attach a security group to allow access
  vpc_security_group_ids = [aws_security_group.docker_sg.id]

  # Add an Elastic IP (Optional)
  associate_public_ip_address = true
}

resource "aws_security_group" "docker_sg" {
  name        = "docker-sg"
  description = "Allow SSH and Docker"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow SSH from anywhere (you can restrict this)
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Docker port (optional, depending on your use case)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Optional: Assign an Elastic IP
resource "aws_eip" "docker_eip" {
  instance = aws_instance.docker_ec2.id
}

output "instance_public_ip" {
  value = aws_eip.docker_eip.public_ip
}

resource "aws_ecr_repository" "my_repo" {
  name = "oz-home-task-repo"  # Replace with your desired repository name
}

resource "null_resource" "docker_push" {
    # Use the triggers argument to force this resource to re-run
    # triggers = {
    #  always_run = "${timestamp()}"  # This will change every time you run terraform apply
    # }
  provisioner "local-exec" {
    command = <<EOT
      #!/bin/bash
      # Log in to ECR
      aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin ${aws_ecr_repository.my_repo.repository_url}
      
      # Build Docker image
      docker build --platform="linux/amd64" -t my-image:latest .
      
      # Tag Docker image
      docker tag my-image:latest ${aws_ecr_repository.my_repo.repository_url}:latest
      
      # Push Docker image
      docker push ${aws_ecr_repository.my_repo.repository_url}:latest
    EOT
  }

  depends_on = [aws_ecr_repository.my_repo]
}


# TODO: chekc if needed
# resource "local_file" "init_sql_file" {
#   content  = file("./init.sql")
#   filename = "${path.module}/init.sql"
# }

resource "aws_iam_role" "ec2_iam_role" {
  name = "ec2_iam_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecr_access_policy" {
  name = "ecr_access_policy"
  role = aws_iam_role.ec2_iam_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetAuthorizationToken"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_iam_role.name
}


