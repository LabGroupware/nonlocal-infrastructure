resource "aws_iam_role" "assumable_role" {
  name = var.cluster_admin_role

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
            "${data.aws_caller_identity.current.arn}"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "admin_policy_attachment" {
  role       = aws_iam_role.assumable_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
