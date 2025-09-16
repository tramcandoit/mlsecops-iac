resource "aws_s3_bucket" "dataset_s3_bucket" {
  bucket = "mlsecops-fraud-dataset"
}

resource "aws_ecr_repository" "ml_pipeline_repo" {
  name                 = "mlpipeline"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

output "ecr_repository_url" {
  value = aws_ecr_repository.ml_pipeline_repo.repository_url
}