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

  prefix=$(terraform output -state=terraform.tfstate -raw prefix)
  rg="${prefix}-management-rg"
  echo "Appending '${prefix}' and '${rg}' input variable values to ${JSON_FILE}.."
  jq -r --arg prefix "${prefix}" --arg rg "${rg}" --arg region "${REGION}" '. + {landing_zone_prefix: $prefix, resource_group: $rg, region: $region}' "${JSON_FILE}" > tmpfile && mv tmpfile "${JSON_FILE}" || exit 1

  echo "Pre-validation complete successfully"
)
