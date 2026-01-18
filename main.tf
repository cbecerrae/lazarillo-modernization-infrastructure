# VPC Module
module "vpc" {
  source                     = "./modules/vpc"
  project_name               = var.project_name
  environment                = var.environment
  vpc_cidr                   = var.vpc_cidr
  aws_availability_zones_ids = var.aws_availability_zones_ids
  single_az                  = true
}

# WordPress Module
module "wordpress" {
  source           = "./modules/wordpress"
  project_name     = var.project_name
  environment      = var.environment
  vpc_id           = module.vpc.vpc_id
  public_subnets   = module.vpc.public_subnets
  private_subnets  = module.vpc.private_subnets
  container_cpu    = 512
  container_memory = 1024

  depends_on = [module.vpc]
}

# Nominatim PostgreSQL Module
module "nominatim_postgresql" {
  source                    = "./modules/nominatim_db"
  project_name              = var.project_name
  environment               = var.environment
  vpc_id                    = module.vpc.vpc_id
  private_subnets           = module.vpc.private_subnets
  db_secret_name            = "dev/Nominatim/PostgreSQL"
  nominatim_ecs_tasks_sg_id = module.nominatim_app.ecs_tasks_sg_id
  container_cpu             = 512
  container_memory          = 1024

  depends_on = [module.vpc]
}

# Nominatim App Module
module "nominatim_app" {
  source           = "./modules/nominatim_app"
  project_name     = var.project_name
  environment      = var.environment
  vpc_id           = module.vpc.vpc_id
  public_subnets   = module.vpc.public_subnets
  private_subnets  = module.vpc.private_subnets
  db_secret_name   = "dev/Nominatim/PostgreSQL"
  pbf_url          = "https://download.geofabrik.de/europe/monaco-latest.osm.pbf"
  container_cpu    = 4096
  container_memory = 16384

  depends_on = [module.vpc]
}

# Nominatim PostgreSQL EC2 Module
module "nominatim_db_instance" {
  source       = "./modules/nominatim_db_instance"
  project_name = var.project_name
  environment  = var.environment

  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.private_subnets[0]

  ami           = var.nominatim_db_instance_ami
  instance_type = var.nominatim_db_instance_instance_type
  enable_ssm    = true
}
