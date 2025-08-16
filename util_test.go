package vanity25519

import (
	"bytes"
	"crypto/rand"
	"encoding/base64"
	"encoding/binary"
	"reflect"
	"strings"
	"testing"

	"filippo.io/edwards25519"
)

func TestHasPrefixBits(t *testing.T) {
	t.Logf("AY/: % x", "AY/") // 41 59 2f

	assertTrue(t, HasPrefixBits([]byte("AY/"), 8)([]byte{0x41, 0x59, 0x2f}))
	assertTrue(t, HasPrefixBits([]byte("AY/"), 7)([]byte{0x40, 0x59, 0x2f}))

	buf := make([]byte, 32)
	rand.Read(buf)
	input := bytes.Clone(buf)

	for i := 1; i < 256; i++ {
		assertTrue(t, HasPrefixBits(buf, i)(input))
	}

	input[0] ^= 0x01
	for i := 1; i < 8; i++ {
		assertTrue(t, HasPrefixBits(buf, i)(input))
	}
	for i := 8; i < 256; i++ {
		assertFalse(t, HasPrefixBits(buf, i)(input))
	}
}

// decodeBase64PrefixBits returns base64-decoded prefix and number of decoded bits.
func decodeBase64PrefixBits(prefix string) ([]byte, int) {
	decodedBits := 6 * len(prefix)
	quantums := (len(prefix) + 3) / 4
	prefix += strings.Repeat("A", quantums*4-len(prefix))
	buf := make([]byte, quantums*3)
	_, err := base64.StdEncoding.Decode(buf, []byte(prefix))
	if err != nil {
		panic(err)
	}
	return buf, decodedBits
}

func randUint64() uint64 {
	var num uint64
	err := binary.Read(rand.Reader, binary.NativeEndian, &num)
	if err != nil {
		panic(err)
	}
	return num
}

func scalarFromUint64(n uint64) *edwards25519.Scalar {
	var buf [64]byte
	binary.LittleEndian.PutUint64(buf[:], n)

	xs, err := edwards25519.NewScalar().SetUniformBytes(buf[:])
	if err != nil {
		panic(err)
	}
	return xs
}

func assertTrue(t *testing.T, value bool) {
	if !value {
		t.Helper()
		t.Error("Should be true")
	}
}

func assertFalse(t *testing.T, value bool) {
	if value {
		t.Helper()
		t.Error("Should be false")
	}
}

func assertEqual(t *testing.T, expected, actual any) {
	if !reflect.DeepEqual(expected, actual) {
		t.Helper()
		t.Errorf("Not equal:\nexpected: %v\n  actual: %v", expected, actual)
	}
}

func assertNoError(t *testing.T, err error) {
	if err != nil {
		t.Helper()
		t.Errorf("Received unexpected error: %+v", err)
	}
}

func requireNoError(t *testing.T, err error) {
	if err != nil {
		t.Helper()
		t.Fatalf("Received unexpected error: %+v", err)
	}
}
