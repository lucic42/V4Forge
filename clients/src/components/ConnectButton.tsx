import { ConnectButton } from "@rainbow-me/rainbowkit";
import { ChevronDown } from "lucide-react";

export default function ConnectWallet() {
  return (
    <ConnectButton.Custom>
      {({
        account,
        chain,
        openAccountModal,
        openChainModal,
        openConnectModal,
        mounted,
      }) => {
        const ready = mounted;
        const connected = ready && account && chain;

        return (
          <div
            {...(!ready && {
              "aria-hidden": true,
              style: {
                opacity: 0,
                pointerEvents: "none",
                userSelect: "none",
              },
            })}
          >
            {(() => {
              if (!connected) {
                return (
                  <button
                    onClick={openConnectModal}
                    className="cursor-pointer bg-gradient-to-r from-teal-500 to-blue-500 hover:from-teal-600 hover:to-blue-600 px-4 py-2 rounded-xl text-white transition-all duration-300"
                  >
                    Connect Wallet
                  </button>
                );
              }

              if (chain.unsupported) {
                return (
                  <button
                    onClick={openChainModal}
                    className="cursor-pointer bg-red-600/80 border border-red-400 px-4 py-2 rounded-xl text-white hover:bg-red-700 transition-colors"
                  >
                    Wrong network
                  </button>
                );
              }

              return (
                <div className="flex items-center gap-2">
                  <button
                    onClick={openChainModal}
                    className="flex items-center cursor-pointer bg-gradient-to-r from-teal-500/10 to-blue-500/10 border border-teal-500/50 hover:border-teal-500 px-3 py-2 rounded-xl transition-colors"
                  >
                    {chain.hasIcon && (
                      <div
                        style={{
                          background: chain.iconBackground,
                          width: 18,
                          height: 18,
                          borderRadius: 999,
                          overflow: "hidden",
                          marginRight: 6,
                        }}
                      >
                        {chain.iconUrl && (
                          <img
                            alt={chain.name ?? "Chain icon"}
                            src={chain.iconUrl}
                            style={{ width: 18, height: 18 }}
                          />
                        )}
                      </div>
                    )}
                    {chain.name}
                    <ChevronDown className="h-4 w-4 ml-2" />
                  </button>

                  <button
                    onClick={openAccountModal}
                    className="flex items-center cursor-pointer bg-gradient-to-r from-teal-500/10 to-blue-500/10 border border-teal-500/50 hover:border-teal-500 px-4 py-2 rounded-xl transition-colors"
                  >
                    {!account.ensAvatar && account.displayBalance && (
                      <div className="w-5 h-5 rounded-full bg-gradient-to-r from-teal-500 to-blue-500 mr-2 flex items-center justify-center text-white text-xs">
                        {account.displayName.slice(0, 1)}
                      </div>
                    )}
                    {account.displayName}
                    {account.displayBalance
                      ? ` (${account.displayBalance})`
                      : ""}
                    <ChevronDown className="h-4 w-4 ml-2" />
                  </button>
                </div>
              );
            })()}
          </div>
        );
      }}
    </ConnectButton.Custom>
  );
}