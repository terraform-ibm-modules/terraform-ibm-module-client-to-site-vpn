// Tests in this file are run in the PR pipeline and the continuous testing pipeline
package test

import (
	"fmt"
	"github.com/gruntwork-io/terratest/modules/files"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/cloudinfo"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/common"
	"log"
	"os"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
)

const resourceGroup = "geretain-test-client-to-site-vpn"
const yamlLocation = "../common-dev-assets/common-go-assets/common-permanent-resources.yaml"

var sharedInfoSvc *cloudinfo.CloudInfoService
var permanentResources map[string]interface{}

// TestMain will be run before any parallel tests, used to read data from yaml for use with tests
func TestMain(m *testing.M) {
	sharedInfoSvc, _ = cloudinfo.NewCloudInfoServiceFromEnv("TF_VAR_ibmcloud_api_key", cloudinfo.CloudInfoServiceOptions{})

	var err error
	permanentResources, err = common.LoadMapFromYaml(yamlLocation)
	if err != nil {
		log.Fatal(err)
	}

	os.Exit(m.Run())
}

func setupHAOptions(t *testing.T, prefix string) *testhelper.TestOptions {
	options := testhelper.TestOptionsDefaultWithVars(&testhelper.TestOptions{
		Testing:          t,
		TerraformDir:     "examples/ha-complete",
		Prefix:           prefix,
		CloudInfoService: sharedInfoSvc,
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
			"existing_sm_instance_guid":     permanentResources["secretsManagerGuid"],
			"existing_sm_instance_region":   permanentResources["secretsManagerRegion"],
			"certificate_template_name":     permanentResources["privateCertTemplateName"],
		},
	})
	return options
}

func TestRunHAExample(t *testing.T) {
	t.Parallel()

	options := setupHAOptions(t, "cts-vpn-ha")
	output, err := options.RunTestConsistency()
	assert.Nil(t, err, "This should not have errored")
	assert.NotNil(t, output, "Expected some output")
}

func TestRunHAUpgrade(t *testing.T) {
	t.Parallel()

	options := setupHAOptions(t, "cts-vpn-ha-upg")
	output, err := options.RunTestUpgrade()
	if !options.UpgradeTestSkipped {
		assert.Nil(t, err, "This should not have errored")
		assert.NotNil(t, output, "Expected some output")
	}
}

func TestRunSLZExample(t *testing.T) {
	t.Parallel()

	// ------------------------------------------------------------------------------------
	// Deploy SLZ VPC first since it is needed for the landing-zone extension input
	// ------------------------------------------------------------------------------------

	prefix := fmt.Sprintf("cts-slz-%s", strings.ToLower(random.UniqueId()))
	realTerraformDir := "./resources"
	tempTerraformDir, _ := files.CopyTerraformFolderToTemp(realTerraformDir, fmt.Sprintf(prefix+"-%s", strings.ToLower(random.UniqueId())))
	tags := common.GetTagsFromTravis()

	// Verify ibmcloud_api_key variable is set
	checkVariable := "TF_VAR_ibmcloud_api_key"
	val, present := os.LookupEnv(checkVariable)
	require.True(t, present, checkVariable+" environment variable not set")
	require.NotEqual(t, "", val, checkVariable+" environment variable is empty")

	// Programmatically determine region to use based on availability
	region, _ := testhelper.GetBestVpcRegion(val, "../common-dev-assets/common-go-assets/cloudinfo-region-vpc-gen2-prefs.yaml", "eu-de")

	logger.Log(t, "Tempdir: ", tempTerraformDir)
	existingTerraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: tempTerraformDir,
		Vars: map[string]interface{}{
			"prefix":        prefix,
			"region":        region,
			"resource_tags": tags,
		},
		// Set Upgrade to true to ensure latest version of providers and modules are used by terratest.
		// This is the same as setting the -upgrade=true flag with terraform.
		Upgrade: true,
	})

	terraform.WorkspaceSelectOrNew(t, existingTerraformOptions, prefix)
	_, existErr := terraform.InitAndApplyE(t, existingTerraformOptions)
	if existErr != nil {
		assert.True(t, existErr == nil, "Init and Apply of temp existing resource failed")
	} else {

		// ------------------------------------------------------------------------------------
		// Deploy landing-zone extension
		// ------------------------------------------------------------------------------------

		options := testhelper.TestOptionsDefault(&testhelper.TestOptions{
			Testing:      t,
			TerraformDir: "extension/landing-zone",
			// Do not hard fail the test if the implicit destroy steps fail to allow a full destroy of resource to occur
			ImplicitRequired: false,
			TerraformVars: map[string]interface{}{
				"prefix":                      prefix,
				"region":                      region,
				"resource_group":              fmt.Sprintf("%s-management-rg", prefix),
				"sm_service_plan":             "trial",
				"existing_sm_instance_guid":   permanentResources["secretsManagerGuid"],
				"existing_sm_instance_region": permanentResources["secretsManagerRegion"],
				"certificate_template_name":   permanentResources["privateCertTemplateName"],
				"landing_zone_prefix":         terraform.Output(t, existingTerraformOptions, "prefix"),
			},
		})

		output, err := options.RunTestConsistency()
		assert.Nil(t, err, "This should not have errored")
		assert.NotNil(t, output, "Expected some output")
	}

	// Check if "DO_NOT_DESTROY_ON_FAILURE" is set
	envVal, _ := os.LookupEnv("DO_NOT_DESTROY_ON_FAILURE")
	// Destroy the temporary existing resources if required
	if t.Failed() && strings.ToLower(envVal) == "true" {
		fmt.Println("Terratest failed. Debug the test and delete resources manually.")
	} else {
		logger.Log(t, "START: Destroy (existing resources)")
		terraform.Destroy(t, existingTerraformOptions)
		terraform.WorkspaceDelete(t, existingTerraformOptions, prefix)
		logger.Log(t, "END: Destroy (existing resources)")
	}
}
