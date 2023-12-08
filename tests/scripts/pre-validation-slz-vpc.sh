#! /bin/bash

########################################################################################################################
## This script is used by the catalog pipeline to deploy the SLZ VPC, which is a prerequisite for the client to site  ##
## landing zone extension, after catalog validation has complete.                                                     ##
########################################################################################################################

set -e

DA_DIR="extensions/landing-zone"
TERRAFORM_SOURCE_DIR="tests/resources"
JSON_FILE="${DA_DIR}/catalogValidationValues.json"
REGION="us-south"
TF_VARS_FILE="terraform.tfvars"

(
  cd ${TERRAFORM_SOURCE_DIR}
  echo "Provisioning prerequisite SLZ VPC .."
  terraform init || exit 1
  # $VALIDATION_APIKEY is available in the catalog runtime
  echo "ibmcloud_api_key=\"${VALIDATION_APIKEY}\"" > ${TF_VARS_FILE}
  echo "prefix=\"c2s-slz-$(openssl rand -hex 2)\"" >> ${TF_VARS_FILE}
  echo "region=\"${REGION}\"" >> ${TF_VARS_FILE}
  terraform apply -input=false -auto-approve -var-file=${TF_VARS_FILE} || exit 1

  prefix_var_name="landing_zone_prefix"
  prefix_var_value=$(terraform output -state=terraform.tfstate -raw prefix)
  rg_var_name="resource_group"
  rg_var_value="${prefix_var_value}-management-rg"
  region_var_name="region"
  echo "Appending '${prefix_var_name}', '${rg_var_name}' and '${region_var_name}' input variable values to ${JSON_FILE}.."
  jq -r --arg prefix_var_name "${prefix_var_name}" \
        --arg prefix_var_value "${prefix_var_value}" \
        --arg rg_var_name "${rg_var_name}" \
        --arg rg_var_value "${rg_var_value}" \
        --arg region_var_name "${region_var_name}" \
        --arg region_var_value "${REGION}" \
        '. + {($prefix_var_name): $prefix_var_value, ($rg_var_name): $rg_var_value, ($region_var_name): $region_var_value}' "${JSON_FILE}" > tmpfile && mv tmpfile "${JSON_FILE}" || exit 1

  echo "Pre-validation complete successfully"
)
