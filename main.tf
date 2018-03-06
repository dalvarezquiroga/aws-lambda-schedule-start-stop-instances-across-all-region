terraform {
  backend "s3" {
    bucket = "devops-terraform-state-store"
    key    = "terraform.tfstate"
    region = "eu-west-1"
  }
}

resource "aws_s3_bucket" "config" {
  bucket = "${lower("${var.project_name}-configuration")}"

  tags {
    Name    = "${var.project_name}.configuration"
    project = "${var.project_name}"
  }
}
