package cmd_test

import (
	"bytes"
	"encoding/hex"
	"flag"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/urfave/cli"

	"github.com/smartcontractkit/chainlink-common/pkg/utils"
	"github.com/smartcontractkit/chainlink/v2/core/cmd"
	"github.com/smartcontractkit/chainlink/v2/core/internal/cltest"
	"github.com/smartcontractkit/chainlink/v2/core/internal/testutils"
	"github.com/smartcontractkit/chainlink/v2/core/services/chainlink"
	"github.com/smartcontractkit/chainlink/v2/core/services/keystore/keys/ocrkey"
	"github.com/smartcontractkit/chainlink/v2/core/web/presenters"
)

func TestOCRKeyBundlePresenter_RenderTable(t *testing.T) {
	t.Parallel()

	var (
		bundleID = "f5bf259689b26f1374efb3c9a9868796953a0f814bb2d39b968d0e61b58620a5"
		buffer   = bytes.NewBufferString("")
		r        = cmd.RendererTable{Writer: buffer}
	)

	key := cltest.DefaultOCRKey

	p := cmd.OCRKeyBundlePresenter{
		JAID: cmd.JAID{ID: bundleID},
		OCRKeysBundleResource: presenters.OCRKeysBundleResource{
			JAID:                  presenters.NewJAID(key.ID()),
			OnChainSigningAddress: key.OnChainSigning.Address(),
			OffChainPublicKey:     key.OffChainSigning.PublicKey(),
			ConfigPublicKey:       key.PublicKeyConfig(),
		},
	}

	// Render a single resource
	require.NoError(t, p.RenderTable(r))

	output := buffer.String()
	assert.Contains(t, output, bundleID)
	assert.Contains(t, output, key.OnChainSigning.Address().String())
	assert.Contains(t, output, hex.EncodeToString(key.PublicKeyOffChain()))
	pubKeyConfig := key.PublicKeyConfig()
	assert.Contains(t, output, hex.EncodeToString(pubKeyConfig[:]))

	// Render many resources
	buffer.Reset()
	ps := cmd.OCRKeyBundlePresenters{p}
	require.NoError(t, ps.RenderTable(r))

	output = buffer.String()
	assert.Contains(t, output, bundleID)
	assert.Contains(t, output, key.OnChainSigning.Address().String())
	assert.Contains(t, output, hex.EncodeToString(key.PublicKeyOffChain()))
	pubKeyConfig = key.PublicKeyConfig()
	assert.Contains(t, output, hex.EncodeToString(pubKeyConfig[:]))
}

func TestShell_ListOCRKeyBundles(t *testing.T) {
	t.Parallel()
	ctx := testutils.Context(t)

	app := startNewApplicationV2(t, nil)
	client, r := app.NewShellAndRenderer()

	key, err := app.GetKeyStore().OCR().Create(ctx)
	require.NoError(t, err)

	requireOCRKeyCount(t, app, 1)

	assert.NoError(t, client.ListOCRKeyBundles(cltest.EmptyCLIContext()))
	require.Len(t, r.Renders, 1)
	output := *r.Renders[0].(*cmd.OCRKeyBundlePresenters)
	require.Equal(t, key.ID(), output[0].ID)
}

func TestShell_CreateOCRKeyBundle(t *testing.T) {
	t.Parallel()

	app := startNewApplicationV2(t, nil)
	client, r := app.NewShellAndRenderer()

	requireOCRKeyCount(t, app, 0)

	require.NoError(t, client.CreateOCRKeyBundle(nilContext))

	keys, err := app.GetKeyStore().OCR().GetAll()
	require.NoError(t, err)
	require.Len(t, keys, 1)

	require.Len(t, r.Renders, 1)
	output := *r.Renders[0].(*cmd.OCRKeyBundlePresenter)
	require.Equal(t, output.ID, keys[0].ID())
}

func TestShell_DeleteOCRKeyBundle(t *testing.T) {
	t.Parallel()
	ctx := testutils.Context(t)

	app := startNewApplicationV2(t, nil)
	client, r := app.NewShellAndRenderer()

	key, err := app.GetKeyStore().OCR().Create(ctx)
	require.NoError(t, err)

	requireOCRKeyCount(t, app, 1)

	set := flag.NewFlagSet("test", 0)
	flagSetApplyFromAction(client.DeleteOCRKeyBundle, set, "")

	require.NoError(t, set.Parse([]string{key.ID()}))
	require.NoError(t, set.Set("yes", "true"))

	c := cli.NewContext(nil, set, nil)

	require.NoError(t, client.DeleteOCRKeyBundle(c))
	requireOCRKeyCount(t, app, 0) // Only fixture key remains

	require.Len(t, r.Renders, 1)
	output := *r.Renders[0].(*cmd.OCRKeyBundlePresenter)
	assert.Equal(t, key.ID(), output.ID)
}

func TestShell_ImportExportOCRKey(t *testing.T) {
	defer deleteKeyExportFile(t)
	ctx := testutils.Context(t)

	app := startNewApplicationV2(t, nil)
	client, _ := app.NewShellAndRenderer()

	require.NoError(t, app.KeyStore.OCR().Add(ctx, cltest.DefaultOCRKey))

	keys := requireOCRKeyCount(t, app, 1)
	key := keys[0]
	keyName := keyNameForTest(t)

	// Export test invalid id
	set := flag.NewFlagSet("test OCR export", 0)
	flagSetApplyFromAction(client.ExportOCRKey, set, "")

	require.NoError(t, set.Parse([]string{"0"}))
	require.NoError(t, set.Set("new-password", "../internal/fixtures/new_password.txt"))
	require.NoError(t, set.Set("output", keyName))

	c := cli.NewContext(nil, set, nil)
	err := client.ExportOCRKey(c)
	require.Error(t, err, "Error exporting")
	require.Error(t, utils.JustError(os.Stat(keyName)))

	// Export
	set = flag.NewFlagSet("test OCR export", 0)
	flagSetApplyFromAction(client.ExportOCRKey, set, "")

	require.NoError(t, set.Parse([]string{key.ID()}))
	require.NoError(t, set.Set("new-password", "../internal/fixtures/new_password.txt"))
	require.NoError(t, set.Set("output", keyName))

	c = cli.NewContext(nil, set, nil)

	require.NoError(t, client.ExportOCRKey(c))
	require.NoError(t, utils.JustError(os.Stat(keyName)))

	require.NoError(t, utils.JustError(app.GetKeyStore().OCR().Delete(ctx, key.ID())))
	requireOCRKeyCount(t, app, 0)

	set = flag.NewFlagSet("test OCR import", 0)
	flagSetApplyFromAction(client.ImportOCRKey, set, "")

	require.NoError(t, set.Parse([]string{keyName}))
	require.NoError(t, set.Set("old-password", "../internal/fixtures/new_password.txt"))

	c = cli.NewContext(nil, set, nil)
	require.NoError(t, client.ImportOCRKey(c))

	requireOCRKeyCount(t, app, 1)
}

func requireOCRKeyCount(t *testing.T, app chainlink.Application, length int) []ocrkey.KeyV2 {
	keys, err := app.GetKeyStore().OCR().GetAll()
	require.NoError(t, err)
	require.Len(t, keys, length)
	return keys
}
