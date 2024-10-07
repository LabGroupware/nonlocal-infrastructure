resource "random_uuid" "test" {
}

output "ramdom_id" {
  value = "${random_uuid.test.id}"
}
