variable "name_prefix" {
  description = "Prefix applied to every resource name and Name tag."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC."
  type        = string
}

variable "private_data_subnet_ids" {
  description = "Private data subnet IDs (one per AZ) for the DB subnet group."
  type        = list(string)
}

variable "app_security_group_id" {
  description = "SG of the web tier; only members can reach MySQL:3306."
  type        = string
}

variable "engine_version" {
  description = "MySQL engine version."
  type        = string
  default     = "8.0"
}

variable "instance_class" {
  description = "RDS instance class (e.g. db.t3.micro)."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GiB."
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Initial database name."
  type        = string
}

variable "db_username" {
  description = "Master username."
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Master password."
  type        = string
  sensitive   = true
}

variable "backup_retention_days" {
  description = "Number of days of automated backups to retain."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Common tags merged onto every resource."
  type        = map(string)
  default     = {}
}
