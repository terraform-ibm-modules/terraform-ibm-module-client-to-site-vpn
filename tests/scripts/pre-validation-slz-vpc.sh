#! /bin/bash

########################################################################################################################
## This script is used by the catalog pipeline to deploy the SLZ VPC, which is a prerequisite for the client to site  ##
## landing zone extension, after catalog validation has complete.                                                     ##
########################################################################################################################

set -e

DA_DIR=$1
TERRAFORM_SOURCE_DIR="tests/resources"
JSON_FILE="${DA_DIR}/catalogValidationValues.json"
REGION="us-south"
TF_VARS_FILE="terraform.tfvars"

(
  cwd=$(pwd)
  cd ${TERRAFORM_SOURCE_DIR}
  echo "Provisioning prerequisite SLZ VPC .."
  terraform init || exit 1
  # $VALIDATION_APIKEY is available in the catalog runtime
  {
    echo "ibmcloud_api_key=\"${VALIDATION_APIKEY}\""
    echo "prefix=\"ct2-slz-$(openssl rand -hex 2)\""
    echo "region=\"${REGION}\""
  } >> ${TF_VARS_FILE}
  terraform apply -input=false -auto-approve -var-file=${TF_VARS_FILE} || exit 1

  prefix_var_name="prefix"
  prefix_var_value=$(terraform output -state=terraform.tfstate -raw prefix)
  resource_group_name_var_name="resource_group_name"
  resource_group_name_var_value=$(terraform output -state=terraform.tfstate -raw resource_group_name)
  use_existing_resource_group_var_name="use_existing_resource_group"
  use_existing_resource_group_var_value=true
  existing_vpc_crn_var_name="existing_vpc_crn"
  existing_vpc_crn_var_value=$(terraform output -state=terraform.tfstate -raw management_vpc_crn)

  echo "Appending '${prefix_var_name}', '${resource_group_name_var_name}', '${use_existing_resource_group_var_name}' and '${existing_vpc_crn_var_name}' input variable values to ${JSON_FILE}.."

  cd "${cwd}"
  jq -r --arg prefix_var_name "${prefix_var_name}" \
        --arg prefix_var_value "${prefix_var_value}" \
        --arg resource_group_name_var_name "${resource_group_name_var_name}" \
        --arg resource_group_name_var_value "${resource_group_name_var_value}" \
        --arg use_existing_resource_group_var_name "${use_existing_resource_group_var_name}" \
        --argjson use_existing_resource_group_var_value "${use_existing_resource_group_var_value}" \
        --arg existing_vpc_crn_var_name "${existing_vpc_crn_var_name}" \
        --arg existing_vpc_crn_var_value "${existing_vpc_crn_var_value}" \
        '. + {($prefix_var_name): $prefix_var_value, ($resource_group_name_var_name): $resource_group_name_var_value, ($use_existing_resource_group_var_name): $use_existing_resource_group_var_value, ($existing_vpc_crn_var_name): $existing_vpc_crn_var_value}' "${JSON_FILE}" > tmpfile && mv tmpfile "${JSON_FILE}" || exit 1

  echo "Pre-validation complete successfully"
)
