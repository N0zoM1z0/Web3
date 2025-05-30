package cosmoskey

import (
	"crypto/ecdsa"
	cryptorand "crypto/rand"
	"fmt"
	"io"
	"math/big"

	"github.com/cosmos/cosmos-sdk/crypto/hd"
	"github.com/cosmos/cosmos-sdk/crypto/keyring"
	"github.com/ethereum/go-ethereum/crypto"

	cryptotypes "github.com/cosmos/cosmos-sdk/crypto/types"

	"github.com/smartcontractkit/chainlink/v2/core/services/keystore/internal"
)

var secpSigningAlgo, _ = keyring.NewSigningAlgoFromString(string(hd.Secp256k1Type), []keyring.SignatureAlgo{hd.Secp256k1})

func KeyFor(raw internal.Raw) Key {
	d := big.NewInt(0).SetBytes(raw.Bytes())
	privKey := secpSigningAlgo.Generate()(d.Bytes())
	return Key{
		d: d,
		k: privKey,
	}
}

var _ fmt.GoStringer = &Key{}

// Key represents Cosmos key
type Key struct {
	d *big.Int
	k cryptotypes.PrivKey
}

// New creates new Key
func New() Key {
	return newFrom(cryptorand.Reader)
}

// MustNewInsecure return Key
func MustNewInsecure(reader io.Reader) Key {
	return newFrom(reader)
}

func newFrom(reader io.Reader) Key {
	rawKey, err := ecdsa.GenerateKey(crypto.S256(), reader)
	if err != nil {
		panic(err)
	}
	privKey := secpSigningAlgo.Generate()(rawKey.D.Bytes())

	return Key{
		d: rawKey.D,
		k: privKey,
	}
}

func (key Key) ID() string {
	return key.PublicKeyStr()
}

func (key Key) PublicKey() (pubKey cryptotypes.PubKey) {
	return key.k.PubKey()
}

func (key Key) PublicKeyStr() string {
	return fmt.Sprintf("%X", key.k.PubKey().Bytes())
}

func (key Key) Raw() internal.Raw {
	return internal.NewRaw(key.d.Bytes())
}

// ToPrivKey returns the key usable for signing.
func (key Key) ToPrivKey() cryptotypes.PrivKey {
	return key.k
}

func (key Key) String() string {
	return fmt.Sprintf("CosmosKey{PrivateKey: <redacted>, Public Key: %s}", key.PublicKeyStr())
}

func (key Key) GoString() string {
	return key.String()
}
