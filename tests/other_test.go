// Tests in this file are NOT run in the PR pipeline. They are run in the continuous testing pipeline along with the ones in pr_test.go
package test

import (
	"testing"

	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"

	"github.com/stretchr/testify/assert"
)

func TestRunBasicExample(t *testing.T) {
	t.Parallel()
	t.Skip()

	options := testhelper.TestOptionsDefaultWithVars(&testhelper.TestOptions{
		Testing:          t,
		TerraformDir:     "examples/basic",
		CloudInfoService: sharedInfoSvc,
		Prefix:           "cts-basic",
		/*
		 Comment out the 'ResourceGroup' input to force this tests to create a unique resource group to ensure tests do
		 not clash. This is due to the fact that an auth policy may already exist in this resource group since we are
		 re-using a permanent secrets-manager instance, and the auth policy cannot be scoped to an exact VPN instance
		 ID. This is due to the face that the VPN can't be provisioned without the cert from secrets manager, but it
		 can't grab the cert from secrets manager until the policy is created. By using a new resource group, the auth
		 policy will not already exist since this module scopes auth policies by resource group.
		*/
		//ResourceGroup: resourceGroup,
		TerraformVars: map[string]interface{}{
			"vpn_client_access_group_users": []string{"GoldenEye.Operations@ibm.com"},
			"secrets_manager_guid":          permanentResources["secretsManagerGuid"],
			"secrets_manager_region":        permanentResources["secretsManagerRegion"],
			"certificate_template_name":     permanentResources["privateCertTemplateName"],
		},
	})

	output, err := options.RunTestConsistency()
	assert.Nil(t, err, "This should not have errored")
	assert.NotNil(t, output, "Expected some output")
}
