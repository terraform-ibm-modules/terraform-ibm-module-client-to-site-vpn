// Tests in this file are run in the PR pipeline and the continuous testing pipeline
package test

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/files"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/cloudinfo"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/common"

	"github.com/stretchr/testify/assert"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testschematic"
)

// const resourceGroup = "geretain-test-client-to-site-vpn"
const yamlLocation = "../common-dev-assets/common-go-assets/common-permanent-resources.yaml"

var sharedInfoSvc *cloudinfo.CloudInfoService
var permanentResources map[string]interface{}

const quickstartFlavorDir = "solutions/quickstart"
const standardFlavorDir = "solutions/standard"

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

func TestQuickstartSolutionInSchematics(t *testing.T) {
	t.Parallel()
	// ------------------------------------------------------------------------------------------------------
	// Create SLZ VPC, SM private cert, resource group first
	// ------------------------------------------------------------------------------------------------------

	prefix := fmt.Sprintf("cts-qs-%s", strings.ToLower(random.UniqueId()))
	realTerraformDir := "./resources"
	tempTerraformDir, _ := files.CopyTerraformFolderToTemp(realTerraformDir, fmt.Sprintf(prefix+"-%s", strings.ToLower(random.UniqueId())))

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
			"prefix":                                prefix,
			"region":                                region,
			"resource_tags":                         []string{"test-schematic"},
			"existing_secrets_manager_instance_crn": permanentResources["secretsManagerCRN"],
			"certificate_template_name":             permanentResources["privateCertTemplateName"],
		},
		// Set Upgrade to true to ensure latest version of providers and modules are used by terratest.
		// This is the same as setting the -upgrade=true flag with terraform.
		Upgrade: true,
	})

	terraform.WorkspaceSelectOrNew(t, existingTerraformOptions, prefix)
	_, existErr := terraform.InitAndApplyE(t, existingTerraformOptions)

	if existErr != nil {
		assert.True(t, existErr == nil, "Init and Apply of temp resources (SLZ VPC and Secrets Manager) failed")
	} else {
		options := testschematic.TestSchematicOptionsDefault(&testschematic.TestSchematicOptions{
			Testing: t,
			Prefix:  prefix,
			TarIncludePatterns: []string{
				quickstartFlavorDir + "/*.*",
				"*.tf",
			},
			ResourceGroup:          terraform.Output(t, existingTerraformOptions, "resource_group_name"),
			TemplateFolder:         quickstartFlavorDir,
			Tags:                   []string{"test-schematic"},
			DeleteWorkspaceOnFail:  false,
			WaitJobCompleteMinutes: 60,
			Region:                 region,
		})

		options.TerraformVars = []testschematic.TestSchematicTerraformVar{
			{Name: "ibmcloud_api_key", Value: options.RequiredEnvironmentVars["TF_VAR_ibmcloud_api_key"], DataType: "string", Secure: true},
			{Name: "prefix", Value: options.Prefix, DataType: "string"},
			{Name: "region", Value: region, DataType: "string"},
			{Name: "use_existing_resource_group", Value: true, DataType: "bool"},
			{Name: "resource_group_name", Value: terraform.Output(t, existingTerraformOptions, "resource_group_name"), DataType: "string"},
			{Name: "existing_secrets_manager_instance_crn", Value: permanentResources["secretsManagerCRN"], DataType: "string"},
			{Name: "existing_vpc_crn", Value: terraform.Output(t, existingTerraformOptions, "management_vpc_crn"), DataType: "string"},
			{Name: "existing_secrets_manager_cert_crn", Value: terraform.Output(t, existingTerraformOptions, "sm_private_cert_crn"), DataType: "string"},
			{Name: "provider_visibility", Value: "public", DataType: "string"},
		}

		err := options.RunSchematicTest()
		assert.Nil(t, err, "This should not have errored")
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

func TestStandardSolutionInSchematics(t *testing.T) {
	t.Parallel()
	// ------------------------------------------------------------------------------------------------------
	// Create SLZ VPC, SM instance, engine, private cert, resource group first
	// ------------------------------------------------------------------------------------------------------

	prefix := fmt.Sprintf("cts-%s", strings.ToLower(random.UniqueId()))
	realTerraformDir := "./resources"
	tempTerraformDir, _ := files.CopyTerraformFolderToTemp(realTerraformDir, fmt.Sprintf(prefix+"-%s", strings.ToLower(random.UniqueId())))

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
			"resource_tags": []string{"test-schematic"},
		},
		// Set Upgrade to true to ensure latest version of providers and modules are used by terratest.
		// This is the same as setting the -upgrade=true flag with terraform.
		Upgrade: true,
	})

	terraform.WorkspaceSelectOrNew(t, existingTerraformOptions, prefix)
	_, existErr := terraform.InitAndApplyE(t, existingTerraformOptions)

	if existErr != nil {
		assert.True(t, existErr == nil, "Init and Apply of temp resources (SLZ VPC and Secrets Manager) failed")
	} else {

		var network_acls_json_array = "[{\"name\":\"vpc-acl-2\",\"rules\":[{\"action\":\"allow\",\"destination\":\"0.0.0.0/0\",\"direction\":\"inbound\",\"name\":\"allow-all-443-inbound\",\"source\":\"0.0.0.0/0\",\"tcp\":{\"port_max\":443,\"port_min\":443,\"source_port_max\":65535,\"source_port_min\":1024}},{\"action\":\"allow\",\"destination\":\"0.0.0.0/0\",\"direction\":\"outbound\",\"name\":\"allow-all-443-outbound\",\"source\":\"0.0.0.0/0\",\"tcp\":{\"port_max\":65535,\"port_min\":1024,\"source_port_max\":443,\"source_port_min\":443}}]},{\"name\":\"vpc-acl\",\"rules\":[{\"action\":\"allow\",\"destination\":\"0.0.0.0/0\",\"direction\":\"inbound\",\"name\":\"allow-all-443-inbound\",\"source\":\"0.0.0.0/0\",\"udp\":{\"port_max\":443,\"port_min\":443}},{\"action\":\"allow\",\"destination\":\"0.0.0.0/0\",\"direction\":\"outbound\",\"name\":\"allow-all-443-outbound\",\"source\":\"0.0.0.0/0\",\"udp\":{\"source_port_max\":443,\"source_port_min\":443}}]}]"
		var network_acls []map[string]interface{}
		err := json.Unmarshal([]byte(network_acls_json_array), &network_acls)
		if err != nil {
			fmt.Println("Error:", err)
			return
		}
		var security_group_rules_json_array = "[{\"name\":\"allow-all-inbound\", \"direction\":\"inbound\", \"remote\":\"0.0.0.0/0\"}]"
		var security_group_rules []map[string]interface{}
		err = json.Unmarshal([]byte(security_group_rules_json_array), &security_group_rules)
		if err != nil {
			fmt.Println("Error:", err)
			return
		}
		options := testschematic.TestSchematicOptionsDefault(&testschematic.TestSchematicOptions{
			Testing: t,
			Prefix:  prefix,
			TarIncludePatterns: []string{
				standardFlavorDir + "/*.*",
				"*.tf",
			},
			ResourceGroup:          terraform.Output(t, existingTerraformOptions, "resource_group_name"),
			TemplateFolder:         standardFlavorDir,
			Tags:                   []string{"test-schematic"},
			DeleteWorkspaceOnFail:  false,
			WaitJobCompleteMinutes: 60,
			Region:                 region,
		})

		options.TerraformVars = []testschematic.TestSchematicTerraformVar{
			{Name: "ibmcloud_api_key", Value: options.RequiredEnvironmentVars["TF_VAR_ibmcloud_api_key"], DataType: "string", Secure: true},
			{Name: "prefix", Value: options.Prefix, DataType: "string"},
			{Name: "region", Value: region, DataType: "string"},
			{Name: "use_existing_resource_group", Value: true, DataType: "bool"},
			{Name: "resource_group_name", Value: terraform.Output(t, existingTerraformOptions, "resource_group_name"), DataType: "string"},
			{Name: "existing_secrets_manager_instance_crn", Value: permanentResources["secretsManagerCRN"], DataType: "string"},
			{Name: "existing_vpc_crn", Value: terraform.Output(t, existingTerraformOptions, "management_vpc_crn"), DataType: "string"},
			{Name: "cert_common_name", Value: fmt.Sprintf("%s%s", options.Prefix, ".com"), DataType: "string"},
			{Name: "certificate_template_name", Value: permanentResources["privateCertTemplateName"], DataType: "string"},
			{Name: "network_acls", Value: network_acls, DataType: "list(object)"},
			{Name: "security_group_rules", Value: security_group_rules, DataType: "list(object)"},
			{Name: "provider_visibility", Value: "public", DataType: "string"},
		}

		err = options.RunSchematicTest()
		assert.Nil(t, err, "This should not have errored")
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

func TestStandardSolutionExistingResources(t *testing.T) {
	t.Parallel()

	// ------------------------------------------------------------------------------------
	// Create SLZ VPC, SM private cert, resource group first
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
			"prefix":                                prefix,
			"region":                                region,
			"resource_tags":                         tags,
			"existing_secrets_manager_instance_crn": permanentResources["secretsManagerCRN"],
			"certificate_template_name":             permanentResources["privateCertTemplateName"],
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
		// Deploy VPN solution
		// ------------------------------------------------------------------------------------
		var network_acls_json_array = "[{\"name\":\"vpc-acl-2\",\"rules\":[{\"action\":\"allow\",\"destination\":\"0.0.0.0/0\",\"direction\":\"inbound\",\"name\":\"allow-all-443-inbound\",\"source\":\"0.0.0.0/0\",\"tcp\":{\"port_max\":443,\"port_min\":443,\"source_port_max\":65535,\"source_port_min\":1024}},{\"action\":\"allow\",\"destination\":\"0.0.0.0/0\",\"direction\":\"outbound\",\"name\":\"allow-all-443-outbound\",\"source\":\"0.0.0.0/0\",\"tcp\":{\"port_max\":65535,\"port_min\":1024,\"source_port_max\":443,\"source_port_min\":443}}]},{\"name\":\"vpc-acl\",\"rules\":[{\"action\":\"allow\",\"destination\":\"0.0.0.0/0\",\"direction\":\"inbound\",\"name\":\"allow-all-443-inbound\",\"source\":\"0.0.0.0/0\",\"udp\":{\"port_max\":443,\"port_min\":443}},{\"action\":\"allow\",\"destination\":\"0.0.0.0/0\",\"direction\":\"outbound\",\"name\":\"allow-all-443-outbound\",\"source\":\"0.0.0.0/0\",\"udp\":{\"source_port_max\":443,\"source_port_min\":443}}]}]"
		var network_acls []map[string]interface{}
		err := json.Unmarshal([]byte(network_acls_json_array), &network_acls)
		if err != nil {
			fmt.Println("Error:", err)
			return
		}
		var security_group_rules_json_array = "[{\"name\":\"allow-all-inbound\", \"direction\":\"inbound\", \"remote\":\"0.0.0.0/0\"}]"
		var security_group_rules []map[string]interface{}
		err = json.Unmarshal([]byte(security_group_rules_json_array), &security_group_rules)
		if err != nil {
			fmt.Println("Error:", err)
			return
		}
		options := testhelper.TestOptionsDefault(&testhelper.TestOptions{
			Testing:      t,
			TerraformDir: standardFlavorDir,
			// Do not hard fail the test if the implicit destroy steps fail to allow a full destroy of resource to occur
			ImplicitRequired: false,
			TerraformVars: map[string]interface{}{
				"prefix":                                prefix,
				"region":                                region,
				"use_existing_resource_group":           true,
				"resource_group_name":                   terraform.Output(t, existingTerraformOptions, "resource_group_name"),
				"existing_vpc_crn":                      terraform.Output(t, existingTerraformOptions, "management_vpc_crn"),
				"existing_secrets_manager_cert_crn":     terraform.Output(t, existingTerraformOptions, "sm_private_cert_crn"),
				"existing_secrets_manager_instance_crn": permanentResources["secretsManagerCRN"],
				"network_acls":                          network_acls,
				"security_group_rules":                  security_group_rules,
				"provider_visibility":                   "public",
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
