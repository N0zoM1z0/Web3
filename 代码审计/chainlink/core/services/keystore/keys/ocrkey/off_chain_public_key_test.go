package ocrkey_test

import (
	"encoding/json"
	"fmt"
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/smartcontractkit/chainlink/v2/core/services/keystore/keys/ocrkey"
)

func TestOCR_OffchainPublicKey_MarshalJSON(t *testing.T) {
	t.Parallel()
	rawBytes := make([]byte, 32)
	rawBytes[31] = 1
	pubKey := ocrkey.OffChainPublicKey(rawBytes)

	pubKeyString := "ocroff_0000000000000000000000000000000000000000000000000000000000000001"
	pubKeyJSON := fmt.Sprintf(`"%s"`, pubKeyString)

	result, err := json.Marshal(pubKey)
	assert.NoError(t, err)
	assert.JSONEq(t, pubKeyJSON, string(result))
}

func TestOCR_OffchainPublicKey_UnmarshalJSON_Happy(t *testing.T) {
	t.Parallel()

	pubKeyString := "918a65a518c005d6367309bec4b26805f8afabef72cbf9940d9a0fd04ec80b38"
	pubKeyJSON := fmt.Sprintf(`"%s"`, pubKeyString)
	pubKey := ocrkey.OffChainPublicKey{}

	err := json.Unmarshal([]byte(pubKeyJSON), &pubKey)
	assert.NoError(t, err)
	assert.Equal(t, pubKeyString, pubKey.Raw())
}

func TestOCR_OffchainPublicKey_UnmarshalJSON_Error(t *testing.T) {
	t.Parallel()

	pubKeyString := "hello world"
	pubKeyJSON := fmt.Sprintf(`"%s"`, pubKeyString)
	pubKey := ocrkey.OffChainPublicKey{}

	err := json.Unmarshal([]byte(pubKeyJSON), &pubKey)
	assert.Error(t, err)
}
