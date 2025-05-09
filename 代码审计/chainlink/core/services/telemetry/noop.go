package telemetry

import (
	ocrtypes "github.com/smartcontractkit/libocr/commontypes"

	"github.com/smartcontractkit/chainlink/v2/core/services/synchronization"
)

var _ MonitoringEndpointGenerator = &NoopAgent{}

type NoopAgent struct {
}

// SendLog sends a telemetry log to the ingress service
func (t *NoopAgent) SendLog(log []byte) {
}

func (t *NoopAgent) SendTypedLog(telemType synchronization.TelemetryType, log []byte) {
}

// GenMonitoringEndpoint creates a monitoring endpoint for telemetry
func (t *NoopAgent) GenMonitoringEndpoint(network string, chainID string, contractID string, telemType synchronization.TelemetryType) ocrtypes.MonitoringEndpoint {
	return t
}

// GenMultitypeMonitoringEndpoint creates a multi monitoring endpoint for telemetry
func (t *NoopAgent) GenMultitypeMonitoringEndpoint(network string, chainID string, contractID string) MultitypeMonitoringEndpoint {
	return t
}
