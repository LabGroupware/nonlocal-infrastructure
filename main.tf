# variableブロックを使って、image_idという変数の名前を定義する
variable "image_id" {
  type = string # [string, number, bool]
  description = "The id of the machine image (AMI) to use for the server." # 任意
  default = "ami-abc123" # 任意のDefault値
  # sensitive = true # 任意, これを設定すると、Terraform planやapplyコマンドのアウトプットに値が表示されなくなる
}

variable "amis" {
  type = map
  default = {
    us-east-1 = "ami-13be557e"
    us-west-2 = "ami-06b94666"
    ap-northeast-1 = "ami-034968955444c1fd9"
  }
}

# "aws_instance"というタイプのresourceを定義し、 そのリソースに"web"というローカルネームをつける
resource "aws_instance" "web" {
  # aws_instance resourceのArguments
  ami           = lookup(var.amis, var.aws_region)
  instance_type = "t2.micro"
}

# output blockを使って、"instance_ip_address"というアウトプット変数を定義
output "instance_ip_address" {
  value = aws_instance.web.private_ip
  description = "The private IP address of the main server instance."
  # sensitive = true # 任意, これを設定すると、Terraform planやapplyコマンドのアウトプットに値が表示されなくなる
}


## AWS Config ##
variable "aws_region" {
  default = "ap-northeast-1"
}
variable "aws_profile" {
  # type = string
  default = "aws-demo"
  # description = "AWS CLI's profile"
}
provider "aws" {
    # access_key = var.aws_access_key
    # secret_key = var.aws_secret_key
    region = var.aws_region
    profile = var.aws_profile
}