// Tests in this file are run in the PR pipeline
package test

import (
	"fmt"
	"log"
	"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/stretchr/testify/assert"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
	"gopkg.in/yaml.v3"
)

// Resource groups are maintained https://github.ibm.com/GoldenEye/ge-dev-account-management
// Allow the tests to create a unique resource group for every test to ensure tests do not clash. This is due to the fact that the auth policy created by this module has to be scoped to the resource group (see https://github.ibm.com/GoldenEye/client-to-site-vpn-module/pull/303#issuecomment-54128819) and hence would clash if tests used same resource group.
// const resourceGroup = "geretain-test-client-to-site-vpn"
const highAvailabilityModeExampleTerraformDir = "examples/highavailability_mode"
const certificateTemplateName = "geretain-cert-template"

var vpnClientAccessGroupUsers = []string{"GoldenEye.Development@ibm.com"}

const yamlLocation = "../common-dev-assets/common-go-assets/common-permanent-resources.yaml"

type Config struct {
	SmGuid   string `yaml:"secretsManagerGuid"`
	SmRegion string `yaml:"secretsManagerRegion"`
}

var smGuid string
var smRegion string

// TestMain will be run before any parallel tests, used to read data from yaml for use with tests
func TestMain(m *testing.M) {
	// Read the YAML file contents
	data, err := os.ReadFile(yamlLocation)
	if err != nil {
		log.Fatal(err)
	}
	// Create a struct to hold the YAML data
	var config Config
	// Unmarshal the YAML data into the struct
	err = yaml.Unmarshal(data, &config)
	if err != nil {
		log.Fatal(err)
	}
	// Parse the SM guid and region from data
	smGuid = config.SmGuid
	smRegion = config.SmRegion
	os.Exit(m.Run())
}

func setupOptions(t *testing.T, prefix string) *testhelper.TestOptions {
	options := testhelper.TestOptionsDefaultWithVars(&testhelper.TestOptions{
		Testing:      t,
		TerraformDir: highAvailabilityModeExampleTerraformDir,
		Prefix:       prefix,
		//ResourceGroup: resourceGroup,
		TerraformVars: map[string]interface{}{
			"existing_sm_instance_guid":     smGuid,
			"existing_sm_instance_region":   smRegion,
			"certificate_template_name":     certificateTemplateName,
			"access_group_name":             fmt.Sprintf("cts-%s", strings.ToLower(random.UniqueId())),
			"vpn_client_access_group_users": vpnClientAccessGroupUsers,
		},
	})
	return options
}

func TestRunHighAvailabilityVPNExample(t *testing.T) {
	t.Parallel()

	options := setupOptions(t, "cts-ha-vpn")

	output, err := options.RunTestConsistency()
	assert.Nil(t, err, "This should not have errored")
	assert.NotNil(t, output, "Expected some output")
}

func TestRunUpgradeHighAvailabilityVPNExample(t *testing.T) {
	t.Parallel()

	options := setupOptions(t, "cts-vpn-upg")

	output, err := options.RunTestUpgrade()
	if !options.UpgradeTestSkipped {
		assert.Nil(t, err, "This should not have errored")
		assert.NotNil(t, output, "Expected some output")
	}
}
