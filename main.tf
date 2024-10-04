# "aws_instance"というタイプのresourceを定義し、 そのリソースに"web"というローカルネームをつける
resource "aws_instance" "web" {  # <----- function create_ec2(name, type)のTerraformのSyntax

  # aws_instance resourceのArguments
  ami           = "ami-0992fc94ca0f1415a"
  instance_type = "t2.micro"
}

# local nameはユニークでなければいけない（"web"は再定義不可）
resource "aws_instance" "app" { # <----- 同じfunction aws_instance()のAlias/local nameの"web"は上に定義されているので、使用不可。違う名前の"app"にする　
  ami           = "ami-0992fc94ca0f1415a"
  instance_type = "t2.micro"
}



## 最低限必要なAWS Config (AWS CLIで”aws config”を実行して、Region、Access Keyなどを設定するのと同じ) ##
variable "aws_region" {
  default = "ap-northeast-1"
}
variable "aws_profile" {
  type = string
  default = "terraform"
  description = "AWS CLI's profile"
}
provider "aws" {
    #　Access keyを使っても酔いが、AWSのProfileの方が便利且つ、Secret Access Keyを間違ってGitにコミットしてしまう恐れがなく安全。
    # access_key = var.aws_access_key
    # secret_key = var.aws_secret_key
    
    region = var.aws_region
    profile = var.aws_profile
}