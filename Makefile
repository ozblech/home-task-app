# Define color codes
GREEN  := \033[0;32m
YELLOW := \033[0;33m
CYAN   := \033[0;36m
RED_BG_BLACK_TEXT := \033[0;30;41m
RESET  := \033[0m
TF_BACKEND_KEY="flir-cloud-kms-terraform.tfstate"

apply:
	@echo "${CYAN}🚀 Starting Terraform Apply...${RESET}"
	@terraform apply -input=true -refresh=true -auto-approve
	@echo "${GREEN}✅ Terraform Apply completed successfully.${RESET}"

plan:
	@echo "${YELLOW}🔍 Generating Terraform Plan...${RESET}"
	@terraform plan -input=true -refresh=true
	@echo "${GREEN}✅ Terraform Plan generated successfully.${RESET}"

init:
	@rm -rf .terraform
	@echo "${CYAN}🔧 Initializing Terraform...${RESET}"	
	terraform init
	@echo "${GREEN}✅ Terraform Initialization completed successfully.${RESET}"

destroy:
	@echo "${RED_BG_BLACK_TEXT}⚠️  Starting Terraform Destroy...${RESET}"
	@terraform destroy -input=true -refresh=true -auto-approve
	@echo "${RED_BG_BLACK_TEXT}✅ Terraform Destroy completed successfully.${RESET}"