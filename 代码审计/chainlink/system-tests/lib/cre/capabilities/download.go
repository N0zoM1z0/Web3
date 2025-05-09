package capabilities

import (
	"os"
	"path/filepath"

	"github.com/smartcontractkit/chainlink-testing-framework/lib/client"
)

func DownloadCapabilityFromRelease(ghToken, version, assetFileName string) (string, error) {
	ghClient := client.NewGithubClient(ghToken)
	content, err := ghClient.DownloadAssetFromRelease("smartcontractkit", "capabilities", version, assetFileName)
	if err != nil {
		return "", err
	}

	fileName := assetFileName
	file, err := os.Create(assetFileName)
	if err != nil {
		return "", err
	}
	defer file.Close()

	if _, err = file.Write(content); err != nil {
		return "", err
	}

	absPath, err := filepath.Abs(fileName)
	if err != nil {
		return "", err
	}

	return absPath, nil
}
