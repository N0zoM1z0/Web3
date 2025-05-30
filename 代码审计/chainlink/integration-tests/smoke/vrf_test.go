package smoke

import (
	"fmt"
	"math/big"
	"strconv"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/onsi/gomega"
	"github.com/rs/zerolog"
	"github.com/stretchr/testify/require"

	"github.com/smartcontractkit/chainlink-testing-framework/lib/logging"
	"github.com/smartcontractkit/chainlink-testing-framework/lib/utils/testcontext"
	"github.com/smartcontractkit/chainlink-testing-framework/seth"

	"github.com/smartcontractkit/chainlink/deployment/environment/nodeclient"
	"github.com/smartcontractkit/chainlink/integration-tests/actions"
	"github.com/smartcontractkit/chainlink/integration-tests/actions/vrf/vrfv1"
	"github.com/smartcontractkit/chainlink/integration-tests/contracts"
	ethcontracts "github.com/smartcontractkit/chainlink/integration-tests/contracts"
	"github.com/smartcontractkit/chainlink/integration-tests/docker/test_env"
	tc "github.com/smartcontractkit/chainlink/integration-tests/testconfig"
	"github.com/smartcontractkit/chainlink/integration-tests/utils"
)

func TestVRFBasic(t *testing.T) {
	t.Parallel()
	l := logging.GetTestLogger(t)
	env, vrfContracts, sethClient := prepareVRFtestEnv(t, l)

	for _, n := range env.ClCluster.Nodes {
		nodeKey, err := n.API.MustCreateVRFKey()
		require.NoError(t, err, "Creating VRF key shouldn't fail")
		l.Debug().Interface("Key JSON", nodeKey).Msg("Created proving key")
		pubKeyCompressed := nodeKey.Data.ID
		jobUUID := uuid.New()
		os := &nodeclient.VRFTxPipelineSpec{
			Address: vrfContracts.Coordinator.Address(),
		}
		ost, err := os.String()
		require.NoError(t, err, "Building observation source spec shouldn't fail")
		job, err := n.API.MustCreateJob(&nodeclient.VRFJobSpec{
			Name:                     fmt.Sprintf("vrf-%s", jobUUID),
			CoordinatorAddress:       vrfContracts.Coordinator.Address(),
			MinIncomingConfirmations: 1,
			PublicKey:                pubKeyCompressed,
			ExternalJobID:            jobUUID.String(),
			EVMChainID:               strconv.FormatInt(sethClient.ChainID, 10),
			ObservationSource:        ost,
		})
		require.NoError(t, err, "Creating VRF Job shouldn't fail")

		oracleAddr, err := n.API.PrimaryEthAddress()
		require.NoError(t, err, "Getting primary ETH address of chainlink node shouldn't fail")
		provingKey, err := actions.EncodeOnChainVRFProvingKey(*nodeKey)
		require.NoError(t, err, "Encoding on-chain VRF Proving key shouldn't fail")
		err = vrfContracts.Coordinator.RegisterProvingKey(
			big.NewInt(1),
			oracleAddr,
			provingKey,
			actions.EncodeOnChainExternalJobID(jobUUID),
		)
		require.NoError(t, err, "Registering the on-chain VRF Proving key shouldn't fail")
		encodedProvingKeys := make([][2]*big.Int, 0)
		encodedProvingKeys = append(encodedProvingKeys, provingKey)

		requestHash, err := vrfContracts.Coordinator.HashOfKey(testcontext.Get(t), encodedProvingKeys[0])
		require.NoError(t, err, "Getting Hash of encoded proving keys shouldn't fail")
		err = vrfContracts.Consumer.RequestRandomness(requestHash, big.NewInt(1))
		require.NoError(t, err, "Requesting randomness shouldn't fail")

		gom := gomega.NewGomegaWithT(t)
		timeout := time.Minute * 2
		gom.Eventually(func(g gomega.Gomega) {
			jobRuns, err := env.ClCluster.Nodes[0].API.MustReadRunsByJob(job.Data.ID)
			g.Expect(err).ShouldNot(gomega.HaveOccurred(), "Job execution shouldn't fail")

			out, err := vrfContracts.Consumer.RandomnessOutput(testcontext.Get(t))
			g.Expect(err).ShouldNot(gomega.HaveOccurred(), "Getting the randomness output of the consumer shouldn't fail")
			// Checks that the job has actually run
			g.Expect(jobRuns.Data).ShouldNot(gomega.BeEmpty(),
				fmt.Sprintf("Expected the VRF job to run once or more after %s", timeout))

			// TODO: This is an imperfect check, given it's a random number, it CAN be 0, but chances are unlikely.
			// So we're just checking that the answer has changed to something other than the default (0)
			// There's a better formula to ensure that VRF response is as expected, detailed under Technical Walkthrough.
			// https://bl.chain.link/chainlink-vrf-on-chain-verifiable-randomness/
			g.Expect(out.Uint64()).ShouldNot(gomega.BeNumerically("==", 0), "Expected the VRF job give an answer other than 0")
			l.Debug().Uint64("Output", out.Uint64()).Msg("Randomness fulfilled")
		}, timeout, "1s").Should(gomega.Succeed())
	}
}

func TestVRFJobReplacement(t *testing.T) {
	t.Parallel()
	l := logging.GetTestLogger(t)
	env, contracts, sethClient := prepareVRFtestEnv(t, l)

	for _, n := range env.ClCluster.Nodes {
		nodeKey, err := n.API.MustCreateVRFKey()
		require.NoError(t, err, "Creating VRF key shouldn't fail")
		l.Debug().Interface("Key JSON", nodeKey).Msg("Created proving key")
		pubKeyCompressed := nodeKey.Data.ID
		jobUUID := uuid.New()
		os := &nodeclient.VRFTxPipelineSpec{
			Address: contracts.Coordinator.Address(),
		}
		ost, err := os.String()
		require.NoError(t, err, "Building observation source spec shouldn't fail")
		job, err := n.API.MustCreateJob(&nodeclient.VRFJobSpec{
			Name:                     fmt.Sprintf("vrf-%s", jobUUID),
			CoordinatorAddress:       contracts.Coordinator.Address(),
			MinIncomingConfirmations: 1,
			PublicKey:                pubKeyCompressed,
			ExternalJobID:            jobUUID.String(),
			EVMChainID:               strconv.FormatInt(sethClient.ChainID, 10),
			ObservationSource:        ost,
		})
		require.NoError(t, err, "Creating VRF Job shouldn't fail")

		oracleAddr, err := n.API.PrimaryEthAddress()
		require.NoError(t, err, "Getting primary ETH address of chainlink node shouldn't fail")
		provingKey, err := actions.EncodeOnChainVRFProvingKey(*nodeKey)
		require.NoError(t, err, "Encoding on-chain VRF Proving key shouldn't fail")
		err = contracts.Coordinator.RegisterProvingKey(
			big.NewInt(1),
			oracleAddr,
			provingKey,
			actions.EncodeOnChainExternalJobID(jobUUID),
		)
		require.NoError(t, err, "Registering the on-chain VRF Proving key shouldn't fail")
		encodedProvingKeys := make([][2]*big.Int, 0)
		encodedProvingKeys = append(encodedProvingKeys, provingKey)

		requestHash, err := contracts.Coordinator.HashOfKey(testcontext.Get(t), encodedProvingKeys[0])
		require.NoError(t, err, "Getting Hash of encoded proving keys shouldn't fail")
		err = contracts.Consumer.RequestRandomness(requestHash, big.NewInt(1))
		require.NoError(t, err, "Requesting randomness shouldn't fail")

		gom := gomega.NewGomegaWithT(t)
		timeout := time.Minute * 2
		gom.Eventually(func(g gomega.Gomega) {
			jobRuns, err := env.ClCluster.Nodes[0].API.MustReadRunsByJob(job.Data.ID)
			g.Expect(err).ShouldNot(gomega.HaveOccurred(), "Job execution shouldn't fail")

			out, err := contracts.Consumer.RandomnessOutput(testcontext.Get(t))
			g.Expect(err).ShouldNot(gomega.HaveOccurred(), "Getting the randomness output of the consumer shouldn't fail")
			// Checks that the job has actually run
			g.Expect(jobRuns.Data).ShouldNot(gomega.BeEmpty(),
				fmt.Sprintf("Expected the VRF job to run once or more after %s", timeout))

			g.Expect(out.Uint64()).ShouldNot(gomega.BeNumerically("==", 0), "Expected the VRF job give an answer other than 0")
			l.Debug().Uint64("Output", out.Uint64()).Msg("Randomness fulfilled")
		}, timeout, "1s").Should(gomega.Succeed())

		err = n.API.MustDeleteJob(job.Data.ID)
		require.NoError(t, err)

		job, err = n.API.MustCreateJob(&nodeclient.VRFJobSpec{
			Name:                     fmt.Sprintf("vrf-%s", jobUUID),
			CoordinatorAddress:       contracts.Coordinator.Address(),
			MinIncomingConfirmations: 1,
			PublicKey:                pubKeyCompressed,
			ExternalJobID:            jobUUID.String(),
			EVMChainID:               strconv.FormatInt(sethClient.ChainID, 10),
			ObservationSource:        ost,
		})
		require.NoError(t, err, "Recreating VRF Job shouldn't fail")
		gom.Eventually(func(g gomega.Gomega) {
			jobRuns, err := env.ClCluster.Nodes[0].API.MustReadRunsByJob(job.Data.ID)
			g.Expect(err).ShouldNot(gomega.HaveOccurred(), "Job execution shouldn't fail")

			out, err := contracts.Consumer.RandomnessOutput(testcontext.Get(t))
			g.Expect(err).ShouldNot(gomega.HaveOccurred(), "Getting the randomness output of the consumer shouldn't fail")
			// Checks that the job has actually run
			g.Expect(jobRuns.Data).ShouldNot(gomega.BeEmpty(),
				fmt.Sprintf("Expected the VRF job to run once or more after %s", timeout))
			g.Expect(out.Uint64()).ShouldNot(gomega.BeNumerically("==", 0), "Expected the VRF job give an answer other than 0")
			l.Debug().Uint64("Output", out.Uint64()).Msg("Randomness fulfilled")
		}, timeout, "1s").Should(gomega.Succeed())
	}
}

func prepareVRFtestEnv(t *testing.T, l zerolog.Logger) (*test_env.CLClusterTestEnv, *vrfv1.Contracts, *seth.Client) {
	config, err := tc.GetChainAndTestTypeSpecificConfig("Smoke", tc.VRF)
	require.NoError(t, err, "Error getting config")

	privateNetwork, err := actions.EthereumNetworkConfigFromConfig(l, &config)
	require.NoError(t, err, "Error building ethereum network config")

	env, err := test_env.NewCLTestEnvBuilder().
		WithTestInstance(t).
		WithTestConfig(&config).
		WithPrivateEthereumNetwork(privateNetwork.EthereumNetworkConfig).
		WithCLNodes(1).
		WithStandardCleanup().
		Build()
	require.NoError(t, err)

	evmNetwork, err := env.GetFirstEvmNetwork()
	require.NoError(t, err, "Error getting first evm network")

	sethClient, err := utils.TestAwareSethClient(t, config, evmNetwork)
	require.NoError(t, err, "Error getting seth client")

	err = actions.FundChainlinkNodesFromRootAddress(l, sethClient, contracts.ChainlinkClientToChainlinkNodeWithKeysAndAddress(env.ClCluster.NodeAPIs()), big.NewFloat(*config.Common.ChainlinkNodeFunding))
	require.NoError(t, err, "Failed to fund the nodes")

	t.Cleanup(func() {
		// ignore error, we will see failures in the logs anyway
		_ = actions.ReturnFundsFromNodes(l, sethClient, contracts.ChainlinkClientToChainlinkNodeWithKeysAndAddress(env.ClCluster.NodeAPIs()))
	})

	lt, err := ethcontracts.DeployLinkTokenContract(l, sethClient)
	require.NoError(t, err, "Deploying Link Token Contract shouldn't fail")
	vrfContracts, err := vrfv1.DeployVRFContracts(sethClient, lt.Address())
	require.NoError(t, err, "Deploying VRF Contracts shouldn't fail")

	err = lt.Transfer(vrfContracts.Consumer.Address(), big.NewInt(2e18))
	require.NoError(t, err, "Funding consumer contract shouldn't fail")
	_, err = ethcontracts.DeployVRFv1Contract(sethClient)
	require.NoError(t, err, "Deploying VRF contract shouldn't fail")

	return env, vrfContracts, sethClient
}
