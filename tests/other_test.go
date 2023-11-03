// Tests in this file are NOT run in the PR pipeline. They are run in the continuous testing pipeline along with the ones in pr_test.go
package test

import (
	"testing"

	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"

	"github.com/stretchr/testify/assert"
)

func TestRunBasicExample(t *testing.T) {
	t.Parallel()

	options := testhelper.TestOptionsDefaultWithVars(&testhelper.TestOptions{
		Testing:          t,
		TerraformDir:     "examples/basic",
		CloudInfoService: sharedInfoSvc,
		Prefix:           "cts-basic",
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
