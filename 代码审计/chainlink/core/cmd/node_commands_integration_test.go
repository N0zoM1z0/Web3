//go:build integration

package cmd_test

import (
	"bytes"
	"strings"
	"testing"

	"github.com/pelletier/go-toml/v2"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/smartcontractkit/chainlink-common/pkg/config"
	"github.com/smartcontractkit/chainlink/v2/core/cmd"
	"github.com/smartcontractkit/chainlink/v2/core/internal/cltest"
	"github.com/smartcontractkit/chainlink/v2/core/internal/testutils/cosmostest"
	"github.com/smartcontractkit/chainlink/v2/core/services/chainlink"
)

func cosmosStartNewApplication(t *testing.T, cfgs ...chainlink.RawConfig) *cltest.TestApplication {
	return startNewApplicationV2(t, func(c *chainlink.Config, s *chainlink.Secrets) {
		c.Cosmos = cfgs
		c.EVM = nil
	})
}

func TestShell_IndexCosmosNodes(t *testing.T) {
	t.Parallel()

	chainID := cosmostest.RandomChainID()
	node := map[string]any{
		"Name":          ptr("second"),
		"TendermintURL": config.MustParseURL("http://tender.mint.test/bombay-12"),
	}
	chain := chainlink.RawConfig{
		"ChainID": chainID,
		"Nodes":   []any{node},
	}
	app := cosmosStartNewApplication(t, chain)
	client, r := app.NewShellAndRenderer()
	require.NoError(t, cmd.NewNodeClient(client, "cosmos").IndexNodes(cltest.EmptyCLIContext()))
	require.NotEmpty(t, r.Renders)
	nodes := *r.Renders[0].(*cmd.NodePresenters)
	require.Len(t, nodes, 1)
	n := nodes[0]
	assert.Equal(t, cltest.FormatWithPrefixedChainID(chainID, "second"), n.ID)
	assert.Equal(t, chainID, n.ChainID)
	assert.Equal(t, "second", n.Name)
	wantConfig, err := toml.Marshal(node)
	require.NoError(t, err)
	assert.Equal(t, string(wantConfig), n.Config)
	assertTableRenders(t, r)

	// Render table and check the fields order
	b := new(bytes.Buffer)
	rt := cmd.RendererTable{b}
	require.NoError(t, nodes.RenderTable(rt))
	renderLines := strings.Split(b.String(), "\n")
	assert.Len(t, renderLines, 10)
	assert.Contains(t, renderLines[2], "Name")
	assert.Contains(t, renderLines[2], n.Name)
	assert.Contains(t, renderLines[3], "Chain ID")
	assert.Contains(t, renderLines[3], n.ChainID)
	assert.Contains(t, renderLines[4], "State")
	assert.Contains(t, renderLines[4], n.State)
}

func starknetStartNewApplication(t *testing.T, cfgs ...chainlink.RawConfig) *cltest.TestApplication {
	return startNewApplicationV2(t, func(c *chainlink.Config, s *chainlink.Secrets) {
		c.Starknet = cfgs
		c.EVM = nil
		c.Solana = nil
	})
}

func TestShell_IndexStarkNetNodes(t *testing.T) {
	t.Parallel()

	id := "starknet chain ID"
	node1 := map[string]any{
		"Name": ptr("first"),
		"URL":  config.MustParseURL("https://starknet1.example"),
	}
	node2 := map[string]any{
		"Name": ptr("second"),
		"URL":  config.MustParseURL("https://starknet2.example"),
	}
	chain := chainlink.RawConfig{
		"ChainID": &id,
		"Nodes":   []any{&node1, &node2},
	}
	app := starknetStartNewApplication(t, chain)
	client, r := app.NewShellAndRenderer()

	require.NoError(t, cmd.NewNodeClient(client, "starknet").IndexNodes(cltest.EmptyCLIContext()))
	require.NotEmpty(t, r.Renders)
	nodes := *r.Renders[0].(*cmd.NodePresenters)
	require.Len(t, nodes, 2)
	n1 := nodes[0]
	n2 := nodes[1]
	assert.Equal(t, id, n1.ChainID)
	assert.Equal(t, cltest.FormatWithPrefixedChainID(id, "first"), n1.ID)
	assert.Equal(t, "first", n1.Name)
	wantConfig, err := toml.Marshal(node1)
	require.NoError(t, err)
	assert.Equal(t, string(wantConfig), n1.Config)
	assert.Equal(t, id, n2.ChainID)
	assert.Equal(t, cltest.FormatWithPrefixedChainID(id, "second"), n2.ID)
	assert.Equal(t, "second", n2.Name)
	wantConfig2, err := toml.Marshal(node2)
	require.NoError(t, err)
	assert.Equal(t, string(wantConfig2), n2.Config)
	assertTableRenders(t, r)

	// Render table and check the fields order
	b := new(bytes.Buffer)
	rt := cmd.RendererTable{b}
	require.NoError(t, nodes.RenderTable(rt))
	renderLines := strings.Split(b.String(), "\n")
	assert.Len(t, renderLines, 17)
	assert.Contains(t, renderLines[2], "Name")
	assert.Contains(t, renderLines[2], n1.Name)
	assert.Contains(t, renderLines[3], "Chain ID")
	assert.Contains(t, renderLines[3], n1.ChainID)
	assert.Contains(t, renderLines[4], "State")
	assert.Contains(t, renderLines[4], n1.State)
	assert.Contains(t, renderLines[9], "Name")
	assert.Contains(t, renderLines[9], n2.Name)
	assert.Contains(t, renderLines[10], "Chain ID")
	assert.Contains(t, renderLines[10], n2.ChainID)
	assert.Contains(t, renderLines[11], "State")
	assert.Contains(t, renderLines[11], n2.State)
}
