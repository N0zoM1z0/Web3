const ZETACHAIN_TESTNET_CONFIG = {
    chain: {
        chainId: 7001,
        explorerURL: "https://zetachain-testnet.blockscout.com",
    },
    defaultAddress: {
        Gateway: "0x6c533f7fe93fae114d0954697069df33c9b74fd7",
        USDC_SEP: "0xcC683A782f4B30c138787CB5576a86AF66fdc31d",
        USDC_ARBSEP: "0x4bC32034caCcc9B7e02536945eDbC286bACbA073",
        UniswapV2Factory: "0x9fd96203f7b22bCF72d9DCb40ff98302376cE09c",
        UniswapV2Router: "0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe",
        MultiSig: "0xfa0d8ebca31a1501144a785a2929e9f91b0571d0",
        DODORouteProxy: "0x026eea5c10f526153e7578E5257801f8610D1142",
        DODOApprove: "0x143bE32C854E4Ddce45aD48dAe3343821556D0c3"
    }, 
    deployedAddress: {
        GatewayCrossChainImpl: "0x047F9cea5CE9Da358E493848daF73192E7D377d0",
        GatewayCrossChainProxy: "0x816D85D853a7Da1f91F427e4132056D88620e7d7",
        GatewayTransferNativeImpl: "0x9de2F7b3BFf91c48d417c47055dABCb45FEFa48F",
        GatewayTransferNativeProxy: "0xe70C62baf742140ED5bAbbCD35f15b7a9811932A"
    },
  };
  
  export { ZETACHAIN_TESTNET_CONFIG };
  