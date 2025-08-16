package vanity25519_test

import (
	"context"
	"crypto/ecdh"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"math/big"

	"github.com/AlexanderYastrebov/vanity25519"
)

func ExampleSearch() {
	startKey, _ := ecdh.X25519().GenerateKey(rand.Reader)
	startPublicKey := startKey.PublicKey().Bytes()

	prefix, _ := base64.StdEncoding.DecodeString("AY/" + "x") // pad to 4 characters to decode properly
	testPrefix := vanity25519.HasPrefixBits(prefix, 3*6)      // search for 3-character prefix, i.e. 18 bits

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	var found *big.Int

	vanity25519.Search(ctx, startPublicKey, big.NewInt(0), 4096, testPrefix, func(_ []byte, offset *big.Int) {
		found = offset
		cancel()
	})

	vkb, _ := vanity25519.Add(startKey.Bytes(), found)
	vk, _ := ecdh.X25519().NewPrivateKey(vkb)

	fmt.Printf("Found key: %s...\n", base64.StdEncoding.EncodeToString(vk.PublicKey().Bytes())[:3])
	// Output:
	// Found key: AY/...
}
