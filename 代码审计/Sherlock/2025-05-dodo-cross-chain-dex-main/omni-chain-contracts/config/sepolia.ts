import { GatewaySend } from "../typechain-types";

const SEPOLIA_CONFIG = {
    chain: {
        "chainId": 11155111,
        "explorerURL": "https://sepolia.etherscan.io/",
    },
    defaultAddress: {
        Gateway: "0x0c487a766110c85d301D96E33579C5B317Fa4995",
        USDC: "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",
        MultiSig: "0xfa0d8ebca31a1501144a785a2929e9f91b0571d0",
        DODORouteProxy: "0x5fa9e06111814840398ceF6E9563d400F6ed3a8d",
        DODOApprove: "0x66c45FF040e86DC613F239123A5E21FFdC3A3fEC",
    }, 
    deployedAddress: {
        GatewaySendImpl: "0xF7B04b14b0F37d77E5Bb3d47e0cff694F8CEaC9c",
        GatewaySendProxy: "0x2405965a3CB8748D7065752AdC702Bb907AA2297",
    },
  };
  
  export { SEPOLIA_CONFIG };
  